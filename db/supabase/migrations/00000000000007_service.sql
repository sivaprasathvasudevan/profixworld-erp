-- Phase 7: Service Management — service orders with workflow engine, delivery posting
-- (service + parts revenue, GST, inventory issue), public status token.
-- The legacy CRM table repair_tickets stays untouched and live; its data migrates in a later task.
-- See CLAUDE.md backbone rules.

-- ============================================================ service orders (header/lines, backbone rule 3)
create table if not exists public.service_orders (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  service_order_no text not null,      -- allocated via allocate_number(entity, 'SVC') by the API
  customer_id uuid not null references public.erp_customers(id),
  warehouse_id uuid references public.warehouses(id),   -- the store doing the work
  device_brand text,
  device_model text,
  imei text,
  complaint text,
  status text not null default 'received' check (status in ('received','wip','completed','delivered','closed','cancelled')),
  public_token uuid not null default gen_random_uuid() unique,   -- share link: status only, no prices
  total_amount numeric(14,2) not null default 0,
  voucher_id uuid references public.vouchers(id),
  posted boolean not null default false,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (entity_id, service_order_no)
);

create table if not exists public.service_order_lines (
  id uuid primary key default gen_random_uuid(),
  service_order_id uuid not null references public.service_orders(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  line_no int not null,
  item_id uuid references public.items(id),   -- NULLABLE: manual lines allowed (count as service)
  description text,
  qty numeric(14,3) not null default 1,
  unit_price numeric(14,2) not null default 0,
  tax_rate numeric(5,2) not null default 18,
  line_amount numeric(14,2) not null default 0   -- GST-inclusive: qty*unit_price
);

create index if not exists service_orders_entity_created_idx on public.service_orders (entity_id, created_at);
create index if not exists service_orders_customer_idx on public.service_orders (customer_id);
create index if not exists service_orders_entity_status_idx on public.service_orders (entity_id, status);

-- ============================================================ workflow log (who, when, note)
create table if not exists public.service_workflow_log (
  id bigint generated always as identity primary key,
  service_order_id uuid not null references public.service_orders(id) on delete cascade,
  from_status text,
  to_status text not null,
  actor uuid,
  note text,
  at timestamptz not null default now()
);
create index if not exists service_workflow_log_order_idx on public.service_workflow_log (service_order_id);

-- ============================================================ workflow transition + delivery posting (backbone rule 4)
-- Forward-only: received → wip → completed → delivered → closed; cancelled allowed from received/wip.
-- On 'delivered' the order posts in the same transaction (skip posting when total is 0 — free service):
--   Dr 1100 Cash in Hand (total)
--   Cr 4200 Service Revenue (taxable of service/manual lines, absorbs the ±0.05 rounding guard)
--   Cr 4100 Sales Revenue (taxable of product/part lines)
--   Cr 2200 GST Output CGST (tax/2) + Cr 2210 GST Output SGST (remainder)
-- plus inventory issue (negative qty at avg cost) for product/part lines at the order warehouse.
create or replace function public.service_transition(p_order uuid, p_to text, p_actor uuid, p_note text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  o service_orders%rowtype;
  allowed text[];
  l record; n int := 0; has_stock boolean := false;
  line_taxable numeric(14,2);
  v_srv numeric(14,2) := 0; v_sales numeric(14,2) := 0; v_tax numeric(14,2) := 0;
  v_cgst numeric(14,2); v_sgst numeric(14,2); v_diff numeric(14,2);
  acc_cash uuid; acc_srv uuid; acc_sales uuid; acc_cgst uuid; acc_sgst uuid;
  lines jsonb; v_voucher uuid;
begin
  select * into o from service_orders where id = p_order for update;
  if not found then raise exception 'service order not found'; end if;

  allowed := case o.status
    when 'received'  then array['wip','cancelled']
    when 'wip'       then array['completed','cancelled']
    when 'completed' then array['delivered']
    when 'delivered' then array['closed']
    else array[]::text[] end;                -- closed/cancelled are terminal
  if not (p_to = any(allowed)) then
    raise exception 'illegal transition % -> % (allowed: %)', o.status, p_to,
      coalesce(nullif(array_to_string(allowed, ', '), ''), 'none');
  end if;

  if p_to = 'delivered' and not o.posted and round(o.total_amount, 2) <> 0 then
    for l in
      select sl.line_no, sl.item_id, sl.qty, sl.line_amount, sl.tax_rate, i.item_type
      from service_order_lines sl left join items i on i.id = sl.item_id
      where sl.service_order_id = p_order order by sl.line_no
    loop
      n := n + 1;
      line_taxable := round(l.line_amount / (1 + l.tax_rate / 100), 2);
      v_tax := v_tax + (l.line_amount - line_taxable);
      if l.item_type in ('product','part') then
        v_sales := v_sales + line_taxable;
        has_stock := true;
      else
        v_srv := v_srv + line_taxable;       -- service items and manual (null item) lines
      end if;
    end loop;
    if n = 0 then raise exception 'service order has no lines'; end if;
    if has_stock and o.warehouse_id is null then
      raise exception 'service order has stock lines but no warehouse';
    end if;

    select id into acc_cash  from ledger_accounts where entity_id = o.entity_id and account_no = '1100';
    select id into acc_srv   from ledger_accounts where entity_id = o.entity_id and account_no = '4200';
    select id into acc_sales from ledger_accounts where entity_id = o.entity_id and account_no = '4100';
    select id into acc_cgst  from ledger_accounts where entity_id = o.entity_id and account_no = '2200';
    select id into acc_sgst  from ledger_accounts where entity_id = o.entity_id and account_no = '2210';
    if acc_cash is null or acc_srv is null or acc_sales is null or acc_cgst is null or acc_sgst is null then
      raise exception 'ledger accounts 1100/4200/4100/2200/2210 not configured for this entity';
    end if;

    v_cgst := round(v_tax / 2, 2);
    v_sgst := v_tax - v_cgst;                -- CGST+SGST always sum to the exact tax
    -- Rounding guard: per-line taxable rounding can drift from the header total by a paisa or two.
    -- If the gap is within ±0.05, absorb it into the Service Revenue line so the voucher balances exactly.
    v_diff := round(o.total_amount - (v_srv + v_sales + v_tax), 2);
    if abs(v_diff) > 0.05 then
      raise exception 'order total % does not match lines % (diff %)', o.total_amount, v_srv + v_sales + v_tax, v_diff;
    end if;
    v_srv := v_srv + v_diff;

    lines := jsonb_build_array(
      jsonb_build_object('account_id', acc_cash, 'debit', o.total_amount, 'credit', 0, 'memo', o.service_order_no));
    if v_srv <> 0 then
      lines := lines || jsonb_build_object('account_id', acc_srv, 'debit', 0, 'credit', v_srv, 'memo', o.service_order_no);
    end if;
    if v_sales <> 0 then
      lines := lines || jsonb_build_object('account_id', acc_sales, 'debit', 0, 'credit', v_sales, 'memo', o.service_order_no);
    end if;
    if v_cgst <> 0 then
      lines := lines || jsonb_build_object('account_id', acc_cgst, 'debit', 0, 'credit', v_cgst, 'memo', o.service_order_no);
    end if;
    if v_sgst <> 0 then
      lines := lines || jsonb_build_object('account_id', acc_sgst, 'debit', 0, 'credit', v_sgst, 'memo', o.service_order_no);
    end if;

    v_voucher := post_voucher(o.entity_id, current_date, 'service', o.id,
                              'Service order ' || o.service_order_no, lines, p_actor);

    -- Inventory issue at weighted-average cost (parts/products consumed by the repair)
    for l in
      select sl.line_no, sl.item_id, sl.qty, i.item_type, i.avg_cost
      from service_order_lines sl join items i on i.id = sl.item_id
      where sl.service_order_id = p_order order by sl.line_no
    loop
      if l.item_type in ('product','part') and coalesce(l.qty, 0) <> 0 then
        insert into inventory_transactions (entity_id, item_id, warehouse_id, qty, unit_cost, source_module, source_doc_id, trans_date)
        values (o.entity_id, l.item_id, o.warehouse_id, -l.qty, l.avg_cost, 'service', o.id, current_date);
      end if;
    end loop;

    update service_orders set posted = true, voucher_id = v_voucher where id = p_order;
  end if;

  update service_orders set status = p_to where id = p_order;
  insert into service_workflow_log (service_order_id, from_status, to_status, actor, note)
  values (p_order, o.status, p_to, p_actor, p_note);
  return p_order;
end $$;
revoke all on function public.service_transition from public, anon, authenticated;

-- ============================================================ public status (shared via wa.me link)
-- PUBLIC ON PURPOSE: token-holders see status only — no prices, no customer data.
create or replace function public.service_public_status(p_token uuid)
returns table (service_order_no text, status text, device_brand text, device_model text, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select o.service_order_no, o.status, o.device_brand, o.device_model,
         coalesce((select max(w.at) from service_workflow_log w where w.service_order_id = o.id), o.created_at)
  from service_orders o
  where o.public_token = p_token
$$;
revoke all on function public.service_public_status(uuid) from public;
grant execute on function public.service_public_status(uuid) to anon, authenticated;

-- ============================================================ audit + RLS
do $$ declare t text;
begin
  foreach t in array array['service_orders']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

do $$ declare t text;
begin
  foreach t in array array['service_orders','service_order_lines','service_workflow_log']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
    -- no insert/update/delete policies: only the service role (API tier) can write
  end loop;
end $$;

-- ============================================================ privileges → admin role
insert into public.erp_privileges (code, module, description) values
  ('service.orders.read',       'service', 'View service orders'),
  ('service.orders.write',      'service', 'Create/edit service orders'),
  ('service.orders.transition', 'service', 'Move service orders through the workflow'),
  ('service.reports.read',      'service', 'Run service reports')
on conflict (code) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p
where r.name = 'admin' and p.module = 'service'
on conflict do nothing;
