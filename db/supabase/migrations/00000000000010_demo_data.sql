-- Demo data seed — realistic Indian demo dataset for entity PROFIX.
-- Masters (customers, vendors, items+dimensions, HR, asset), opening balances, and full
-- document flows driven through the REAL engine functions (allocate_number, post_gl_journal,
-- post_goods_receipt, post_purchase_invoice, convert_quotation_to_order, post_sales_invoice,
-- service_transition, post_movement_journal, post_transfer_journal, generate_payroll,
-- generate_depreciation, post_depreciation) so vouchers, inventory transactions and every
-- report screen have data. Idempotent: guarded on the existence of customer 'Rajesh Kumar'.
-- Never inserts into vouchers / voucher_lines / inventory_transactions directly (backbone rule 4).

do $seed$
declare
  v_entity uuid;
  v_wh uuid;
  v_wh2 uuid;
  v_actor uuid;

  -- customers
  v_cust_rajesh uuid; v_cust_priya uuid; v_cust_farook uuid; v_cust_anitha uuid; v_cust_suresh uuid;
  -- vendors
  v_vend_chennai uuid; v_vend_cbe uuid; v_vend_tech uuid;
  -- items
  v_item_a54 uuid; v_item_redmi uuid; v_item_charger uuid; v_item_glass uuid;
  v_item_amoled uuid; v_item_battery uuid; v_item_screensvc uuid; v_item_swflash uuid;
  -- dimensions
  v_dt_colour uuid; v_dt_size uuid;
  v_dv_black uuid; v_dv_blue uuid; v_dv_64 uuid;
  -- HR
  v_dept_sales uuid; v_dept_svc uuid; v_pos_tech uuid; v_pos_sexec uuid;
  v_emp_karthik uuid; v_emp_divya uuid;
  -- asset
  v_asset uuid;
  -- GL accounts (opening balance journal)
  v_acc_bank uuid; v_acc_capital uuid;
  -- documents
  v_gj uuid;
  v_po uuid; v_grn uuid; v_pinv uuid;
  v_sq uuid; v_so1 uuid; v_sinv1 uuid; v_so2 uuid; v_sinv2 uuid;
  v_svc1 uuid; v_svc2 uuid;
  v_mvj uuid; v_trj uuid;
  v_payrun uuid; v_deprun uuid;
  v_n int;
