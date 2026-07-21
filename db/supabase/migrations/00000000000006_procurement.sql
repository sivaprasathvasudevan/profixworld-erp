-- Phase 5: Procurement & Sourcing — vendors, purchase order → goods receipt → purchase invoice
-- with GST input posting and weighted-average costing. Vendor-side mirror of Phase 4 sales.
-- See CLAUDE.md backbone rules. Sequences PO/GRN/PINV/VEND are seeded in migration 2.

-- ============================================================ vendors
create table if not exists public.vendors (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  vendor_no text not null,             -- allocated via allocate_number(entity, 'VEND') by the API
  name text not null,
  phone text,
  email text,
  gstin text,
  address text,
  bank_details text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, vendor_no)
);

-- ============================================================ purchase orders (header/lines, backbone rule 3)
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  order_no text not null,
  order_date date not null default current_date,
  vendor_id uuid not null references public.vendors(id),
  status text not null default 'draft' check (status in ('draft','approved','received','invoiced','cancelled')),
  warehouse_id uuid references public.warehouses(id),
  total_amount numeric(14,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, order_no)
);

create table if not exists public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.purchase_orders(id) on delete cascade,
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

-- ============================================================ goods receipts (GRN)
create table if not exists public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  grn_no text not null,
  grn_date date not null default current_date,
  vendor_id uuid not null references public.vendors(id),
  purchase_order_id uuid not null references public.purchase_orders(id),
  warehouse_id uuid not null references public.warehouses(id),
  status text not null default 'draft' check (status in ('draft','posted')),
  total_amount numeric(14,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, grn_no)
);

create table if not exists public.goods_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  grn_id uuid not null references public.goods_receipts(id) on delete cascade,
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

-- ============================================================ purchase invoices
create table if not exists public.purchase_invoices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  invoice_no text not null,
  invoice_date date not null default current_date,
  vendor_id uuid not null references public.vendors(id),
  status text not null default 'draft' check (status in ('draft','posted')),
  purchase_order_id uuid references public.purchase_orders(id),
  goods_receipt_id uuid references public.goods_receipts(id),
  voucher_id uuid references public.vouchers(id),
  posted boolean not null default false,
  total_amount numeric(14,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, invoice_no)
);

create table if not exists public.purchase_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.purchase_invoices(id) on delete cascade,
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

create index if not exists purchase_invoices_entity_date_idx on public.purchase_invoices (entity_id, invoice_date);
create index if not exists purchase_invoices_vendor_idx on public.purchase_invoices (vendor_id);
create index if not exists goods_receipts_po_idx on public.goods_receipts (purchase_order_id);

