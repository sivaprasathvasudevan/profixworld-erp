-- Phase 3: Inventory + Warehouse — items with dimensions, warehouses, inventory transactions,
-- on-hand, transfer & movement journals with posting. See CLAUDE.md backbone rules.

-- ============================================================ items
create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  item_no text not null,               -- allocated via allocate_number(entity, 'ITEM') by the API
  name text not null,
  item_type text not null default 'product' check (item_type in ('product','part','service')),
  category text,
  uom text not null default 'pcs',
  gst_rate numeric(5,2) not null default 18,
  sales_price numeric(14,2) not null default 0,
  avg_cost numeric(14,4) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, item_no)
);

-- ============================================================ dimensions (Model / Specification / Size / Colour)
create table if not exists public.dimension_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,           -- MODEL, SPEC, SIZE, COLOUR
  name text not null
);

create table if not exists public.dimension_values (
  id uuid primary key default gen_random_uuid(),
  type_id uuid not null references public.dimension_types(id) on delete cascade,
  value text not null,
  unique (type_id, value)
);

create table if not exists public.item_dimensions (
  item_id uuid not null references public.items(id) on delete cascade,
  dimension_value_id uuid not null references public.dimension_values(id) on delete cascade,
  primary key (item_id, dimension_value_id)
);

-- ============================================================ warehouses
create table if not exists public.warehouses (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  warehouse_no text not null,
  name text not null,
  branch_id uuid references public.branches(id),
  is_store boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, warehouse_no)
);

-- ============================================================ inventory transactions (positive = in, negative = out)
create table if not exists public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  item_id uuid not null references public.items(id),
  warehouse_id uuid not null references public.warehouses(id),
  qty numeric(14,3) not null,
  unit_cost numeric(14,4) not null default 0,
  source_module text not null,         -- transfer, movement, sales, purchase, service...
  source_doc_id uuid,
  trans_date date not null default current_date,
  created_at timestamptz not null default now()
);
create index if not exists inventory_transactions_entity_item_wh_idx
  on public.inventory_transactions (entity_id, item_id, warehouse_id);

-- ============================================================ on-hand
create or replace function public.inv_on_hand(p_entity uuid)
returns table (item_id uuid, item_no text, item_name text, warehouse_id uuid, warehouse_no text, qty numeric)
language sql security definer set search_path = public as $$
  select i.id, i.item_no, i.name, w.id, w.warehouse_no, sum(t.qty)
  from inventory_transactions t
  join items i on i.id = t.item_id
  join warehouses w on w.id = t.warehouse_id
  where t.entity_id = p_entity
  group by i.id, i.item_no, i.name, w.id, w.warehouse_no
  order by i.item_no, w.warehouse_no
$$;
revoke all on function public.inv_on_hand from public, anon, authenticated;

-- ============================================================ transfer journals (header/lines, draft → posted)
create table if not exists public.transfer_journals (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  journal_no text not null,
  journal_date date not null default current_date,
  description text,
  status text not null default 'draft' check (status in ('draft','posted')),
  from_warehouse_id uuid references public.warehouses(id),
  to_warehouse_id uuid references public.warehouses(id),
  total_qty numeric(14,3) not null default 0,
  posted_by uuid,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, journal_no)
);

create table if not exists public.transfer_journal_lines (
  id uuid primary key default gen_random_uuid(),
  journal_id uuid not null references public.transfer_journals(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  item_id uuid not null references public.items(id),
  qty numeric(14,3) not null
);

-- ============================================================ movement journals (signed adjustments, GL-posted)
create table if not exists public.movement_journals (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  journal_no text not null,
  journal_date date not null default current_date,
  description text,
  status text not null default 'draft' check (status in ('draft','posted')),
  voucher_id uuid references public.vouchers(id),
  total_qty numeric(14,3) not null default 0,
  posted_by uuid,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, journal_no)
);

