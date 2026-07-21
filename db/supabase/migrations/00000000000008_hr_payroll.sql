-- Phase 6: HR & Payroll + Employee Management — departments/positions, employees linked to
-- legacy staff_members, employment history, salary structures, payroll runs generated from
-- legacy staff_attendance with statutory deductions and GL posting. See CLAUDE.md backbone rules.
--
-- LEGACY CONSTRAINT: staff_members, staff_attendance, staff_roster, staff_leave, staff_advances,
-- staff_incentives are LIVE (the staff/me PWAs write them) and are NOT altered here.
-- employees.staff_member_id is a nullable uuid link (staff_members.id is uuid in the baseline);
-- payroll only READS staff_attendance / staff_incentives.

-- ============================================================ masters: departments & positions
create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  code text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, code)
);

create table if not exists public.positions (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  code text not null,
  title text not null,
  department_id uuid references public.departments(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, code)
);

-- ============================================================ employees
-- staff_member_id: link to the legacy staff app identity. on delete set null so the live
-- staff PWA can still delete staff_members rows without being blocked by the ERP.
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  employee_no text not null,            -- allocated via allocate_number(entity, 'EMP') by the API
  staff_member_id uuid references public.staff_members(id) on delete set null,
  display_name text not null,
  phone text,
  email text,
  pan text,
  aadhaar_last4 text,
  uan text,
  esi_no text,
  bank_account text,
  bank_ifsc text,
  join_date date,
  exit_date date,
  department_id uuid references public.departments(id),
  position_id uuid references public.positions(id),
  branch_id uuid references public.branches(id),   -- workplace assignment snapshot
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, employee_no)
);

create index if not exists employees_entity_active_idx on public.employees (entity_id, active);
create index if not exists employees_staff_member_idx on public.employees (staff_member_id);

-- ============================================================ employment history (position/dept/workplace/salary over time)
create table if not exists public.employment_history (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  position_id uuid references public.positions(id),
  department_id uuid references public.departments(id),
  branch_id uuid references public.branches(id),
  from_date date not null,
  to_date date,                          -- null = current assignment
  monthly_salary numeric(14,2),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists employment_history_employee_idx on public.employment_history (employee_id, from_date);

-- ============================================================ salary structures (one active structure per employee)
create table if not exists public.salary_structures (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  employee_id uuid not null unique references public.employees(id) on delete cascade,
  basic numeric(14,2) not null default 0,
  hra numeric(14,2) not null default 0,
  allowances numeric(14,2) not null default 0,
  pf_percent numeric(5,2) not null default 12,
  esi_percent numeric(5,2) not null default 0.75,
  pt_amount numeric(14,2) not null default 200,
  tds_amount numeric(14,2) not null default 0,
  updated_at timestamptz not null default now()
);

-- ============================================================ payroll runs (header/lines, backbone rule 3)
create table if not exists public.payroll_runs (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  period_code text not null check (period_code ~ '^\d{4}-(0[1-9]|1[0-2])$'),  -- e.g. '2026-07'
  status text not null default 'draft' check (status in ('draft','approved','posted')),
  total_gross numeric(14,2) not null default 0,
  total_net numeric(14,2) not null default 0,
  voucher_id uuid references public.vouchers(id),
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, period_code)
);

