-- Phase 2: General Ledger — chart of accounts, fiscal periods, vouchers, posting engine, GL journals
-- Also: grant admin to additional owner account(s).

-- ============================================================ access fix
insert into public.erp_user_roles (user_id, role_id, entity_id)
select u.id, r.id, e.id
from auth.users u, public.erp_roles r, public.legal_entities e
where u.email in ('sivavasusp@gmail.com', 'govenkat99@gmail.com')
  and r.name = 'admin' and e.code = 'PROFIX'
on conflict do nothing;

-- ============================================================ chart of accounts
create table if not exists public.ledger_groups (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,          -- 1000 Assets, 2000 Liabilities, ...
  name text not null,
  kind text not null check (kind in ('asset','liability','equity','income','expense')),
  parent_id uuid references public.ledger_groups(id)
);

create table if not exists public.ledger_accounts (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  account_no text not null,
  name text not null,
  group_id uuid not null references public.ledger_groups(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, account_no)
);

create table if not exists public.fiscal_periods (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  period_code text not null,          -- e.g. 2026-04
  start_date date not null,
  end_date date not null,
  status text not null default 'open' check (status in ('open','closed')),
  unique (entity_id, period_code)
);

-- ============================================================ vouchers
create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  voucher_no text not null,
  voucher_date date not null,
  source_module text not null,        -- gl, sales, purchase, inventory, payroll, asset
  source_doc_id uuid,
  description text,
  posted_at timestamptz not null default now(),
  posted_by uuid,
  unique (entity_id, voucher_no)
);