-- ============================================================ post goods receipt (backbone rule 4)
-- Receives stock IN at the GRN warehouse. unit_cost = taxable unit cost = unit_price / (1+tax_rate/100)
-- rounded to 4dp (prices are GST-inclusive; the GST part is input credit, not inventory value).
-- items.avg_cost is re-weighted: (old_onhand*old_avg + qty*new_cost) / (old_onhand + qty),
-- guarding division by zero / non-positive stock: if on-hand (before or after) is <= 0 just take the new cost.
create or replace function public.post_goods_receipt(p_grn uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  g goods_receipts%rowtype; l record; n int := 0;
  new_cost numeric(14,4); old_onhand numeric;
begin
  select * into g from goods_receipts where id = p_grn for update;
  if not found then raise exception 'goods receipt not found'; end if;
  if g.status <> 'draft' then raise exception 'goods receipt is %, only draft can be posted', g.status; end if;

  for l in
    select gl.line_no, gl.item_id, gl.qty, gl.unit_price, gl.tax_rate, i.item_type, i.avg_cost
    from goods_receipt_lines gl join items i on i.id = gl.item_id
    where gl.grn_id = p_grn order by gl.line_no
  loop
    n := n + 1;
    if l.item_type <> 'service' and coalesce(l.qty, 0) > 0 then
      new_cost := round(l.unit_price / (1 + l.tax_rate / 100), 4);
      -- on-hand across all warehouses of the entity, before this receipt line
      select coalesce(sum(qty), 0) into old_onhand
      from inventory_transactions where entity_id = g.entity_id and item_id = l.item_id;
      insert into inventory_transactions (entity_id, item_id, warehouse_id, qty, unit_cost, source_module, source_doc_id, trans_date)
      values (g.entity_id, l.item_id, g.warehouse_id, l.qty, new_cost, 'purchase', g.id, g.grn_date);
      if old_onhand <= 0 or old_onhand + l.qty <= 0 then
        update items set avg_cost = new_cost where id = l.item_id;
      else
        update items set avg_cost = round((old_onhand * l.avg_cost + l.qty * new_cost) / (old_onhand + l.qty), 4)
        where id = l.item_id;
      end if;
    end if;
  end loop;
  if n = 0 then raise exception 'goods receipt has no lines'; end if;

  update goods_receipts set status = 'posted' where id = p_grn;
  update purchase_orders set status = 'received'
  where id = g.purchase_order_id and status = 'approved';
  return p_grn;
end $$;
revoke all on function public.post_goods_receipt from public, anon, authenticated;

-- ============================================================ post purchase invoice (backbone rule 4: one transaction)
-- Prices are GST-inclusive: per line taxable = round(line_amount / (1+tax_rate/100), 2), tax = the rest.
-- GL: Dr 1300 Inventory sum(taxable) + Dr 1400 GST Input Credit sum(tax) / Cr 2100 Accounts Payable total.
-- NO inventory transactions here — the goods receipt already put the stock in at taxable cost.
-- 3-way match (kept deliberately simple): if a GRN is linked and any item is invoiced for more qty
-- than was received on that GRN, we raise a NOTICE (not an exception) so posting still succeeds.
create or replace function public.post_purchase_invoice(p_invoice uuid, p_actor uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  inv purchase_invoices%rowtype; l record; n int := 0;
  v_taxable numeric(14,2) := 0; v_tax numeric(14,2) := 0; line_taxable numeric(14,2);
  v_invval numeric(14,2); v_diff numeric(14,2);
  acc_inv uuid; acc_gst uuid; acc_ap uuid;
  v_id uuid; lines jsonb;
begin
  select * into inv from purchase_invoices where id = p_invoice for update;
  if not found then raise exception 'purchase invoice not found'; end if;
  if inv.status <> 'draft' or inv.posted then
    raise exception 'purchase invoice is %, only draft can be posted', inv.status;
  end if;

  for l in
    select il.line_no, il.line_amount, il.tax_rate
    from purchase_invoice_lines il
    where il.invoice_id = p_invoice order by il.line_no
  loop
    n := n + 1;
    line_taxable := round(l.line_amount / (1 + l.tax_rate / 100), 2);
    v_taxable := v_taxable + line_taxable;
    v_tax := v_tax + (l.line_amount - line_taxable);
  end loop;
  if n = 0 then raise exception 'purchase invoice has no lines'; end if;
  if round(inv.total_amount, 2) = 0 then raise exception 'purchase invoice total is zero'; end if;

  -- 3-way match warning: invoice qty per item vs GRN qty per item
  if inv.goods_receipt_id is not null then
    for l in
      select i.item_id, i.qty as inv_qty, coalesce(g.qty, 0) as grn_qty
      from (select item_id, sum(qty) qty from purchase_invoice_lines where invoice_id = p_invoice group by item_id) i
      left join (select item_id, sum(qty) qty from goods_receipt_lines where grn_id = inv.goods_receipt_id group by item_id) g
        on g.item_id = i.item_id
      where i.qty > coalesce(g.qty, 0)
    loop
      raise notice '3-way match: item % invoiced qty % exceeds GRN qty %', l.item_id, l.inv_qty, l.grn_qty;
    end loop;
  end if;

  select id into acc_inv from ledger_accounts where entity_id = inv.entity_id and account_no = '1300';
  select id into acc_gst from ledger_accounts where entity_id = inv.entity_id and account_no = '1400';
  select id into acc_ap  from ledger_accounts where entity_id = inv.entity_id and account_no = '2100';
  if acc_inv is null or acc_gst is null or acc_ap is null then
    raise exception 'ledger accounts 1300/1400/2100 not configured for this entity';
  end if;

  v_invval := v_taxable;
  -- Rounding guard: per-line taxable rounding can drift from the header total by a paisa or two.
  -- If the gap is within ±0.05, absorb it into the Inventory line so the voucher balances exactly.
  v_diff := round(inv.total_amount - (v_taxable + v_tax), 2);
  if abs(v_diff) > 0.05 then
    raise exception 'invoice total % does not match lines % (diff %)', inv.total_amount, v_taxable + v_tax, v_diff;
  end if;
  v_invval := v_invval + v_diff;

  lines := jsonb_build_array(
    jsonb_build_object('account_id', acc_inv, 'debit', v_invval, 'credit', 0, 'memo', inv.invoice_no),
    jsonb_build_object('account_id', acc_gst, 'debit', v_tax,    'credit', 0, 'memo', inv.invoice_no),
    jsonb_build_object('account_id', acc_ap,  'debit', 0, 'credit', inv.total_amount, 'memo', inv.invoice_no));
  v_id := post_voucher(inv.entity_id, inv.invoice_date, 'purchase', inv.id,
                       'Purchase invoice ' || inv.invoice_no, lines, p_actor);

  update purchase_invoices set posted = true, status = 'posted', voucher_id = v_id where id = p_invoice;
  if inv.purchase_order_id is not null then
    update purchase_orders set status = 'invoiced'
    where id = inv.purchase_order_id and status in ('approved', 'received');
  end if;
  return v_id;
end $$;
revoke all on function public.post_purchase_invoice from public, anon, authenticated;

-- ============================================================ report: purchase register
create or replace function public.purchase_register(p_entity uuid, p_from date, p_to date)
returns table (invoice_no text, invoice_date date, vendor_no text, vendor_name text, total numeric, taxable numeric, tax numeric, status text)
language sql security definer set search_path = public as $$
  select i.invoice_no, i.invoice_date, v.vendor_no, v.name, i.total_amount,
         coalesce(sum(round(l.line_amount / (1 + l.tax_rate / 100), 2)), 0),
         coalesce(sum(l.line_amount - round(l.line_amount / (1 + l.tax_rate / 100), 2)), 0),
         i.status
  from purchase_invoices i
  join vendors v on v.id = i.vendor_id
  left join purchase_invoice_lines l on l.invoice_id = i.id
  where i.entity_id = p_entity and i.posted
    and i.invoice_date between p_from and p_to
  group by i.id, i.invoice_no, i.invoice_date, v.vendor_no, v.name, i.total_amount, i.status
  order by i.invoice_date, i.invoice_no
$$;
revoke all on function public.purchase_register from public, anon, authenticated;

-- ============================================================ audit + RLS
do $$ declare t text;
begin
  foreach t in array array['vendors','purchase_orders','goods_receipts','purchase_invoices']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

do $$ declare t text;
begin
  foreach t in array array['vendors','purchase_orders','purchase_order_lines','goods_receipts','goods_receipt_lines','purchase_invoices','purchase_invoice_lines']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
    -- no insert/update/delete policies: only the service role (API tier) can write
  end loop;
end $$;

-- ============================================================ privileges → admin role
insert into public.erp_privileges (code, module, description) values
  ('purchase.vendors.read',   'purchase', 'View vendors'),
  ('purchase.vendors.write',  'purchase', 'Manage vendors'),
  ('purchase.orders.read',    'purchase', 'View purchase orders'),
  ('purchase.orders.write',   'purchase', 'Create/edit draft purchase orders'),
  ('purchase.orders.approve', 'purchase', 'Approve purchase orders'),
  ('purchase.grn.read',       'purchase', 'View goods receipts'),
  ('purchase.grn.write',      'purchase', 'Create/edit draft goods receipts'),
  ('purchase.grn.post',       'purchase', 'Post goods receipts'),
  ('purchase.invoices.read',  'purchase', 'View purchase invoices'),
  ('purchase.invoices.write', 'purchase', 'Create/edit draft purchase invoices'),
  ('purchase.invoices.post',  'purchase', 'Post purchase invoices'),
  ('purchase.reports.read',   'purchase', 'Run purchase reports')
on conflict (code) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p
where r.name = 'admin' and p.module = 'purchase'
on conflict do nothing;
