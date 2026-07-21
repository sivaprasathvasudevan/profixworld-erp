-- Phase 4: Sales & Marketing — customers, quotation → order → invoice with GST posting,
-- customer transactions, sales register. See CLAUDE.md backbone rules.
-- erp_customers is a NEW table: the legacy `customers` table belongs to the live CRM and is untouched.

-- ============================================================ customers
create table if not exists public.erp_customers (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  customer_no text not null,           -- allocated via allocate_number(entity, 'CUST') by the API
  name text not null,
  phone text,
  email text,
  gstin text,
  billing_address text,
  shipping_address text,
  credit_points numeric(14,2) not null default 0,
  credit_limit numeric(14,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, customer_no)
);

-- ============================================================ quotations (header/lines, backbone rule 3)
create table if not exists public.sales_quotations (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  quotation_no text not null,
  quotation_date date not null default current_date,
  customer_id uuid not null references public.erp_customers(id),
  status text not null default 'draft' check (status in ('draft','approved','converted','cancelled')),
  total_amount numeric(14,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, quotation_no)
);

create table if not exists public.sales_quotation_lines (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.sales_quotations(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  item_id uuid not null references public.items(id),
  description text,
  qty numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  tax_rate numeric(5,2) not null default 18,
  line_amount numeric(14,2) not null default 0   -- GST-inclusive: qty*unit_price - discount
);

-- ============================================================ orders
create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  order_no text not null,
  order_date date not null default current_date,
  customer_id uuid not null references public.erp_customers(id),
  status text not null default 'open' check (status in ('open','invoiced','cancelled')),
  warehouse_id uuid references public.warehouses(id),
  quotation_id uuid references public.sales_quotations(id),
  total_amount numeric(14,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, order_no)
);

create table if not exists public.sales_order_lines (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.sales_orders(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  item_id uuid not null references public.items(id),
  description text,
  qty numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  tax_rate numeric(5,2) not null default 18,
  line_amount numeric(14,2) not null default 0
);

-- ============================================================ invoices
create table if not exists public.sales_invoices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  invoice_no text not null,
  invoice_date date not null default current_date,
  customer_id uuid not null references public.erp_customers(id),
  status text not null default 'draft' check (status in ('draft','posted')),
  warehouse_id uuid references public.warehouses(id),
  order_id uuid references public.sales_orders(id),
  voucher_id uuid references public.vouchers(id),
  posted boolean not null default false,
  total_amount numeric(14,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, invoice_no)
);

create table if not exists public.sales_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.sales_invoices(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  item_id uuid not null references public.items(id),
  description text,
  qty numeric(14,3) not null default 0,
  unit_price numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  tax_rate numeric(5,2) not null default 18,
  line_amount numeric(14,2) not null default 0
);

create index if not exists sales_invoices_entity_date_idx on public.sales_invoices (entity_id, invoice_date);
create index if not exists sales_invoices_customer_idx on public.sales_invoices (customer_id);