begin
  -- ============================================================ guard (idempotency)
  select id into v_entity from legal_entities where code = 'PROFIX';
  if v_entity is null then
    raise notice 'demo seed: entity PROFIX not found, skipping';
    return;
  end if;
  if exists (select 1 from erp_customers where entity_id = v_entity and name = 'Rajesh Kumar') then
    raise notice 'demo seed: already applied (customer Rajesh Kumar exists), skipping';
    return;
  end if;

  -- ============================================================ context
  -- actor: owner account if it exists; every engine function accepts a null actor
  select id into v_actor from auth.users where email = 'sivavasusp@gmail.com' limit 1;

  -- first warehouse of the entity (create a main store if the entity has none yet)
  select id into v_wh from warehouses
   where entity_id = v_entity and active
   order by created_at, warehouse_no limit 1;
  if v_wh is null then
    insert into warehouses (entity_id, warehouse_no, name, is_store)
    values (v_entity, 'WH-MAIN', 'Main Store', true)
    returning id into v_wh;
  end if;
  select id into v_wh2 from warehouses
   where entity_id = v_entity and active and id <> v_wh
   order by created_at, warehouse_no limit 1;   -- null when the entity has a single warehouse

  -- ============================================================ masters: customers
  insert into erp_customers (entity_id, customer_no, name, phone, email, gstin, billing_address, shipping_address, credit_limit)
  values (v_entity, allocate_number(v_entity, 'CUST'), 'Rajesh Kumar', '9840011223', 'rajesh.kumar@example.in',
          '33AAACR1234F1Z5', '12, DB Road, RS Puram, Coimbatore 641002', '12, DB Road, RS Puram, Coimbatore 641002', 50000)
  returning id into v_cust_rajesh;

  insert into erp_customers (entity_id, customer_no, name, phone, email, billing_address, shipping_address, credit_limit)
  values (v_entity, allocate_number(v_entity, 'CUST'), 'Priya Sharma', '9894022334', 'priya.sharma@example.in',
          '45, Avinashi Road, Peelamedu, Coimbatore 641004', '45, Avinashi Road, Peelamedu, Coimbatore 641004', 50000)
  returning id into v_cust_priya;

  insert into erp_customers (entity_id, customer_no, name, phone, email, billing_address, shipping_address, credit_limit)
  values (v_entity, allocate_number(v_entity, 'CUST'), 'Mohammed Farook', '9976033445', 'md.farook@example.in',
          '8, Oppanakara Street, Town Hall, Coimbatore 641001', '8, Oppanakara Street, Town Hall, Coimbatore 641001', 50000)
  returning id into v_cust_farook;

  insert into erp_customers (entity_id, customer_no, name, phone, email, billing_address, shipping_address, credit_limit)
  values (v_entity, allocate_number(v_entity, 'CUST'), 'Anitha Krishnan', '9443044556', 'anitha.k@example.in',
          '23, Trichy Road, Ramanathapuram, Coimbatore 641045', '23, Trichy Road, Ramanathapuram, Coimbatore 641045', 50000)
  returning id into v_cust_anitha;

  insert into erp_customers (entity_id, customer_no, name, phone, email, billing_address, shipping_address, credit_limit)
  values (v_entity, allocate_number(v_entity, 'CUST'), 'Suresh Babu', '9500055667', 'suresh.babu@example.in',
          '67, Mettupalayam Road, Saibaba Colony, Coimbatore 641011', '67, Mettupalayam Road, Saibaba Colony, Coimbatore 641011', 50000)
  returning id into v_cust_suresh;

  -- ============================================================ masters: vendors
  insert into vendors (entity_id, vendor_no, name, phone, email, gstin, address)
  values (v_entity, allocate_number(v_entity, 'VEND'), 'Chennai Mobile Distributors', '9884100200', 'sales@chennaimobiledist.in',
          '33AABCC2345G1Z6', '114, Ritchie Street, Mount Road, Chennai 600002')
  returning id into v_vend_chennai;

  insert into vendors (entity_id, vendor_no, name, phone, email, address)
  values (v_entity, allocate_number(v_entity, 'VEND'), 'Coimbatore Spares Hub', '9842200300', 'orders@cbespareshub.in',
          '31, Raja Street, Town Hall, Coimbatore 641001')
  returning id into v_vend_cbe;

  insert into vendors (entity_id, vendor_no, name, phone, email, address)
  values (v_entity, allocate_number(v_entity, 'VEND'), 'TechParts India', '9930300400', 'support@techpartsindia.in',
          '5th Floor, Lamington Road, Mumbai 400007')
  returning id into v_vend_tech;

  -- ============================================================ masters: items (GST-inclusive sales prices, rate 18)
  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'Samsung Galaxy A54', 'product', 'Mobiles', 'pcs', 18, 38999)
  returning id into v_item_a54;

  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'Redmi Note 13', 'product', 'Mobiles', 'pcs', 18, 16999)
  returning id into v_item_redmi;

  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'USB-C Fast Charger 25W', 'product', 'Accessories', 'pcs', 18, 999)
  returning id into v_item_charger;

  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'Tempered Glass Universal', 'product', 'Accessories', 'pcs', 18, 299)
  returning id into v_item_glass;

  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'AMOLED Display A54', 'part', 'Spare Parts', 'pcs', 18, 8999)
  returning id into v_item_amoled;

  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'Battery 5000mAh', 'part', 'Spare Parts', 'pcs', 18, 1499)
  returning id into v_item_battery;

  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'Screen Replacement Service', 'service', 'Service', 'job', 18, 1500)
  returning id into v_item_screensvc;

  insert into items (entity_id, item_no, name, item_type, category, uom, gst_rate, sales_price)
  values (v_entity, allocate_number(v_entity, 'ITEM'), 'Software Flash & Reset', 'service', 'Service', 'job', 18, 500)
  returning id into v_item_swflash;

  -- dimensions: Colour Black/Blue + Size 6.4 inch, linked to the two phones
  select id into v_dt_colour from dimension_types where code = 'COLOUR';
  select id into v_dt_size   from dimension_types where code = 'SIZE';
  if v_dt_colour is not null and v_dt_size is not null then
    insert into dimension_values (type_id, value) values (v_dt_colour, 'Black')
    on conflict (type_id, value) do nothing;
    insert into dimension_values (type_id, value) values (v_dt_colour, 'Blue')
    on conflict (type_id, value) do nothing;
    insert into dimension_values (type_id, value) values (v_dt_size, '6.4 inch')
    on conflict (type_id, value) do nothing;
    select id into v_dv_black from dimension_values where type_id = v_dt_colour and value = 'Black';
    select id into v_dv_blue  from dimension_values where type_id = v_dt_colour and value = 'Blue';
    select id into v_dv_64    from dimension_values where type_id = v_dt_size   and value = '6.4 inch';
    insert into item_dimensions (item_id, dimension_value_id) values
      (v_item_a54, v_dv_black), (v_item_a54, v_dv_64), (v_item_redmi, v_dv_blue)
    on conflict do nothing;
  end if;

  -- ============================================================ masters: HR
  insert into departments (entity_id, code, name)
  values (v_entity, 'SALES', 'Sales') returning id into v_dept_sales;
  insert into departments (entity_id, code, name)
  values (v_entity, 'SVC', 'Service') returning id into v_dept_svc;

  insert into positions (entity_id, code, title, department_id)
  values (v_entity, 'TECH', 'Technician', v_dept_svc) returning id into v_pos_tech;
  insert into positions (entity_id, code, title, department_id)
  values (v_entity, 'SEXEC', 'Sales Executive', v_dept_sales) returning id into v_pos_sexec;

  insert into employees (entity_id, employee_no, staff_member_id, display_name, phone, join_date, department_id, position_id)
  values (v_entity, allocate_number(v_entity, 'EMP'), null, 'Karthik R', '9789066778', date '2025-06-01', v_dept_svc, v_pos_tech)
  returning id into v_emp_karthik;

  insert into employees (entity_id, employee_no, staff_member_id, display_name, phone, join_date, department_id, position_id)
  values (v_entity, allocate_number(v_entity, 'EMP'), null, 'Divya M', '9865077889', date '2025-09-15', v_dept_sales, v_pos_sexec)
  returning id into v_emp_divya;

  insert into employment_history (employee_id, entity_id, position_id, department_id, from_date, to_date, monthly_salary, note)
  values (v_emp_karthik, v_entity, v_pos_tech, v_dept_svc, date '2025-06-01', null, 22000, 'Joined as Technician'),
         (v_emp_divya,   v_entity, v_pos_sexec, v_dept_sales, date '2025-09-15', null, 17500, 'Joined as Sales Executive');

  insert into salary_structures (entity_id, employee_id, basic, hra, allowances)
  values (v_entity, v_emp_karthik, 15000, 5000, 2000),
         (v_entity, v_emp_divya,   12000, 4000, 1500);

  -- ============================================================ masters: asset
  insert into assets (entity_id, asset_no, name, category, acquisition_date, cost, method, useful_life_months, salvage_value)
  values (v_entity, allocate_number(v_entity, 'AST'), 'Billing POS Terminal', 'equipment',
          date '2026-04-10', 60000, 'straight_line', 36, 6000)
  returning id into v_asset;

  -- ============================================================ opening balances (GL journal → post_gl_journal)
  select id into v_acc_bank    from ledger_accounts where entity_id = v_entity and account_no = '1110';
  select id into v_acc_capital from ledger_accounts where entity_id = v_entity and account_no = '3100';
  if v_acc_bank is null or v_acc_capital is null then
    raise exception 'demo seed: ledger accounts 1110/3100 not configured for PROFIX';
  end if;

  insert into gl_journals (entity_id, journal_no, journal_date, description, total_debit, total_credit, created_by)
  values (v_entity, allocate_number(v_entity, 'GLJ'), date '2026-07-01', 'Opening balances FY 2026-27', 500000, 500000, v_actor)
  returning id into v_gj;

  insert into gl_journal_lines (journal_id, entity_id, line_no, account_id, debit, credit, memo) values
    (v_gj, v_entity, 1, v_acc_bank,    500000, 0, 'Opening bank balance'),
    (v_gj, v_entity, 2, v_acc_capital, 0, 500000, 'Owner capital introduced');

  perform post_gl_journal(v_gj, v_actor);

  -- ============================================================ purchase flow: PO → GRN → purchase invoice
  -- GST-inclusive unit prices chosen to divide cleanly by 1.18 (taxable costs 28000/12000/6000/1000/600/100).
  insert into purchase_orders (entity_id, order_no, order_date, vendor_id, warehouse_id, total_amount, created_by)
  values (v_entity, allocate_number(v_entity, 'PO'), date '2026-07-05', v_vend_chennai, v_wh, 610060, v_actor)
  returning id into v_po;

  insert into purchase_order_lines (order_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount) values
    (v_po, v_entity, 1, v_item_a54,     'Samsung Galaxy A54',       10, 33040, 0, 18, 330400),
    (v_po, v_entity, 2, v_item_redmi,   'Redmi Note 13',            15, 14160, 0, 18, 212400),
    (v_po, v_entity, 3, v_item_amoled,  'AMOLED Display A54',        5,  7080, 0, 18,  35400),
    (v_po, v_entity, 4, v_item_battery, 'Battery 5000mAh',          10,  1180, 0, 18,  11800),
    (v_po, v_entity, 5, v_item_charger, 'USB-C Fast Charger 25W',   20,   708, 0, 18,  14160),
    (v_po, v_entity, 6, v_item_glass,   'Tempered Glass Universal', 50,   118, 0, 18,   5900);

  -- API flow: created as draft, then approved
  update purchase_orders set status = 'approved' where id = v_po;

  -- GRN: copy PO lines, receive into the main warehouse, then post (sets avg_cost + stock in)
  insert into goods_receipts (entity_id, grn_no, grn_date, vendor_id, purchase_order_id, warehouse_id, total_amount, created_by)
  values (v_entity, allocate_number(v_entity, 'GRN'), date '2026-07-06', v_vend_chennai, v_po, v_wh, 610060, v_actor)
  returning id into v_grn;

  insert into goods_receipt_lines (grn_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount)
  select v_grn, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount
  from purchase_order_lines where order_id = v_po order by line_no;

  perform post_goods_receipt(v_grn, v_actor);

  -- purchase invoice: copy lines, then post (Dr Inventory + GST input / Cr AP)
  insert into purchase_invoices (entity_id, invoice_no, invoice_date, vendor_id, purchase_order_id, goods_receipt_id, total_amount, created_by)
  values (v_entity, allocate_number(v_entity, 'PINV'), date '2026-07-08', v_vend_chennai, v_po, v_grn, 610060, v_actor)
  returning id into v_pinv;

  insert into purchase_invoice_lines (invoice_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount)
  select v_pinv, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount
  from purchase_order_lines where order_id = v_po order by line_no;

  perform post_purchase_invoice(v_pinv, v_actor);

  -- ============================================================ sales flow 1: quotation → order → invoice
  insert into sales_quotations (entity_id, quotation_no, quotation_date, customer_id, total_amount, created_by)
  values (v_entity, allocate_number(v_entity, 'SQ'), date '2026-07-10', v_cust_rajesh, 39298, v_actor)
  returning id into v_sq;

  insert into sales_quotation_lines (quotation_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount) values
    (v_sq, v_entity, 1, v_item_a54,   'Samsung Galaxy A54',       1, 38999, 0, 18, 38999),
    (v_sq, v_entity, 2, v_item_glass, 'Tempered Glass Universal', 1,   299, 0, 18,   299);

  -- API flow: created as draft, then approved, then converted
  update sales_quotations set status = 'approved' where id = v_sq;
  v_so1 := convert_quotation_to_order(v_sq, v_actor);
  -- the converter dates the order today; align the demo timeline and set the fulfilment warehouse
  update sales_orders set order_date = date '2026-07-12', warehouse_id = v_wh where id = v_so1;

  insert into sales_invoices (entity_id, invoice_no, invoice_date, customer_id, warehouse_id, order_id, total_amount, created_by)
  values (v_entity, allocate_number(v_entity, 'SINV'), date '2026-07-12', v_cust_rajesh, v_wh, v_so1, 39298, v_actor)
  returning id into v_sinv1;

  insert into sales_invoice_lines (invoice_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount)
  select v_sinv1, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount
  from sales_order_lines where order_id = v_so1 order by line_no;

  perform post_sales_invoice(v_sinv1, v_actor);

  -- ============================================================ sales flow 2: direct order → invoice
  insert into sales_orders (entity_id, order_no, order_date, customer_id, warehouse_id, total_amount, created_by)
  values (v_entity, allocate_number(v_entity, 'SO'), date '2026-07-14', v_cust_priya, v_wh, 17998, v_actor)
  returning id into v_so2;

  insert into sales_order_lines (order_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount) values
    (v_so2, v_entity, 1, v_item_redmi,   'Redmi Note 13',          1, 16999, 0, 18, 16999),
    (v_so2, v_entity, 2, v_item_charger, 'USB-C Fast Charger 25W', 1,   999, 0, 18,   999);

  insert into sales_invoices (entity_id, invoice_no, invoice_date, customer_id, warehouse_id, order_id, total_amount, created_by)
  values (v_entity, allocate_number(v_entity, 'SINV'), date '2026-07-15', v_cust_priya, v_wh, v_so2, 17998, v_actor)
  returning id into v_sinv2;

  insert into sales_invoice_lines (invoice_id, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount)
  select v_sinv2, entity_id, line_no, item_id, description, qty, unit_price, discount, tax_rate, line_amount
  from sales_order_lines where order_id = v_so2 order by line_no;

  perform post_sales_invoice(v_sinv2, v_actor);

  -- ============================================================ service flow
  -- order 1: screen replacement, driven through the full workflow (delivered posts cash + revenue + parts issue)
  insert into service_orders (entity_id, service_order_no, customer_id, warehouse_id, device_brand, device_model, imei, complaint, created_by)
  values (v_entity, allocate_number(v_entity, 'SVC'), v_cust_farook, v_wh, 'Samsung', 'Galaxy M31',
          '356789104321567', 'Broken display, battery drains fast', v_actor)
  returning id into v_svc1;

  insert into service_order_lines (service_order_id, entity_id, line_no, item_id, description, qty, unit_price, tax_rate, line_amount) values
    (v_svc1, v_entity, 1, v_item_amoled,    'AMOLED Display A54',         1, 8999, 18, 8999),
    (v_svc1, v_entity, 2, v_item_screensvc, 'Screen Replacement Service', 1, 1500, 18, 1500);

  update service_orders
     set total_amount = (select sum(line_amount) from service_order_lines where service_order_id = v_svc1)
   where id = v_svc1;

  perform service_transition(v_svc1, 'wip', v_actor, 'Assigned to Karthik R');
  perform service_transition(v_svc1, 'completed', v_actor, 'Display replaced and tested');
  perform service_transition(v_svc1, 'delivered', v_actor, 'Handed over, paid in cash');

  -- order 2: software issue, still on the bench (wip)
  insert into service_orders (entity_id, service_order_no, customer_id, warehouse_id, device_brand, device_model, complaint, created_by)
  values (v_entity, allocate_number(v_entity, 'SVC'), v_cust_anitha, v_wh, 'Redmi', 'Note 13', 'Software issue', v_actor)
  returning id into v_svc2;

  insert into service_order_lines (service_order_id, entity_id, line_no, item_id, description, qty, unit_price, tax_rate, line_amount) values
    (v_svc2, v_entity, 1, v_item_swflash, 'Software Flash & Reset', 1, 500, 18, 500);

  update service_orders
     set total_amount = (select sum(line_amount) from service_order_lines where service_order_id = v_svc2)
   where id = v_svc2;

  perform service_transition(v_svc2, 'wip', v_actor, 'Flashing stock ROM');

  -- ============================================================ inventory: movement journal (damage write-off)
  insert into movement_journals (entity_id, journal_no, journal_date, description, total_qty, created_by)
  values (v_entity, allocate_number(v_entity, 'MVJ'), date '2026-07-16', 'Damaged in handling', -1, v_actor)
  returning id into v_mvj;

  insert into movement_journal_lines (journal_id, entity_id, line_no, item_id, warehouse_id, qty, reason)
  values (v_mvj, v_entity, 1, v_item_glass, v_wh, -1, 'Damaged in handling');

  perform post_movement_journal(v_mvj, v_actor);

  -- transfer journal only when the entity actually has a second warehouse
  if v_wh2 is not null then
    insert into transfer_journals (entity_id, journal_no, journal_date, description, from_warehouse_id, to_warehouse_id, total_qty, created_by)
    values (v_entity, allocate_number(v_entity, 'TRJ'), date '2026-07-17', 'Stock rebalance to second store', v_wh, v_wh2, 2, v_actor)
    returning id into v_trj;

    insert into transfer_journal_lines (journal_id, entity_id, line_no, item_id, qty)
    values (v_trj, v_entity, 1, v_item_charger, 2);

    perform post_transfer_journal(v_trj, v_actor);
  end if;

  -- ============================================================ payroll: July 2026 run, generated but left DRAFT
  insert into payroll_runs (entity_id, period_code, created_by)
  values (v_entity, '2026-07', v_actor)
  returning id into v_payrun;

  v_n := generate_payroll(v_payrun, v_actor);
  raise notice 'demo seed: payroll 2026-07 generated for % employees (left draft)', v_n;

  -- ============================================================ depreciation: July 2026 run, generated and posted
  insert into depreciation_runs (entity_id, period_code, created_by)
  values (v_entity, '2026-07', v_actor)
  returning id into v_deprun;

  v_n := generate_depreciation(v_deprun, v_actor);
  perform post_depreciation(v_deprun, v_actor);

  -- ============================================================ summary
  raise notice 'demo seed complete for PROFIX: 5 customers, 3 vendors, 8 items (+dimensions), 2 employees (+salary structures), 1 asset';
  raise notice 'demo seed posted: opening GLJ 500000, PO/GRN/PINV 610060, 2 sales invoices (39298 + 17998), 1 delivered service order (10499, 1 wip), movement journal -1 glass%, payroll 2026-07 draft, depreciation 2026-07 posted (1500)',
    case when v_trj is not null then ', transfer journal 2 chargers' else '' end;
end
$seed$;