create table if not exists public.payroll_lines (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.payroll_runs(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  employee_id uuid not null references public.employees(id),
  days_present numeric(5,2) not null default 0,
  days_in_month int not null default 30,
  basic numeric(14,2) not null default 0,
  hra numeric(14,2) not null default 0,
  allowances numeric(14,2) not null default 0,
  gross numeric(14,2) not null default 0,
  pf numeric(14,2) not null default 0,
  esi numeric(14,2) not null default 0,
  pt numeric(14,2) not null default 0,
  tds numeric(14,2) not null default 0,
  advance_recovery numeric(14,2) not null default 0,
  incentives numeric(14,2) not null default 0,
  net numeric(14,2) not null default 0
);

create index if not exists payroll_lines_run_idx on public.payroll_lines (run_id);

-- ============================================================ generate payroll (reads LEGACY attendance/incentives)
-- Attendance: legacy staff_attendance has (staff_id uuid, clock_in timestamptz, clock_out ...);
-- a "present day" = a distinct IST calendar day with at least one clock_in.
-- Incentives: legacy staff_incentives has (staff_id uuid, amount integer, created_at timestamptz).
-- Employees without a staff link are assumed fully present (days_present = days_in_month, incentives 0).
create or replace function public.generate_payroll(p_run uuid, p_actor uuid default null)
returns integer language plpgsql security definer set search_path = public as $$
declare
  r payroll_runs%rowtype;
  e record;
  d_start date; d_end date; dim int; n int := 0;
  v_present numeric(5,2); v_factor numeric;
  v_basic numeric(14,2); v_hra numeric(14,2); v_allow numeric(14,2); v_gross numeric(14,2);
  v_pf numeric(14,2); v_esi numeric(14,2); v_pt numeric(14,2); v_tds numeric(14,2);
  v_inc numeric(14,2); v_net numeric(14,2);
  t_gross numeric(14,2) := 0; t_net numeric(14,2) := 0;
begin
  select * into r from payroll_runs where id = p_run for update;
  if not found then raise exception 'payroll run not found'; end if;
  if r.status <> 'draft' then raise exception 'run is %, only draft can be generated', r.status; end if;

  d_start := to_date(r.period_code || '-01', 'YYYY-MM-DD');
  d_end := (d_start + interval '1 month - 1 day')::date;
  dim := extract(day from d_end)::int;

  delete from payroll_lines where run_id = p_run;

  for e in
    select emp.id, emp.employee_no, emp.staff_member_id,
           s.basic, s.hra, s.allowances, s.pf_percent, s.esi_percent, s.pt_amount, s.tds_amount
    from employees emp
    join salary_structures s on s.employee_id = emp.id
    where emp.entity_id = r.entity_id and emp.active
    order by emp.employee_no
  loop
    if e.staff_member_id is null then
      v_present := dim;   -- no legacy attendance source: assume full month
      v_inc := 0;
    else
      select count(distinct (a.clock_in at time zone 'Asia/Kolkata')::date) into v_present
      from staff_attendance a
      where a.staff_id = e.staff_member_id
        and (a.clock_in at time zone 'Asia/Kolkata')::date between d_start and d_end;
      select coalesce(sum(i.amount), 0) into v_inc
      from staff_incentives i
      where i.staff_id = e.staff_member_id
        and (i.created_at at time zone 'Asia/Kolkata')::date between d_start and d_end;
    end if;

    v_factor := least(v_present / dim, 1);            -- prorate, capped at 1
    v_basic := round(e.basic * v_factor, 2);
    v_hra   := round(e.hra * v_factor, 2);
    v_allow := round(e.allowances * v_factor, 2);
    v_gross := v_basic + v_hra + v_allow;
    v_pf  := round(v_basic * e.pf_percent / 100, 2);
    v_esi := case when v_gross <= 21000 then round(v_gross * e.esi_percent / 100, 2) else 0 end;
    v_pt  := e.pt_amount;
    v_tds := e.tds_amount;
    v_net := v_gross + v_inc - v_pf - v_esi - v_pt - v_tds;  -- advance_recovery starts at 0 (edited manually on the draft)

    insert into payroll_lines (run_id, entity_id, employee_id, days_present, days_in_month,
                               basic, hra, allowances, gross, pf, esi, pt, tds, advance_recovery, incentives, net)
    values (p_run, r.entity_id, e.id, v_present, dim,
            v_basic, v_hra, v_allow, v_gross, v_pf, v_esi, v_pt, v_tds, 0, v_inc, v_net);
    n := n + 1;
    t_gross := t_gross + v_gross;
    t_net := t_net + v_net;
  end loop;

  update payroll_runs set total_gross = t_gross, total_net = t_net where id = p_run;
  return n;
end $$;
revoke all on function public.generate_payroll from public, anon, authenticated;

-- ============================================================ post payroll (backbone rule 4: one transaction)
-- Dr 5200 Salaries Expense   (gross + incentives)
-- Cr 2310 Statutory Payable  (pf + esi + pt + tds)
-- Cr 2300 Salaries Payable   (net)  + separate Cr 2300 line for advance recovery (memo'd) —
-- net = gross + incentives - statutory - advance_recovery per line, so Dr equals the sum of Crs.
-- Rounding guard ±0.05 absorbed into the 5200 expense line.
create or replace function public.post_payroll(p_run uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  r payroll_runs%rowtype;
  v_gross numeric(14,2); v_stat numeric(14,2); v_net numeric(14,2); v_adv numeric(14,2);
  v_dr numeric(14,2); v_diff numeric(14,2);
  acc_exp uuid; acc_stat uuid; acc_pay uuid;
  lines jsonb; v_id uuid; d_end date;
begin
  select * into r from payroll_runs where id = p_run for update;
  if not found then raise exception 'payroll run not found'; end if;
  if r.status <> 'approved' then raise exception 'run is %, only approved can be posted', r.status; end if;

  select coalesce(sum(gross + incentives), 0), coalesce(sum(pf + esi + pt + tds), 0),
         coalesce(sum(net), 0), coalesce(sum(advance_recovery), 0)
  into v_gross, v_stat, v_net, v_adv
  from payroll_lines where run_id = p_run;
  if v_gross = 0 then raise exception 'run has no lines (generate first)'; end if;

  select id into acc_exp  from ledger_accounts where entity_id = r.entity_id and account_no = '5200';
  select id into acc_stat from ledger_accounts where entity_id = r.entity_id and account_no = '2310';
  select id into acc_pay  from ledger_accounts where entity_id = r.entity_id and account_no = '2300';
  if acc_exp is null or acc_stat is null or acc_pay is null then
    raise exception 'ledger accounts 5200/2310/2300 not configured for this entity';
  end if;

  v_diff := round((v_net + v_stat + v_adv) - v_gross, 2);
  if abs(v_diff) > 0.05 then
    raise exception 'payroll not balanced: gross+incentives % vs net+statutory+advances % (diff %)', v_gross, v_net + v_stat + v_adv, v_diff;
  end if;
  v_dr := v_gross + v_diff;

  lines := jsonb_build_array(
    jsonb_build_object('account_id', acc_exp, 'debit', v_dr, 'credit', 0, 'memo', 'Payroll ' || r.period_code || ' gross + incentives'));
  if v_stat > 0 then
    lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_stat, 'debit', 0, 'credit', v_stat, 'memo', 'PF/ESI/PT/TDS ' || r.period_code));
  end if;
  lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_pay, 'debit', 0, 'credit', v_net, 'memo', 'Net salaries ' || r.period_code));
  if v_adv > 0 then
    lines := lines || jsonb_build_array(jsonb_build_object('account_id', acc_pay, 'debit', 0, 'credit', v_adv, 'memo', 'Advance recovery ' || r.period_code));
  end if;

  d_end := (to_date(r.period_code || '-01', 'YYYY-MM-DD') + interval '1 month - 1 day')::date;
  v_id := post_voucher(r.entity_id, d_end, 'payroll', r.id, 'Payroll ' || r.period_code, lines, p_actor);

  update payroll_runs set status = 'posted', voucher_id = v_id where id = p_run;
  return v_id;