create table if not exists public.voucher_lines (
  id uuid primary key default gen_random_uuid(),
  voucher_id uuid not null references public.vouchers(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  account_id uuid not null references public.ledger_accounts(id),
  debit numeric(14,2) not null default 0 check (debit >= 0),
  credit numeric(14,2) not null default 0 check (credit >= 0),
  dimensions jsonb not null default '{}'::jsonb,
  memo text
);
create index if not exists voucher_lines_account_idx on public.voucher_lines (account_id);
create index if not exists vouchers_entity_date_idx on public.vouchers (entity_id, voucher_date);

create table if not exists public.posting_profiles (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  module text not null,               -- sales, purchase, inventory, payroll, asset, service
  event text not null,                -- invoice, receipt, grn, adjustment, payrun, depreciation...
  debit_account_id uuid references public.ledger_accounts(id),
  credit_account_id uuid references public.ledger_accounts(id),
  unique (entity_id, module, event)
);

-- ============================================================ posting engine (backbone rule 4)
-- One atomic call: validate period + balance, allocate voucher number, write header + lines.
create or replace function public.post_voucher(
  p_entity uuid, p_date date, p_source text, p_source_id uuid,
  p_description text, p_lines jsonb, p_actor uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid; v_no text; dr numeric(14,2) := 0; cr numeric(14,2) := 0;
  l jsonb; n int := 0;
begin
  if p_lines is null or jsonb_array_length(p_lines) < 2 then
    raise exception 'a voucher needs at least 2 lines';
  end if;
  if not exists (
    select 1 from fiscal_periods
     where entity_id = p_entity and status = 'open'
       and p_date between start_date and end_date
  ) then
    raise exception 'no open fiscal period for date %', p_date;
  end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    dr := dr + coalesce((l->>'debit')::numeric, 0);
    cr := cr + coalesce((l->>'credit')::numeric, 0);
  end loop;
  if round(dr, 2) <> round(cr, 2) or round(dr, 2) = 0 then
    raise exception 'voucher not balanced: debit % vs credit %', dr, cr;
  end if;
  v_no := allocate_number(p_entity, 'VCH');
  insert into vouchers (entity_id, voucher_no, voucher_date, source_module, source_doc_id, description, posted_by)
  values (p_entity, v_no, p_date, p_source, p_source_id, p_description, p_actor)
  returning id into v_id;
  for l in select * from jsonb_array_elements(p_lines) loop
    n := n + 1;
    insert into voucher_lines (voucher_id, entity_id, line_no, account_id, debit, credit, dimensions, memo)
    values (v_id, p_entity, n, (l->>'account_id')::uuid,
            coalesce((l->>'debit')::numeric, 0), coalesce((l->>'credit')::numeric, 0),
            coalesce(l->'dimensions', '{}'::jsonb), l->>'memo');
  end loop;
  return v_id;
end $$;
revoke all on function public.post_voucher from public, anon, authenticated;

-- ============================================================ manual GL journals (header/lines)
create table if not exists public.gl_journals (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  journal_no text not null,
  journal_date date not null default current_date,
  description text,
  status text not null default 'draft' check (status in ('draft','posted','cancelled')),
  voucher_id uuid references public.vouchers(id),
  total_debit numeric(14,2) not null default 0,
  total_credit numeric(14,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, journal_no)
);

create table if not exists public.gl_journal_lines (
  id uuid primary key default gen_random_uuid(),
  journal_id uuid not null references public.gl_journals(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  account_id uuid not null references public.ledger_accounts(id),
  debit numeric(14,2) not null default 0,
  credit numeric(14,2) not null default 0,
  memo text
);

create or replace function public.post_gl_journal(p_journal uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare j gl_journals%rowtype; v_id uuid; lines jsonb;
begin
  select * into j from gl_journals where id = p_journal for update;
  if not found then raise exception 'journal not found'; end if;
  if j.status <> 'draft' then raise exception 'journal is %, only draft can be posted', j.status; end if;
  select jsonb_agg(jsonb_build_object('account_id', account_id, 'debit', debit, 'credit', credit, 'memo', memo) order by line_no)
    into lines from gl_journal_lines where journal_id = p_journal;
  v_id := post_voucher(j.entity_id, j.journal_date, 'gl', j.id, j.description, lines, p_actor);
  update gl_journals set status = 'posted', voucher_id = v_id where id = p_journal;
  return v_id;
end $$;
revoke all on function public.post_gl_journal from public, anon, authenticated;

-- ============================================================ report functions
create or replace function public.gl_trial_balance(p_entity uuid, p_from date, p_to date)
returns table (account_id uuid, account_no text, account_name text, group_code text, group_name text, kind text, debit numeric, credit numeric)
language sql security definer set search_path = public as $$
  select a.id, a.account_no, a.name, g.code, g.name, g.kind,
         coalesce(sum(t.debit), 0), coalesce(sum(t.credit), 0)
  from ledger_accounts a
  join ledger_groups g on g.id = a.group_id
  left join (
    select vl.account_id, vl.debit, vl.credit
    from voucher_lines vl join vouchers v on v.id = vl.voucher_id
    where vl.entity_id = p_entity and v.voucher_date between p_from and p_to
  ) t on t.account_id = a.id
  where a.entity_id = p_entity
  group by a.id, a.account_no, a.name, g.code, g.name, g.kind
  order by a.account_no
$$;
revoke all on function public.gl_trial_balance from public, anon, authenticated;

create or replace function public.gl_ledger(p_entity uuid, p_account uuid, p_from date, p_to date)
returns table (voucher_no text, voucher_date date, source_module text, description text, memo text, debit numeric, credit numeric)
language sql security definer set search_path = public as $$
  select v.voucher_no, v.voucher_date, v.source_module, v.description, vl.memo, vl.debit, vl.credit
  from voucher_lines vl join vouchers v on v.id = vl.voucher_id
  where vl.entity_id = p_entity and vl.account_id = p_account
    and v.voucher_date between p_from and p_to
  order by v.voucher_date, v.voucher_no, vl.line_no
$$;
revoke all on function public.gl_ledger from public, anon, authenticated;

-- ============================================================ audit + RLS
do $$ declare t text;
begin
  foreach t in array array['ledger_accounts','posting_profiles','gl_journals','fiscal_periods']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

do $$ declare t text;
begin
  foreach t in array array['ledger_groups','ledger_accounts','fiscal_periods','vouchers','voucher_lines','posting_profiles','gl_journals','gl_journal_lines']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
  end loop;
end $$;

-- ============================================================ seeds
insert into public.ledger_groups (code, name, kind) values
  ('1000', 'Assets', 'asset'),
  ('2000', 'Liabilities', 'liability'),
  ('3000', 'Equity', 'equity'),
  ('4000', 'Income', 'income'),
  ('5000', 'Expenses', 'expense')
on conflict (code) do nothing;

insert into public.ledger_accounts (entity_id, account_no, name, group_id)
select e.id, v.no, v.nm, g.id
from (values
  ('1100', 'Cash in Hand',            '1000'),
  ('1110', 'Bank',                    '1000'),
  ('1120', 'UPI Clearing',            '1000'),
  ('1200', 'Accounts Receivable',     '1000'),
  ('1300', 'Inventory',               '1000'),
  ('1400', 'GST Input Credit',        '1000'),
  ('1500', 'Fixed Assets',            '1000'),
  ('1510', 'Accumulated Depreciation','1000'),
  ('2100', 'Accounts Payable',        '2000'),
  ('2200', 'GST Output CGST',         '2000'),
  ('2210', 'GST Output SGST',         '2000'),
  ('2300', 'Salaries Payable',        '2000'),
  ('2310', 'Statutory Payable (PF/ESI/PT/TDS)', '2000'),
  ('3100', 'Owner Capital',           '3000'),
  ('4100', 'Sales Revenue',           '4000'),
  ('4200', 'Service Revenue',         '4000'),
  ('5100', 'Cost of Goods Sold',      '5000'),
  ('5200', 'Salaries Expense',        '5000'),
  ('5300', 'Rent Expense',            '5000'),
  ('5400', 'Depreciation Expense',    '5000'),
  ('5500', 'Inventory Adjustment',    '5000')
) v(no, nm, grp)
join public.ledger_groups g on g.code = v.grp
cross join (select id from public.legal_entities where code = 'PROFIX') e
on conflict (entity_id, account_no) do nothing;

-- FY 2026-27 monthly periods (Apr 2026 – Mar 2027), open
insert into public.fiscal_periods (entity_id, period_code, start_date, end_date)
select e.id, to_char(d, 'YYYY-MM'), d::date, (d + interval '1 month' - interval '1 day')::date
from generate_series('2026-04-01'::date, '2027-03-01'::date, interval '1 month') d
cross join (select id from public.legal_entities where code = 'PROFIX') e
on conflict (entity_id, period_code) do nothing;

-- GL privileges → admin role
insert into public.erp_privileges (code, module, description) values
  ('gl.accounts.read',  'gl', 'View chart of accounts'),
  ('gl.accounts.write', 'gl', 'Manage ledger accounts'),
  ('gl.journals.read',  'gl', 'View GL journals'),
  ('gl.journals.write', 'gl', 'Create/edit draft journals'),
  ('gl.journals.post',  'gl', 'Post GL journals'),
  ('gl.vouchers.read',  'gl', 'Browse vouchers'),
  ('gl.profiles.read',  'gl', 'View posting profiles'),
  ('gl.profiles.write', 'gl', 'Manage posting profiles'),
  ('gl.reports.read',   'gl', 'Run GL reports')
on conflict (code) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p
where r.name = 'admin' and p.module = 'gl'
on conflict do nothing;
