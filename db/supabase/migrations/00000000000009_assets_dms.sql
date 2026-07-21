-- Phase 8: Asset Management + Document Management (+ Phase 9 data import/export privileges).
-- Assets with straight-line/WDV depreciation runs posted through the posting engine, disposal
-- with gain/loss, and a generic document store (Supabase Storage) linkable to any record.
-- See CLAUDE.md backbone rules. Sequences AST/DOC are seeded in migration 2.
--
-- STORAGE NOTE: the 'erp-documents' bucket is NOT created here — bucket DDL via SQL is not
-- reliable across setups. The API creates it lazily on first upload
-- (sb.storage.createBucket('erp-documents', { public: false }), ignoring 'already exists').

-- ============================================================ document management
create table if not exists public.erp_documents (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  doc_no text not null,                -- allocated via allocate_number(entity, 'DOC') by the API
  title text not null,
  category text not null default 'general',
  storage_path text,                   -- current version's object path in the 'erp-documents' bucket
  mime_type text,
  size_bytes bigint,
  version int not null default 1,
  versions jsonb not null default '[]'::jsonb,   -- prior versions: [{version, storage_path, mime_type, size_bytes, replaced_at}]
  uploaded_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, doc_no)
);

-- Any master/transaction record can carry attachments via (table_name, record_id).
create table if not exists public.erp_document_links (
  document_id uuid not null references public.erp_documents(id) on delete cascade,
  table_name text not null,
  record_id uuid not null,
  primary key (document_id, table_name, record_id)
);

create index if not exists erp_documents_entity_idx on public.erp_documents (entity_id, created_at);
create index if not exists erp_document_links_record_idx on public.erp_document_links (table_name, record_id);

-- ============================================================ assets
create table if not exists public.assets (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  asset_no text not null,              -- allocated via allocate_number(entity, 'AST') by the API
  name text not null,
  category text,
  acquisition_date date not null default current_date,
  cost numeric(14,2) not null default 0,
  method text not null default 'straight_line' check (method in ('straight_line','wdv')),
  rate_percent numeric(5,2) not null default 15,          -- WDV annual rate
  useful_life_months int not null default 60,             -- straight-line life
  salvage_value numeric(14,2) not null default 0,
  accumulated_depreciation numeric(14,2) not null default 0,
  status text not null default 'active' check (status in ('active','disposed')),
  purchase_invoice_id uuid,            -- optional reference to the purchase invoice it came from
  voucher_id uuid references public.vouchers(id),         -- acquisition voucher (if any)
  disposal jsonb,                      -- {proceeds, gain_loss, date, voucher_id} once disposed
  created_at timestamptz not null default now(),
  unique (entity_id, asset_no)
);

create index if not exists assets_entity_status_idx on public.assets (entity_id, status);

-- ============================================================ depreciation runs (header/lines, backbone rule 3)
create table if not exists public.depreciation_runs (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  period_code text not null check (period_code ~ '^\d{4}-(0[1-9]|1[0-2])$'),  -- e.g. '2026-07'
  status text not null default 'draft' check (status in ('draft','posted')),
  total_amount numeric(14,2) not null default 0,
  voucher_id uuid references public.vouchers(id),
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, period_code)
);