-- ============================================================ convert quotation → order
create or replace function public.convert_quotation_to_order(p_quotation uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare q sales_quotations%rowtype; v_no text; v_id uuid;
begin
  select * into q from sales_quotations where id = p_quotation for update;
  if not found then raise exception 'quotation not found'; end if;
  if q.status <> 'approved' then raise exception 'quotation is %, only approved can be converted', q.status; end if;
  v_no := allocate_number(q.entity_id, 'SO');
  insert into sales_orders (entity_id, order_no, order_date, customer_id, quotation_id, total_amount, created_by)
  values (q.entity_id, v_no, current_date, q.customer_id, q.id, q.total_amount, p_actor)
  returning id into v_id;
  insert into sales_order_lines (order_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount)
  select v_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount
  from sales_quotation_lines where quotation_id = p_quotation order by line_no;
  update sales_quotations set status = 'converted' where id = p_quotation;
  return v_id;
end $$;
revoke all on function public.convert_quotation_to_order from public, anon, authenticated;

-- ============================================================ post invoice (backbone rule 4: one transaction)
-- Prices are GST-inclusive: per line taxable = round(line_amount / (1+tax_rate/100), 2), tax = the rest.
-- GL: Dr 1200 Accounts Receivable / Cr 4100 Sales Revenue + Cr 2200 CGST + Cr 2210 SGST (tax split 50/50).
create or replace function public.post_sales_invoice(p_invoice uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  inv sales_invoices%rowtype; l record; n int := 0;
  v_taxable numeric(14,2) := 0; v_tax numeric(14,2) := 0; line_taxable numeric(14,2);
  v_cgst numeric(14,2); v_sgst numeric(14,2); v_rev numeric(14,2); v_diff numeric(14,2);
  acc_ar uuid; acc_rev uuid; acc_cgst uuid; acc_sgst uuid;
  v_id uuid; lines jsonb;
begin
  select * into inv from sales_invoices where id = p_invoice for update;
  if not found then raise exception 'invoice not found'; end if;
  if inv.status <> 'draft' or inv.posted then
    raise exception 'invoice is %, only draft can be posted', inv.status;
  end if;
  for l in
    select il.line_no, il.qty, il.line_amount, il.tax_rate, i.item_type
    from sales_invoice_lines il join items i on i.id = il.item_id
    where il.invoice_id = p_invoice order by il.line_no
  loop
    n := n + 1;
    line_taxable := round(l.line_amount / (1 + l.tax_rate / 100), 2);
    v_taxable := v_taxable + line_taxable;
    v_tax := v_tax + (l.line_amount - line_taxable);
    if l.item_type <> 'service' and inv.warehouse_id is null then
      raise exception 'line %: invoice has stock lines but no warehouse', l.line_no;
    end if;
  end loop;
  if n = 0 then raise exception 'invoice has no lines'; end if;
  if round(inv.total_amount, 2) = 0 then raise exception 'invoice total is zero'; end if;

  select id into acc_ar   from ledger_accounts where entity_id = inv.entity_id and account_no = '1200';
  select id into acc_rev  from ledger_accounts where entity_id = inv.entity_id and account_no = '4100';
  select id into acc_cgst from ledger_accounts where entity_id = inv.entity_id and account_no = '2200';
  select id into acc_sgst from ledger_accounts where entity_id = inv.entity_id and account_no = '2210';
  if acc_ar is null or acc_rev is null or acc_cgst is null or acc_sgst is null then
    raise exception 'ledger accounts 1200/4100/2200/2210 not configured for this entity';
  end if;

  v_cgst := round(v_tax / 2, 2);
  v_sgst := v_tax - v_cgst;              -- CGST+SGST always sum to the exact tax
  v_rev := v_taxable;
  -- Rounding guard: per-line taxable rounding can drift from the header total by a paisa or two.
  -- If the gap is within ±0.05, absorb it into the Sales Revenue line so the voucher balances exactly.
  v_diff := round(inv.total_amount - (v_taxable + v_tax), 2);
  if abs(v_diff) > 0.05 then
    raise exception 'invoice total % does not match lines % (diff %)', inv.total_amount, v_taxable + v_tax, v_diff;
  end if;
  v_rev := v_rev + v_diff;

  lines := jsonb_build_array(
    jsonb_build_object('account_id', acc_ar,   'debit', inv.total_amount, 'credit', 0, 'memo', inv.invoice_no),
    jsonb_build_object('account_id', acc_rev,  'debit', 0, 'credit', v_rev,  'memo', inv.invoice_no),
    jsonb_build_object('account_id', acc_cgst, 'debit', 0, 'credit', v_cgst, 'memo', inv.invoice_no),
    jsonb_build_object('account_id', acc_sgst, 'debit', 0, 'credit', v_sgst, 'memo', inv.invoice_no));
  v_id := post_voucher(inv.entity_id, inv.invoice_date, 'sales', inv.id,
                       'Sales invoice ' || inv.invoice_no, lines, p_actor);

  -- Inventory issue at weighted-average cost (services carry no stock)
  for l in
    select il.line_no, il.item_id, il.qty, i.item_type, i.avg_cost
    from sales_invoice_lines il join items i on i.id = il.item_id
    where il.invoice_id = p_invoice order by il.line_no
  loop
    if l.item_type <> 'service' and coalesce(l.qty, 0) <> 0 then
      insert into inventory_transactions (entity_id, item_id, warehouse_id, qty, unit_cost, source_module, source_doc_id, trans_date)
      values (inv.entity_id, l.item_id, inv.warehouse_id, -l.qty, l.avg_cost, 'sales', inv.id, inv.invoice_date);
    end if;
  end loop;

  -- Loyalty: 1 credit point per ₹100 invoiced
  update erp_customers set credit_points = credit_points + floor(inv.total_amount / 100)
  where id = inv.customer_id;

  update sales_invoices set posted = true, status = 'posted', voucher_id = v_id where id = p_invoice;
  -- Simple fulfilment rule for now: posting an invoice marks its order invoiced
  if inv.order_id is not null then
    update sales_orders set status = 'invoiced' where id = inv.order_id and status = 'open';
  end if;
  return v_id;
end $$;
revoke all on function public.post_sales_invoice from public, anon, authenticated;

-- ============================================================ report: sales register
create or replace function public.sales_register(p_entity uuid, p_from date, p_to date)
returns table (invoice_no text, invoice_date date, customer_no text, customer_name text, total numeric, taxable numeric, tax numeric, status text)
language sql security definer set search_path = public as $$
  select i.invoice_no, i.invoice_date, c.customer_no, c.name, i.total_amount,
         coalesce(sum(round(l.line_amount / (1 + l.tax_rate / 100), 2)), 0),
         coalesce(sum(l.line_amount - round(l.line_amount / (1 + l.tax_rate / 100), 2)), 0),
         i.status
  from sales_invoices i
  join erp_customers c on c.id = i.customer_id
  left join sales_invoice_lines l on l.invoice_id = i.id
  where i.entity_id = p_entity and i.posted
    and i.invoice_date between p_from and p_to
  group by i.id, i.invoice_no, i.invoice_date, c.customer_no, c.name, i.total_amount, i.status
  order by i.invoice_date, i.invoice_no
$$;
revoke all on function public.sales_register from public, anon, authenticated;

-- ============================================================ audit + RLS
do $$ declare t text;
begin
  foreach t in array array['erp_customers','sales_quotations','sales_orders','sales_invoices']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

do $$ declare t text;
begin
  foreach t in array array['erp_customers','sales_quotations','sales_quotation_lines','sales_orders','sales_order_lines','sales_invoices','sales_invoice_lines']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
    -- no insert/update/delete policies: only the service role (API tier) can write
  end loop;
end $$;

-- ============================================================ privileges → admin role
insert into public.erp_privileges (code, module, description) values
  ('sales.customers.read',    'sales', 'View customers'),
  ('sales.customers.write',   'sales', 'Manage customers'),
  ('sales.quotations.read',   'sales', 'View quotations'),
  ('sales.quotations.write',  'sales', 'Create/edit draft quotations'),
  ('sales.quotations.approve','sales', 'Approve quotations'),
  ('sales.orders.read',       'sales', 'View sales orders'),
  ('sales.orders.write',      'sales', 'Create/edit sales orders & convert quotations'),
  ('sales.invoices.read',     'sales', 'View sales invoices'),
  ('sales.invoices.write',    'sales', 'Create/edit draft invoices'),
  ('sales.invoices.post',     'sales', 'Post sales invoices'),
  ('sales.reports.read',      'sales', 'Run sales reports')
on conflict (code) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p
where r.name = 'admin' and p.module = 'sales'
on conflict do nothing;