create table if not exists public.movement_journal_lines (
  id uuid primary key default gen_random_uuid(),
  journal_id uuid not null references public.movement_journals(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  item_id uuid not null references public.items(id),
  warehouse_id uuid not null references public.warehouses(id),
  qty numeric(14,3) not null,          -- signed: positive = in, negative = out
  reason text
);

-- ============================================================ posting: transfer journal (backbone rule 4)
create or replace function public.post_transfer_journal(p_journal uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare j transfer_journals%rowtype; l record; n int := 0;
begin
  select * into j from transfer_journals where id = p_journal for update;
  if not found then raise exception 'transfer journal not found'; end if;
  if j.status <> 'draft' then raise exception 'journal is %, only draft can be posted', j.status; end if;
  if j.from_warehouse_id is null or j.to_warehouse_id is null then
    raise exception 'from and to warehouse are required';
  end if;
  if j.from_warehouse_id = j.to_warehouse_id then
    raise exception 'from and to warehouse must differ';
  end if;
  for l in
    select tl.line_no, tl.item_id, tl.qty, i.avg_cost
    from transfer_journal_lines tl join items i on i.id = tl.item_id
    where tl.journal_id = p_journal order by tl.line_no
  loop
    n := n + 1;
    if coalesce(l.qty, 0) <= 0 then raise exception 'line %: qty must be positive', l.line_no; end if;
    insert into inventory_transactions (entity_id, item_id, warehouse_id, qty, unit_cost, source_module, source_doc_id, trans_date)
    values (j.entity_id, l.item_id, j.from_warehouse_id, -l.qty, l.avg_cost, 'transfer', j.id, j.journal_date),
           (j.entity_id, l.item_id, j.to_warehouse_id,    l.qty, l.avg_cost, 'transfer', j.id, j.journal_date);
  end loop;
  if n = 0 then raise exception 'journal has no lines'; end if;
  update transfer_journals set status = 'posted', posted_by = p_actor where id = p_journal;
  return p_journal;
end $$;
revoke all on function public.post_transfer_journal from public, anon, authenticated;

-- ============================================================ posting: movement journal (inventory + GL voucher)
create or replace function public.post_movement_journal(p_journal uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  j movement_journals%rowtype; prof posting_profiles%rowtype;
  l record; n int := 0; v_total numeric(14,2) := 0; v_id uuid; lines jsonb;
begin
  select * into j from movement_journals where id = p_journal for update;
  if not found then raise exception 'movement journal not found'; end if;
  if j.status <> 'draft' then raise exception 'journal is %, only draft can be posted', j.status; end if;
  select * into prof from posting_profiles
   where entity_id = j.entity_id and module = 'inventory' and event = 'adjustment';
  if not found or prof.debit_account_id is null or prof.credit_account_id is null then
    raise exception 'posting profile inventory/adjustment not configured';
  end if;
  for l in
    select ml.line_no, ml.item_id, ml.warehouse_id, ml.qty, i.avg_cost
    from movement_journal_lines ml join items i on i.id = ml.item_id
    where ml.journal_id = p_journal order by ml.line_no
  loop
    n := n + 1;
    if coalesce(l.qty, 0) = 0 then raise exception 'line %: qty must not be zero', l.line_no; end if;
    insert into inventory_transactions (entity_id, item_id, warehouse_id, qty, unit_cost, source_module, source_doc_id, trans_date)
    values (j.entity_id, l.item_id, l.warehouse_id, l.qty, l.avg_cost, 'movement', j.id, j.journal_date);
    v_total := v_total + round(l.qty * l.avg_cost, 2);
  end loop;
  if n = 0 then raise exception 'journal has no lines'; end if;
  -- GL voucher: debit_account for positive total value, credit_account the other side (flipped when negative).
  -- Zero net value (e.g. all items at zero avg_cost) posts inventory only — a voucher cannot balance on 0.
  if round(v_total, 2) <> 0 then
    if v_total > 0 then
      lines := jsonb_build_array(
        jsonb_build_object('account_id', prof.debit_account_id,  'debit', v_total, 'credit', 0, 'memo', j.journal_no),
        jsonb_build_object('account_id', prof.credit_account_id, 'debit', 0, 'credit', v_total, 'memo', j.journal_no));
    else
      lines := jsonb_build_array(
        jsonb_build_object('account_id', prof.credit_account_id, 'debit', -v_total, 'credit', 0, 'memo', j.journal_no),
        jsonb_build_object('account_id', prof.debit_account_id,  'debit', 0, 'credit', -v_total, 'memo', j.journal_no));
    end if;
    v_id := post_voucher(j.entity_id, j.journal_date, 'inventory', j.id,
                         coalesce(j.description, 'Inventory movement ' || j.journal_no), lines, p_actor);
  end if;
  update movement_journals set status = 'posted', voucher_id = v_id, posted_by = p_actor where id = p_journal;
  return p_journal;
end $$;
revoke all on function public.post_movement_journal from public, anon, authenticated;

-- ============================================================ audit + RLS
do $$ declare t text;
begin
  foreach t in array array['items','warehouses','transfer_journals','movement_journals']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

do $$ declare t text;
begin
  foreach t in array array['items','dimension_types','dimension_values','item_dimensions','warehouses','inventory_transactions','transfer_journals','transfer_journal_lines','movement_journals','movement_journal_lines']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
    -- no insert/update/delete policies: only the service role (API tier) can write
  end loop;
end $$;

-- ============================================================ seeds
insert into public.dimension_types (code, name) values
  ('MODEL',  'Model'),
  ('SPEC',   'Specification'),
  ('SIZE',   'Size'),
  ('COLOUR', 'Colour')
on conflict (code) do nothing;

-- One warehouse per existing PROFIX branch
insert into public.warehouses (entity_id, warehouse_no, name, branch_id, is_store)
select b.entity_id, 'WH-' || b.branch_no, b.name, b.id, b.is_store
from public.branches b
join public.legal_entities e on e.id = b.entity_id
where e.code = 'PROFIX'
on conflict (entity_id, warehouse_no) do nothing;

-- Journal number sequences
insert into public.number_sequences (entity_id, code, prefix, padding)
select e.id, v.code, v.prefix, 5
from (values ('TRJ','TRJ-'), ('MVJ','MVJ-')) v(code, prefix)
cross join (select id from public.legal_entities where code = 'PROFIX') e
on conflict (entity_id, code) do nothing;

-- Posting profile: inventory/adjustment → Dr 5500 Inventory Adjustment / Cr 1300 Inventory
insert into public.posting_profiles (entity_id, module, event, debit_account_id, credit_account_id)
select e.id, 'inventory', 'adjustment', d.id, c.id
from public.legal_entities e
join public.ledger_accounts d on d.entity_id = e.id and d.account_no = '5500'
join public.ledger_accounts c on c.entity_id = e.id and c.account_no = '1300'
where e.code = 'PROFIX'
on conflict (entity_id, module, event) do nothing;

-- Inventory privileges → admin role
insert into public.erp_privileges (code, module, description) values
  ('inv.items.read',       'inv', 'View items'),
  ('inv.items.write',      'inv', 'Manage items'),
  ('inv.dimensions.read',  'inv', 'View dimension types & values'),
  ('inv.dimensions.write', 'inv', 'Manage dimension types & values'),
  ('inv.warehouses.read',  'inv', 'View warehouses'),
  ('inv.warehouses.write', 'inv', 'Manage warehouses'),
  ('inv.journals.read',    'inv', 'View transfer & movement journals'),
  ('inv.journals.write',   'inv', 'Create/edit draft transfer & movement journals'),
  ('inv.journals.post',    'inv', 'Post transfer & movement journals'),
  ('inv.onhand.read',      'inv', 'View on-hand stock'),
  ('inv.reports.read',     'inv', 'Run inventory reports')
on conflict (code) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p
where r.name = 'admin' and p.module = 'inv'
on conflict do nothing;