create table if not exists public.depreciation_lines (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.depreciation_runs(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  asset_id uuid not null references public.assets(id),
  amount numeric(14,2) not null default 0,
  book_value_before numeric(14,2) not null default 0,
  book_value_after numeric(14,2) not null default 0
);

create index if not exists depreciation_lines_run_idx on public.depreciation_lines (run_id);

-- ============================================================ generate depreciation (draft only)
-- Monthly amount per active asset acquired on or before the period end:
--   straight_line: (cost - salvage) / useful_life_months
--   wdv:           (cost - accumulated) * (rate_percent/100) / 12
-- Capped so accumulated never exceeds (cost - salvage); zero lines are skipped.
-- Mirrored by computeDepreciationMonth/Schedule in packages/shared (keep the two in sync).
create or replace function public.generate_depreciation(p_run uuid, p_actor uuid default null)
returns integer language plpgsql security definer set search_path = public as $$
declare
  r depreciation_runs%rowtype;
  a record;
  d_end date; n int := 0;
  v_amount numeric(14,2); v_base numeric(14,2); v_before numeric(14,2);
  t_total numeric(14,2) := 0;
begin
  select * into r from depreciation_runs where id = p_run for update;
  if not found then raise exception 'depreciation run not found'; end if;
  if r.status <> 'draft' then raise exception 'run is %, only draft can be generated', r.status; end if;

  d_end := (to_date(r.period_code || '-01', 'YYYY-MM-DD') + interval '1 month - 1 day')::date;
  delete from depreciation_lines where run_id = p_run;

  for a in
    select * from assets
    where entity_id = r.entity_id and status = 'active' and acquisition_date <= d_end
    order by asset_no
  loop
    if a.method = 'straight_line' then
      if coalesce(a.useful_life_months, 0) <= 0 then continue; end if;
      v_amount := round((a.cost - a.salvage_value) / a.useful_life_months, 2);
    else
      v_amount := round((a.cost - a.accumulated_depreciation) * (a.rate_percent / 100) / 12, 2);
    end if;
    v_base := a.cost - a.salvage_value;              -- depreciable base
    if a.accumulated_depreciation + v_amount > v_base then
      v_amount := round(v_base - a.accumulated_depreciation, 2);
    end if;
    if v_amount <= 0 then continue; end if;          -- fully depreciated (or zero-cost) assets skip

    v_before := a.cost - a.accumulated_depreciation;
    insert into depreciation_lines (run_id, entity_id, asset_id, amount, book_value_before, book_value_after)
    values (p_run, r.entity_id, a.id, v_amount, v_before, v_before - v_amount);
    n := n + 1;
    t_total := t_total + v_amount;
  end loop;

  update depreciation_runs set total_amount = t_total where id = p_run;
  return n;
end $$;
revoke all on function public.generate_depreciation from public, anon, authenticated;

-- ============================================================ post depreciation (backbone rule 4: one transaction)
-- Dr 5400 Depreciation Expense (total) / Cr 1510 Accumulated Depreciation (total),
-- dated the last day of the period. No approve step: draft posts directly.
create or replace function public.post_depreciation(p_run uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  r depreciation_runs%rowtype;
  l record;
  v_total numeric(14,2); v_diff numeric(14,2);
  acc_exp uuid; acc_accdep uuid;
  lines jsonb; v_id uuid; d_end date;
begin
  select * into r from depreciation_runs where id = p_run for update;
  if not found then raise exception 'depreciation run not found'; end if;
  if r.status <> 'draft' then raise exception 'run is %, only draft can be posted', r.status; end if;

  select coalesce(sum(amount), 0) into v_total from depreciation_lines where run_id = p_run;
  if v_total <= 0 then raise exception 'run has no lines (generate first)'; end if;
  -- Rounding guard: header total must match the lines within ±0.05; the lines' sum is authoritative.
  v_diff := round(r.total_amount - v_total, 2);
  if abs(v_diff) > 0.05 then
    raise exception 'run total % does not match lines % (diff %)', r.total_amount, v_total, v_diff;
  end if;

  select id into acc_exp    from ledger_accounts where entity_id = r.entity_id and account_no = '5400';
  select id into acc_accdep from ledger_accounts where entity_id = r.entity_id and account_no = '1510';
  if acc_exp is null or acc_accdep is null then
    raise exception 'ledger accounts 5400/1510 not configured for this entity';
  end if;

  lines := jsonb_build_array(
    jsonb_build_object('account_id', acc_exp,    'debit', v_total, 'credit', 0, 'memo', 'Depreciation ' || r.period_code),
    jsonb_build_object('account_id', acc_accdep, 'debit', 0, 'credit', v_total, 'memo', 'Accumulated depreciation ' || r.period_code));

  d_end := (to_date(r.period_code || '-01', 'YYYY-MM-DD') + interval '1 month - 1 day')::date;
  v_id := post_voucher(r.entity_id, d_end, 'asset', r.id, 'Depreciation run ' || r.period_code, lines, p_actor);

  for l in select asset_id, amount from depreciation_lines where run_id = p_run loop
    update assets set accumulated_depreciation = accumulated_depreciation + l.amount where id = l.asset_id;
  end loop;

  update depreciation_runs set status = 'posted', voucher_id = v_id, total_amount = v_total where id = p_run;
  return v_id;
end $$;
revoke all on function public.post_depreciation from public, anon, authenticated;

-- ============================================================ dispose asset (backbone rule 4: one transaction)
-- book value = cost - accumulated; gain/loss = proceeds - book value.
-- Dr 1100 Cash (proceeds) + Dr 1510 Accumulated Depreciation (accumulated)
-- Cr 1500 Fixed Assets (cost), balance line:
--   gain > 0 → Cr 4100 Sales Revenue  memo 'asset disposal gain'
--   loss     → Dr 5500 Inventory Adjustment (misc expense) memo 'asset disposal loss'
create or replace function public.dispose_asset(p_asset uuid, p_proceeds numeric, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  a assets%rowtype;
  v_proceeds numeric(14,2); v_book numeric(14,2); v_gl numeric(14,2);
  acc_cash uuid; acc_accdep uuid; acc_fa uuid; acc_gain uuid; acc_loss uuid;
  lines jsonb := '[]'::jsonb; v_id uuid;
begin
  select * into a from assets where id = p_asset for update;
  if not found then raise exception 'asset not found'; end if;
  if a.status <> 'active' then raise exception 'asset is %, only active assets can be disposed', a.status; end if;
  v_proceeds := round(coalesce(p_proceeds, 0), 2);
  if v_proceeds < 0 then raise exception 'proceeds must be >= 0'; end if;

  v_book := a.cost - a.accumulated_depreciation;
  v_gl := v_proceeds - v_book;                     -- positive = gain, negative = loss

  select id into acc_cash   from ledger_accounts where entity_id = a.entity_id and account_no = '1100';
  select id into acc_accdep from ledger_accounts where entity_id = a.entity_id and account_no = '1510';
  select id into acc_fa     from ledger_accounts where entity_id = a.entity_id and account_no = '1500';
  select id into acc_gain   from ledger_accounts where entity_id = a.entity_id and account_no = '4100';
  select id into acc_loss   from ledger_accounts where entity_id = a.entity_id and account_no = '5500';
  if acc_cash is null or acc_accdep is null or acc_fa is null or acc_gain is null or acc_loss is null then
    raise exception 'ledger accounts 1100/1510/1500/4100/5500 not configured for this entity';
  end if;

  if v_proceeds > 0 then
    lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_cash, 'debit', v_proceeds, 'credit', 0, 'memo', 'Disposal proceeds ' || a.asset_no));
  end if;
  if a.accumulated_depreciation > 0 then
    lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_accdep, 'debit', a.accumulated_depreciation, 'credit', 0, 'memo', 'Reverse accumulated depreciation ' || a.asset_no));
  end if;
  if a.cost > 0 then
    lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_fa, 'debit', 0, 'credit', a.cost, 'memo', 'Derecognise asset ' || a.asset_no));
  end if;
  if v_gl > 0 then
    lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_gain, 'debit', 0, 'credit', v_gl, 'memo', 'asset disposal gain ' || a.asset_no));
  elsif v_gl < 0 then
    lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_loss, 'debit', -v_gl, 'credit', 0, 'memo', 'asset disposal loss ' || a.asset_no));
  end if;
  if jsonb_array_length(lines) < 2 then
    raise exception 'nothing to post: asset % has zero cost and zero proceeds', a.asset_no;
  end if;

  v_id := post_voucher(a.entity_id, current_date, 'asset', a.id, 'Disposal of asset ' || a.asset_no || ' — ' || a.name, lines, p_actor);

  update assets
     set status = 'disposed',
         disposal = jsonb_build_object('proceeds', v_proceeds, 'gain_loss', v_gl,
                                       'date', to_char(current_date, 'YYYY-MM-DD'), 'voucher_id', v_id)
   where id = p_asset;
  return v_id;