end $$;
revoke all on function public.post_payroll from public, anon, authenticated;

-- ============================================================ report: payroll register
create or replace function public.payroll_register(p_entity uuid, p_period text)
returns table (employee_no text, employee_name text, days_present numeric, days_in_month int,
               basic numeric, hra numeric, allowances numeric, gross numeric,
               pf numeric, esi numeric, pt numeric, tds numeric,
               advance_recovery numeric, incentives numeric, net numeric, status text)
language sql security definer set search_path = public as $$
  select e.employee_no, e.display_name, l.days_present, l.days_in_month,
         l.basic, l.hra, l.allowances, l.gross, l.pf, l.esi, l.pt, l.tds,
         l.advance_recovery, l.incentives, l.net, r.status
  from payroll_runs r
  join payroll_lines l on l.run_id = r.id
  join employees e on e.id = l.employee_id
  where r.entity_id = p_entity and r.period_code = p_period
  order by e.employee_no
$$;
revoke all on function public.payroll_register from public, anon, authenticated;

-- ============================================================ audit + RLS
do $$ declare t text;
begin
  foreach t in array array['employees','salary_structures','payroll_runs']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

-- Non-sensitive tables get the usual authenticated read policy (writes only via service role).
do $$ declare t text;
begin
  foreach t in array array['departments','positions','employees']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
    -- no insert/update/delete policies: only the service role (API tier) can write
  end loop;
end $$;

-- PRIVACY DEVIATION from the usual module pattern: salary_structures, employment_history,
-- payroll_runs and payroll_lines carry compensation data. RLS is enabled with NO select
-- policy at all — not even authenticated read. They are reachable only through the API tier
-- (service role), which enforces hr.* privileges per entity.
do $$ declare t text;
begin
  foreach t in array array['salary_structures','employment_history','payroll_runs','payroll_lines']
  loop
    execute format('alter table public.%s enable row level security', t);
  end loop;
end $$;

-- ============================================================ privileges → admin role
insert into public.erp_privileges (code, module, description) values
  ('hr.employees.read',   'hr', 'View employees'),
  ('hr.employees.write',  'hr', 'Manage employees, history & salary structures'),
  ('hr.masters.read',     'hr', 'View departments & positions'),
  ('hr.masters.write',    'hr', 'Manage departments & positions'),
  ('hr.payroll.read',     'hr', 'View payroll runs'),
  ('hr.payroll.write',    'hr', 'Create/generate/edit draft payroll runs'),
  ('hr.payroll.approve',  'hr', 'Approve payroll runs'),
  ('hr.payroll.post',     'hr', 'Post payroll runs to GL'),
  ('hr.reports.read',     'hr', 'Run HR & payroll reports')
on conflict (code) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p
where r.name = 'admin' and p.module = 'hr'
on conflict do nothing;