end $$;
revoke all on function public.dispose_asset from public, anon, authenticated;

-- ============================================================ audit + RLS
do $$ declare t text;
begin
  foreach t in array array['assets','depreciation_runs']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

do $$ declare t text;
begin
  foreach t in array array['assets','depreciation_runs','depreciation_lines','erp_documents','erp_document_links']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
    -- no insert/update/delete policies: only the service role (API tier) can write
  end loop;
end $$;

-- ============================================================ privileges → admin role
insert into public.erp_privileges (code, module, description) values
  ('assets.assets.read',        'assets', 'View assets'),
  ('assets.assets.write',       'assets', 'Manage assets & disposals'),
  ('assets.depreciation.read',  'assets', 'View depreciation runs'),
  ('assets.depreciation.write', 'assets', 'Create/generate draft depreciation runs'),
  ('assets.depreciation.post',  'assets', 'Post depreciation runs to GL'),
  ('assets.reports.read',       'assets', 'Run asset reports'),
  ('dms.documents.read',        'dms',    'View & download documents'),
  ('dms.documents.write',       'dms',    'Upload, version, link & delete documents'),
  ('sysadmin.dataio.read',      'sysadmin', 'Export master data as CSV'),
  ('sysadmin.dataio.write',     'sysadmin', 'Import master data from CSV')
on conflict (code) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p
where r.name = 'admin' and (p.module in ('assets', 'dms') or p.code like 'sysadmin.dataio.%')
on conflict do nothing;
