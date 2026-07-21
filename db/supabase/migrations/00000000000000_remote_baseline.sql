-- ProFixWorld baseline schema (public) — project toxwbjofyglbyjanxmzv
-- Generated Docker-free via Supabase Management API (extract-baseline.mjs).
-- Regenerate the authoritative version with `supabase db pull` once Docker is available.
set search_path = public;

-- ============================================================
-- EXTENSIONS (5)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS supabase_vault;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- SEQUENCES (8)
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS public.activity_log_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.driver_jobs_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.driver_payouts_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.forge_activity_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.profix_drivers_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.push_subscriptions_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.store_products_id_seq;
CREATE SEQUENCE IF NOT EXISTS public.store_reviews_id_seq;

-- ============================================================
-- TABLES (94)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.activity_log (
  id bigint NOT NULL,
  shop_id uuid NOT NULL,
  ticket_id uuid,
  actor uuid NOT NULL,
  actor_email text,
  action text NOT NULL,
  at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.app_roles (
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'staff'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.bill_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  bill_id uuid,
  shop_id uuid NOT NULL,
  line_kind text NOT NULL DEFAULT 'product'::text,
  label text,
  amount numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  gst_rate numeric,
  gst_amount numeric NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS public.bills (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  ticket_id uuid,
  total numeric(10,2) NOT NULL DEFAULT 0,
  paid boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  payment_method text DEFAULT 'cash'::text,
  gst_rate numeric,
  gst_amount numeric NOT NULL DEFAULT 0,
  taxable_amount numeric
);
CREATE TABLE IF NOT EXISTS public.cash_movements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  direction text NOT NULL DEFAULT 'out'::text,
  label text,
  amount numeric NOT NULL DEFAULT 0,
  method text NOT NULL DEFAULT 'cash'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  created_by uuid
);
CREATE TABLE IF NOT EXISTS public.crm_handovers (
  ticket_id text NOT NULL,
  otp text NOT NULL,
  customer_phone text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  verified_at timestamp with time zone
);
CREATE TABLE IF NOT EXISTS public.crm_invites (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  email text NOT NULL,
  role text NOT NULL DEFAULT 'staff'::text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  name text NOT NULL,
  phone text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.demo_catalog (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_slug text NOT NULL,
  name text,
  category text,
  price integer,
  stock integer DEFAULT 10,
  image_url text
);
CREATE TABLE IF NOT EXISTS public.demo_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_slug text NOT NULL,
  customer_name text,
  phone text,
  address text,
  items jsonb,
  total integer,
  status text DEFAULT 'new'::text,
  notes text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.demo_shops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL,
  name text NOT NULL,
  niche text,
  tagline text,
  brand jsonb,
  whatsapp text,
  order_type text DEFAULT 'delivery'::text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.driver_jobs (
  id bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  job_type text NOT NULL,
  ref_kind text,
  ref_id text,
  customer_name text,
  customer_phone text,
  from_addr text NOT NULL,
  to_addr text NOT NULL,
  shop_id bigint,
  fee numeric(10,2) NOT NULL DEFAULT 0,
  assigned_driver bigint,
  accepted_by bigint,
  status text NOT NULL DEFAULT 'open'::text,
  pickup_otp text,
  drop_otp text,
  pickup_verified_at timestamp with time zone,
  drop_verified_at timestamp with time zone,
  accepted_at timestamp with time zone,
  notes text
);
CREATE TABLE IF NOT EXISTS public.driver_payouts (
  id bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  driver_id bigint NOT NULL,
  job_id bigint NOT NULL,
  amount numeric(10,2) NOT NULL,
  status text NOT NULL DEFAULT 'unpaid'::text,
  paid_at timestamp with time zone
);
CREATE TABLE IF NOT EXISTS public.eng_activity (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid,
  work_item_id uuid,
  actor uuid,
  actor_email text,
  action text,
  at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.eng_inventory (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  name text NOT NULL,
  category text,
  sku text,
  qty numeric DEFAULT 0,
  cost numeric,
  price numeric,
  updated_at timestamp with time zone DEFAULT now(),
  reorder_at integer DEFAULT 3
);
CREATE TABLE IF NOT EXISTS public.eng_invites (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  email text NOT NULL,
  shop_id uuid,
  role text NOT NULL DEFAULT 'owner'::text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.eng_memberships (
  user_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  role text NOT NULL
);
CREATE TABLE IF NOT EXISTS public.eng_operators (
  user_id uuid NOT NULL,
  level text NOT NULL DEFAULT 'operator'::text,
  email text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.eng_partner_clients (
  partner_user_id uuid NOT NULL,
  shop_id uuid NOT NULL
);
CREATE TABLE IF NOT EXISTS public.eng_patterns (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  key text NOT NULL,
  label text,
  accent text DEFAULT '#7c5cff'::text,
  item_s text DEFAULT 'Item'::text,
  item_p text DEFAULT 'Items'::text,
  money text DEFAULT 'Bill'::text,
  statuses jsonb NOT NULL DEFAULT '[]'::jsonb,
  fields jsonb NOT NULL DEFAULT '[]'::jsonb,
  description text,
  source text DEFAULT 'ai'::text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.eng_shops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  niche text NOT NULL DEFAULT 'repair'::text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.eng_tenants (
  subdomain text NOT NULL,
  shop_id uuid,
  brand_name text,
  color text DEFAULT '#4f7cff'::text,
  logo_url text,
  updated_at timestamp with time zone DEFAULT now(),
  capture_on boolean DEFAULT false,
  headline text,
  review_url text
);
CREATE TABLE IF NOT EXISTS public.entities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  key text NOT NULL,
  label text,
  icon text,
  sort integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.fields (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  key text NOT NULL,
  label text,
  type text NOT NULL DEFAULT 'text'::text,
  is_private boolean NOT NULL DEFAULT false,
  required boolean NOT NULL DEFAULT false,
  options jsonb DEFAULT '[]'::jsonb,
  sort integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_activity (
  id bigint NOT NULL,
  app_id uuid NOT NULL,
  actor_id uuid,
  action text NOT NULL,
  entity_key text,
  record_id uuid,
  diff jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_apps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  slug text NOT NULL,
  name text NOT NULL,
  tagline text,
  industry text,
  brand jsonb NOT NULL DEFAULT '{}'::jsonb,
  features jsonb NOT NULL DEFAULT '[]'::jsonb,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft'::text,
  share_token text NOT NULL DEFAULT encode(gen_random_bytes(12), 'hex'::text),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  in_gallery boolean NOT NULL DEFAULT false,
  api_key text,
  webhook_url text
);
CREATE TABLE IF NOT EXISTS public.forge_entities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  app_id uuid NOT NULL,
  key text NOT NULL,
  label text NOT NULL,
  icon text,
  sort integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  options jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS public.forge_fields (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  key text NOT NULL,
  label text NOT NULL,
  type text NOT NULL DEFAULT 'text'::text,
  required boolean NOT NULL DEFAULT false,
  is_private boolean NOT NULL DEFAULT false,
  options jsonb NOT NULL DEFAULT '{}'::jsonb,
  sort integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS public.forge_invites (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  app_id uuid NOT NULL,
  token text NOT NULL DEFAULT replace((gen_random_uuid())::text, '-'::text, ''::text),
  role text NOT NULL DEFAULT 'staff'::text,
  created_by uuid NOT NULL,
  used_by uuid,
  used_at timestamp with time zone,
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + '7 days'::interval),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_leads (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'lokaforge'::text,
  name text,
  business text,
  phone text,
  email text,
  message text,
  config jsonb,
  status text NOT NULL DEFAULT 'new'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_members (
  app_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'staff'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_plans (
  user_id uuid NOT NULL,
  plan text NOT NULL DEFAULT 'free'::text,
  max_apps integer NOT NULL DEFAULT 3,
  max_records integer NOT NULL DEFAULT 500,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  app_id uuid NOT NULL,
  entity_id uuid NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_records_private (
  record_id uuid NOT NULL,
  app_id uuid NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.forge_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  token text NOT NULL DEFAULT replace((gen_random_uuid())::text, '-'::text, ''::text),
  name text NOT NULL,
  config jsonb NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.inventory (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  category text,
  item text NOT NULL,
  brand text,
  spec text,
  qty integer NOT NULL DEFAULT 0,
  unit text DEFAULT 'pcs'::text,
  cost numeric,
  sell numeric,
  reorder_at integer,
  notes text,
  updated_at timestamp with time zone DEFAULT now(),
  updated_by uuid,
  shop_id uuid
);
CREATE TABLE IF NOT EXISTS public.kv (
  user_id uuid NOT NULL,
  k text NOT NULL,
  v jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.memberships (
  user_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  role shop_role NOT NULL DEFAULT 'staff'::shop_role
);
CREATE TABLE IF NOT EXISTS public.neet_questions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  subject text NOT NULL,
  unit text,
  chapter text NOT NULL,
  difficulty text NOT NULL DEFAULT 'medium'::text,
  source text NOT NULL DEFAULT 'gen'::text,
  q text NOT NULL,
  options jsonb NOT NULL,
  answer_index integer NOT NULL,
  explanation text NOT NULL,
  ncert_ref text,
  verified boolean NOT NULL DEFAULT true,
  report_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.partner_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  name text NOT NULL,
  business_name text,
  phone text NOT NULL,
  pin_hash text NOT NULL,
  active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS public.partner_submissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  partner_id uuid NOT NULL,
  kind text NOT NULL DEFAULT 'new'::text,
  product_id bigint,
  name text NOT NULL,
  brand text,
  price integer NOT NULL,
  qty integer NOT NULL DEFAULT 0,
  image_url text,
  note text,
  status text NOT NULL DEFAULT 'pending'::text,
  reviewed_at timestamp with time zone,
  reject_reason text,
  deleted_at timestamp with time zone,
  images text[],
  description text
);
CREATE TABLE IF NOT EXISTS public.parts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  name text NOT NULL,
  stock_qty integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  category text
);
CREATE TABLE IF NOT EXISTS public.parts_pricing (
  part_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  cost numeric,
  price numeric
);
CREATE TABLE IF NOT EXISTS public.platform_admins (
  user_id uuid NOT NULL,
  email text,
  added_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.profix_drivers (
  id bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  full_name text NOT NULL,
  phone text NOT NULL,
  vehicle text,
  license_last4 text,
  status text NOT NULL DEFAULT 'pending'::text,
  available boolean NOT NULL DEFAULT false,
  driver_code text,
  pin text,
  home_shop bigint,
  notes text,
  address text,
  area text,
  vehicle_type text,
  vehicle_number text,
  upi_id text,
  emergency_contact text,
  review_notes text,
  reviewed_at timestamp with time zone,
  reviewed_by text,
  id_doc_path text,
  photo_path text
);
CREATE TABLE IF NOT EXISTS public.profix_shops (
  id integer NOT NULL,
  name text NOT NULL,
  location text,
  cctv_url text,
  active boolean NOT NULL DEFAULT true,
  sort integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id bigint NOT NULL,
  endpoint text NOT NULL,
  p256dh text NOT NULL,
  auth text NOT NULL,
  role text NOT NULL DEFAULT 'customer'::text,
  phone text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  entity_key text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.records_private (
  record_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS public.registry (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  niche text,
  owner text,
  contact text,
  tier text DEFAULT 'A'::text,
  status text DEFAULT 'building'::text,
  url text,
  project text,
  supabase_ref text,
  tenant text,
  version text,
  deployed date,
  notes text,
  gate_owner boolean DEFAULT false,
  gate_staff boolean DEFAULT false,
  updated_at timestamp with time zone DEFAULT now(),
  shop_id uuid
);
CREATE TABLE IF NOT EXISTS public.repair_tickets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  customer_id uuid,
  device_brand text,
  device_model text,
  imei text,
  complaint text,
  lock_code text,
  accessories text,
  status text NOT NULL DEFAULT 'Received'::text,
  estimate numeric(10,2),
  date_in timestamp with time zone NOT NULL DEFAULT now(),
  date_out timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  handled_by uuid,
  return_reason text,
  diagnostic_fee numeric,
  parent_ticket_id uuid,
  is_rework boolean NOT NULL DEFAULT false,
  rework_is_warranty boolean,
  warranty_until date,
  return_outcome text,
  is_warranty boolean DEFAULT false
);
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  kind text NOT NULL DEFAULT 'accessory'::text,
  item text,
  qty integer DEFAULT 1,
  amount numeric NOT NULL DEFAULT 0,
  customer_phone text,
  note text,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamp with time zone DEFAULT now(),
  payment_method text DEFAULT 'cash'::text,
  return_outcome text,
  return_reason text,
  inventory_id uuid,
  line_kind text DEFAULT 'product'::text,
  gst_rate numeric,
  gst_amount numeric NOT NULL DEFAULT 0,
  taxable_amount numeric
);
CREATE TABLE IF NOT EXISTS public.sales_private (
  sale_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  return_fee numeric,
  refund_amount numeric,
  profit numeric,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.shop_groups (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.shop_service_costs (
  service_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  cost numeric
);
CREATE TABLE IF NOT EXISTS public.shop_services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  price numeric NOT NULL DEFAULT 0,
  estimated_minutes integer,
  category text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.shop_settings (
  shop_id uuid NOT NULL,
  business_name text,
  address text,
  phone text,
  gstin text,
  logo_url text,
  invoice_prefix text DEFAULT 'INV-'::text,
  terms text,
  updated_at timestamp with time zone DEFAULT now(),
  gst_enabled boolean NOT NULL DEFAULT false,
  gst_rate numeric NOT NULL DEFAULT 18,
  gst_inclusive boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS public.shops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  review_url text,
  latitude double precision,
  longitude double precision,
  slug text,
  niche text,
  group_id uuid,
  created_by uuid DEFAULT auth.uid()
);
CREATE TABLE IF NOT EXISTS public.staff_advances (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  amount integer NOT NULL,
  reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.staff_attendance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  clock_in timestamp with time zone NOT NULL DEFAULT now(),
  clock_out timestamp with time zone,
  in_lat double precision,
  in_lng double precision,
  out_lat double precision,
  out_lng double precision,
  device text,
  auto_closed boolean NOT NULL DEFAULT false,
  edited boolean NOT NULL DEFAULT false,
  shop_id integer
);
CREATE TABLE IF NOT EXISTS public.staff_daily_notes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  day date NOT NULL DEFAULT ((now() AT TIME ZONE 'Asia/Kolkata'::text))::date,
  note text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.staff_incentives (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  staff_id uuid NOT NULL,
  amount integer NOT NULL,
  reason text NOT NULL,
  note text,
  status text NOT NULL DEFAULT 'assigned'::text,
  paid_at timestamp with time zone
);
CREATE TABLE IF NOT EXISTS public.staff_leave (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  from_day date NOT NULL,
  to_day date NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  decided_at timestamp with time zone,
  decided_note text
);
CREATE TABLE IF NOT EXISTS public.staff_live_location (
  staff_id uuid NOT NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.staff_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  name text NOT NULL,
  code text NOT NULL,
  pin_hash text NOT NULL,
  role text NOT NULL DEFAULT 'staff'::text,
  daily_wage integer,
  active boolean NOT NULL DEFAULT true,
  phone text,
  address text,
  emergency_name text,
  emergency_phone text,
  id_number text,
  joining_date date,
  monthly_salary integer,
  works_in text NOT NULL DEFAULT 'store'::text,
  photo_url text,
  notes text,
  home_shop_id integer DEFAULT 1,
  employee_uid text,
  father_mother_name text,
  dob date,
  gender text,
  blood_group text,
  marital_status text,
  aadhaar_last4 text,
  pan text,
  driving_licence text,
  alt_phone text,
  email text,
  permanent_address text,
  department text,
  designation text,
  employment_type text,
  working_shift text,
  seniority text,
  emergency_relation text,
  bank_name text,
  bank_account text,
  bank_ifsc text,
  docs jsonb NOT NULL DEFAULT '{}'::jsonb,
  declared_on date
);
CREATE TABLE IF NOT EXISTS public.staff_roster (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  day date NOT NULL,
  staff_id uuid NOT NULL,
  shop_id integer NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.staff_settings (
  id integer NOT NULL DEFAULT 1,
  shop_lat double precision,
  shop_lng double precision,
  radius_m integer NOT NULL DEFAULT 150
);
CREATE TABLE IF NOT EXISTS public.staff_todos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  title text NOT NULL,
  detail text,
  done boolean NOT NULL DEFAULT false,
  created_by text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  done_at timestamp with time zone
);
CREATE TABLE IF NOT EXISTS public.stock_moves (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  product_id bigint NOT NULL,
  qty integer NOT NULL,
  reason text NOT NULL,
  doc_id uuid
);
CREATE TABLE IF NOT EXISTS public.store_buyback (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  customer_name text NOT NULL,
  phone text NOT NULL,
  brand text NOT NULL,
  model text NOT NULL,
  condition text NOT NULL,
  age_months integer,
  notes text,
  status text NOT NULL DEFAULT 'new'::text,
  quote_amount integer
);
CREATE TABLE IF NOT EXISTS public.store_cash (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  direction text NOT NULL,
  amount integer NOT NULL,
  reason text,
  staff text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.store_categories (
  id integer NOT NULL,
  name text NOT NULL,
  sort_order integer DEFAULT 0
);
CREATE TABLE IF NOT EXISTS public.store_coupons (
  code text NOT NULL,
  kind text DEFAULT 'pct'::text,
  value integer NOT NULL,
  min_order integer DEFAULT 0,
  first_order_only boolean DEFAULT false,
  active boolean DEFAULT true,
  expires_at timestamp with time zone
);
CREATE TABLE IF NOT EXISTS public.store_daycloses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  day date NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  orders_count integer NOT NULL,
  expected_total integer NOT NULL,
  counted_cash integer NOT NULL,
  difference integer NOT NULL,
  notes text,
  shop_id integer NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS public.store_order_issues (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  order_id uuid NOT NULL,
  phone text NOT NULL,
  issue_type text NOT NULL,
  message text,
  status text NOT NULL DEFAULT 'open'::text
);
CREATE TABLE IF NOT EXISTS public.store_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  phone text NOT NULL,
  apartment text,
  address text,
  items jsonb NOT NULL,
  total numeric,
  payment_mode text DEFAULT 'COD'::text,
  status text DEFAULT 'new'::text,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  paid_method text,
  cod_collected boolean DEFAULT false,
  eta_at timestamp with time zone,
  delivery_staff_id uuid,
  dest_lat double precision,
  dest_lng double precision,
  shop_id integer,
  handover_otp text,
  handover_verified_at timestamp with time zone
);
CREATE TABLE IF NOT EXISTS public.store_products (
  id bigint NOT NULL DEFAULT nextval('store_products_id_seq'::regclass),
  category_id integer,
  name text NOT NULL,
  brand text,
  spec text,
  stock integer DEFAULT 0,
  price numeric,
  image_url text,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  featured boolean NOT NULL DEFAULT false,
  description text,
  owner_id uuid,
  published boolean DEFAULT true,
  partner_name text,
  cost_price integer,
  compat text[],
  partner_id uuid,
  images text[]
);
CREATE TABLE IF NOT EXISTS public.store_refunds (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  phone text,
  reason text,
  status text DEFAULT 'requested'::text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.store_repairs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  phone text NOT NULL,
  address text,
  device text,
  issue text,
  preferred_slot text,
  quote numeric,
  status text DEFAULT 'new'::text,
  created_at timestamp with time zone DEFAULT now(),
  assigned_partner uuid,
  assigned_staff_id uuid,
  visit_status text,
  visit_updated_at timestamp with time zone,
  amount_collected integer,
  is_walk_in boolean NOT NULL DEFAULT false,
  shop_id integer,
  handover_otp text,
  handover_verified_at timestamp with time zone
);
CREATE TABLE IF NOT EXISTS public.store_reviews (
  id bigint NOT NULL,
  product_id bigint,
  rating integer NOT NULL,
  name text,
  comment text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.store_roles (
  user_id uuid NOT NULL,
  role text DEFAULT 'partner'::text,
  partner_name text,
  kind text DEFAULT 'accessories'::text
);
CREATE TABLE IF NOT EXISTS public.store_sales (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  amount integer NOT NULL,
  gst_amount integer DEFAULT 0,
  payment_method text DEFAULT 'cash'::text,
  note text,
  staff text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.store_services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_type text,
  customer_name text,
  phone text,
  current_number text,
  operator text,
  preferred_slot text,
  notes text,
  status text DEFAULT 'new'::text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.store_settings (
  id integer NOT NULL DEFAULT 1,
  delivery_fee integer NOT NULL DEFAULT 30,
  free_delivery_above integer NOT NULL DEFAULT 499,
  min_order integer NOT NULL DEFAULT 249,
  upi_vpa text,
  upi_name text DEFAULT 'ProFix'::text,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  theme text NOT NULL DEFAULT 'classic'::text
);
CREATE TABLE IF NOT EXISTS public.store_signups (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  phone text,
  name text,
  area text,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.ticket_money (
  ticket_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  labour numeric,
  final_price numeric,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  return_fee numeric,
  refund_amount numeric
);
CREATE TABLE IF NOT EXISTS public.ticket_part_prices (
  ticket_part_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  unit_price numeric
);
CREATE TABLE IF NOT EXISTS public.ticket_parts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  part_id uuid,
  qty integer NOT NULL DEFAULT 1,
  name text,
  inventory_id uuid
);
CREATE TABLE IF NOT EXISTS public.ticket_service_costs (
  ticket_service_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  cost numeric
);
CREATE TABLE IF NOT EXISTS public.ticket_services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  service_id uuid,
  name text,
  price numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.trade_counters (
  doc_type text NOT NULL,
  yr integer NOT NULL,
  n integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS public.trade_docs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  code text NOT NULL,
  doc_type text NOT NULL,
  partner_id uuid NOT NULL,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  total integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'issued'::text,
  notes text,
  deleted_at timestamp with time zone,
  gst_percent integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS public.work_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL,
  niche text NOT NULL,
  customer text,
  phone text,
  status text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  handled_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.work_money (
  work_item_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  amount numeric,
  updated_at timestamp with time zone DEFAULT now()
);

-- ============================================================
-- CONSTRAINTS (PK/UNIQUE/CHECK/FK) (236)
-- ============================================================
ALTER TABLE public.activity_log ADD CONSTRAINT activity_log_pkey PRIMARY KEY (id);
ALTER TABLE public.app_roles ADD CONSTRAINT app_roles_pkey PRIMARY KEY (user_id);
ALTER TABLE public.bill_items ADD CONSTRAINT bill_items_pkey PRIMARY KEY (id);
ALTER TABLE public.bills ADD CONSTRAINT bills_pkey PRIMARY KEY (id);
ALTER TABLE public.cash_movements ADD CONSTRAINT cash_movements_pkey PRIMARY KEY (id);
ALTER TABLE public.crm_handovers ADD CONSTRAINT crm_handovers_pkey PRIMARY KEY (ticket_id);
ALTER TABLE public.crm_invites ADD CONSTRAINT crm_invites_pkey PRIMARY KEY (id);
ALTER TABLE public.customers ADD CONSTRAINT customers_pkey PRIMARY KEY (id);
ALTER TABLE public.demo_catalog ADD CONSTRAINT demo_catalog_pkey PRIMARY KEY (id);
ALTER TABLE public.demo_orders ADD CONSTRAINT demo_orders_pkey PRIMARY KEY (id);
ALTER TABLE public.demo_shops ADD CONSTRAINT demo_shops_pkey PRIMARY KEY (id);
ALTER TABLE public.demo_shops ADD CONSTRAINT demo_shops_slug_key UNIQUE (slug);
ALTER TABLE public.driver_jobs ADD CONSTRAINT driver_jobs_job_type_check CHECK ((job_type = ANY (ARRAY['pickup'::text, 'drop'::text, 'return'::text, 'order_delivery'::text, 'parts_run'::text, 'shop_transfer'::text])));
ALTER TABLE public.driver_jobs ADD CONSTRAINT driver_jobs_pkey PRIMARY KEY (id);
ALTER TABLE public.driver_jobs ADD CONSTRAINT driver_jobs_ref_kind_check CHECK ((ref_kind = ANY (ARRAY['store_repair'::text, 'store_order'::text, 'crm_ticket'::text, 'other'::text])));
ALTER TABLE public.driver_jobs ADD CONSTRAINT driver_jobs_status_check CHECK ((status = ANY (ARRAY['open'::text, 'accepted'::text, 'going_pickup'::text, 'picked_up'::text, 'dropped'::text, 'cancelled'::text])));
ALTER TABLE public.driver_payouts ADD CONSTRAINT driver_payouts_job_id_key UNIQUE (job_id);
ALTER TABLE public.driver_payouts ADD CONSTRAINT driver_payouts_pkey PRIMARY KEY (id);
ALTER TABLE public.driver_payouts ADD CONSTRAINT driver_payouts_status_check CHECK ((status = ANY (ARRAY['unpaid'::text, 'paid'::text])));
ALTER TABLE public.eng_activity ADD CONSTRAINT eng_activity_pkey PRIMARY KEY (id);
ALTER TABLE public.eng_inventory ADD CONSTRAINT eng_inventory_pkey PRIMARY KEY (id);
ALTER TABLE public.eng_invites ADD CONSTRAINT eng_invites_pkey PRIMARY KEY (id);
ALTER TABLE public.eng_memberships ADD CONSTRAINT eng_memberships_pkey PRIMARY KEY (user_id, shop_id);
ALTER TABLE public.eng_memberships ADD CONSTRAINT eng_memberships_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'staff'::text])));
ALTER TABLE public.eng_operators ADD CONSTRAINT eng_operators_level_check CHECK ((level = ANY (ARRAY['operator'::text, 'partner'::text])));
ALTER TABLE public.eng_operators ADD CONSTRAINT eng_operators_pkey PRIMARY KEY (user_id);
ALTER TABLE public.eng_partner_clients ADD CONSTRAINT eng_partner_clients_pkey PRIMARY KEY (partner_user_id, shop_id);
ALTER TABLE public.eng_patterns ADD CONSTRAINT eng_patterns_key_key UNIQUE (key);
ALTER TABLE public.eng_patterns ADD CONSTRAINT eng_patterns_pkey PRIMARY KEY (id);
ALTER TABLE public.eng_shops ADD CONSTRAINT eng_shops_pkey PRIMARY KEY (id);
ALTER TABLE public.eng_tenants ADD CONSTRAINT eng_tenants_pkey PRIMARY KEY (subdomain);
ALTER TABLE public.entities ADD CONSTRAINT entities_pkey PRIMARY KEY (id);
ALTER TABLE public.entities ADD CONSTRAINT entities_shop_id_key_key UNIQUE (shop_id, key);
ALTER TABLE public.fields ADD CONSTRAINT fields_entity_id_key_key UNIQUE (entity_id, key);
ALTER TABLE public.fields ADD CONSTRAINT fields_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_activity ADD CONSTRAINT forge_activity_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_apps ADD CONSTRAINT forge_apps_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_apps ADD CONSTRAINT forge_apps_slug_key UNIQUE (slug);
ALTER TABLE public.forge_apps ADD CONSTRAINT forge_apps_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text])));
ALTER TABLE public.forge_entities ADD CONSTRAINT forge_entities_app_id_key_key UNIQUE (app_id, key);
ALTER TABLE public.forge_entities ADD CONSTRAINT forge_entities_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_fields ADD CONSTRAINT forge_fields_entity_id_key_key UNIQUE (entity_id, key);
ALTER TABLE public.forge_fields ADD CONSTRAINT forge_fields_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_fields ADD CONSTRAINT forge_fields_type_check CHECK ((type = ANY (ARRAY['text'::text, 'number'::text, 'money'::text, 'date'::text, 'datetime'::text, 'select'::text, 'multiselect'::text, 'boolean'::text, 'phone'::text, 'email'::text, 'url'::text, 'image'::text, 'longtext'::text])));
ALTER TABLE public.forge_invites ADD CONSTRAINT forge_invites_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_invites ADD CONSTRAINT forge_invites_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'staff'::text])));
ALTER TABLE public.forge_invites ADD CONSTRAINT forge_invites_token_key UNIQUE (token);
ALTER TABLE public.forge_leads ADD CONSTRAINT forge_leads_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_leads ADD CONSTRAINT forge_leads_source_check CHECK ((source = ANY (ARRAY['lokaforge'::text, 'demo-factory'::text, 'happyloka'::text])));
ALTER TABLE public.forge_leads ADD CONSTRAINT forge_leads_status_check CHECK ((status = ANY (ARRAY['new'::text, 'contacted'::text, 'converted'::text, 'closed'::text])));
ALTER TABLE public.forge_members ADD CONSTRAINT forge_members_pkey PRIMARY KEY (app_id, user_id);
ALTER TABLE public.forge_members ADD CONSTRAINT forge_members_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'staff'::text])));
ALTER TABLE public.forge_plans ADD CONSTRAINT forge_plans_pkey PRIMARY KEY (user_id);
ALTER TABLE public.forge_records ADD CONSTRAINT forge_records_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_records_private ADD CONSTRAINT forge_records_private_pkey PRIMARY KEY (record_id);
ALTER TABLE public.forge_templates ADD CONSTRAINT forge_templates_pkey PRIMARY KEY (id);
ALTER TABLE public.forge_templates ADD CONSTRAINT forge_templates_token_key UNIQUE (token);
ALTER TABLE public.inventory ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);
ALTER TABLE public.kv ADD CONSTRAINT kv_pkey PRIMARY KEY (user_id, k);
ALTER TABLE public.memberships ADD CONSTRAINT memberships_pkey PRIMARY KEY (user_id, shop_id);
ALTER TABLE public.neet_questions ADD CONSTRAINT neet_questions_answer_index_check CHECK (((answer_index >= 0) AND (answer_index <= 3)));
ALTER TABLE public.neet_questions ADD CONSTRAINT neet_questions_difficulty_check CHECK ((difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text])));
ALTER TABLE public.neet_questions ADD CONSTRAINT neet_questions_pkey PRIMARY KEY (id);
ALTER TABLE public.neet_questions ADD CONSTRAINT neet_questions_subject_check CHECK ((subject = ANY (ARRAY['Physics'::text, 'Chemistry'::text, 'Botany'::text, 'Zoology'::text])));
ALTER TABLE public.partner_members ADD CONSTRAINT partner_members_phone_key UNIQUE (phone);
ALTER TABLE public.partner_members ADD CONSTRAINT partner_members_pkey PRIMARY KEY (id);
ALTER TABLE public.partner_submissions ADD CONSTRAINT partner_submissions_kind_check CHECK ((kind = ANY (ARRAY['new'::text, 'price_change'::text])));
ALTER TABLE public.partner_submissions ADD CONSTRAINT partner_submissions_pkey PRIMARY KEY (id);
ALTER TABLE public.partner_submissions ADD CONSTRAINT partner_submissions_price_check CHECK ((price > 0));
ALTER TABLE public.partner_submissions ADD CONSTRAINT partner_submissions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])));
ALTER TABLE public.parts ADD CONSTRAINT parts_pkey PRIMARY KEY (id);
ALTER TABLE public.parts_pricing ADD CONSTRAINT parts_pricing_pkey PRIMARY KEY (part_id);
ALTER TABLE public.platform_admins ADD CONSTRAINT platform_admins_pkey PRIMARY KEY (user_id);
ALTER TABLE public.profix_drivers ADD CONSTRAINT profix_drivers_driver_code_key UNIQUE (driver_code);
ALTER TABLE public.profix_drivers ADD CONSTRAINT profix_drivers_phone_key UNIQUE (phone);
ALTER TABLE public.profix_drivers ADD CONSTRAINT profix_drivers_pkey PRIMARY KEY (id);
ALTER TABLE public.profix_drivers ADD CONSTRAINT profix_drivers_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'under_review'::text, 'active'::text, 'rejected'::text, 'blocked'::text])));
ALTER TABLE public.profix_shops ADD CONSTRAINT profix_shops_pkey PRIMARY KEY (id);
ALTER TABLE public.push_subscriptions ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);
ALTER TABLE public.push_subscriptions ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);
ALTER TABLE public.records ADD CONSTRAINT records_pkey PRIMARY KEY (id);
ALTER TABLE public.records_private ADD CONSTRAINT records_private_pkey PRIMARY KEY (record_id);
ALTER TABLE public.registry ADD CONSTRAINT registry_pkey PRIMARY KEY (id);
ALTER TABLE public.repair_tickets ADD CONSTRAINT repair_tickets_pkey PRIMARY KEY (id);
ALTER TABLE public.sales ADD CONSTRAINT sales_pkey PRIMARY KEY (id);
ALTER TABLE public.sales_private ADD CONSTRAINT sales_private_pkey PRIMARY KEY (sale_id);
ALTER TABLE public.shop_groups ADD CONSTRAINT shop_groups_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_service_costs ADD CONSTRAINT shop_service_costs_pkey PRIMARY KEY (service_id);
ALTER TABLE public.shop_services ADD CONSTRAINT shop_services_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_settings ADD CONSTRAINT shop_settings_pkey PRIMARY KEY (shop_id);
ALTER TABLE public.shops ADD CONSTRAINT shops_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_advances ADD CONSTRAINT staff_advances_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_attendance ADD CONSTRAINT staff_attendance_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_daily_notes ADD CONSTRAINT staff_daily_notes_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_incentives ADD CONSTRAINT staff_incentives_amount_check CHECK ((amount > 0));
ALTER TABLE public.staff_incentives ADD CONSTRAINT staff_incentives_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_leave ADD CONSTRAINT staff_leave_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_leave ADD CONSTRAINT staff_leave_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])));
ALTER TABLE public.staff_live_location ADD CONSTRAINT staff_live_location_pkey PRIMARY KEY (staff_id);
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_code_key UNIQUE (code);
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_employee_uid_key UNIQUE (employee_uid);
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_employment_type_check CHECK (((employment_type = ANY (ARRAY['full_time'::text, 'part_time'::text, 'trainee'::text, 'contract'::text])) OR (employment_type IS NULL)));
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_gender_check CHECK (((gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text])) OR (gender IS NULL)));
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_marital_status_check CHECK (((marital_status = ANY (ARRAY['single'::text, 'married'::text])) OR (marital_status IS NULL)));
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_seniority_check CHECK (((seniority = ANY (ARRAY['junior'::text, 'senior'::text, 'lead'::text])) OR (seniority IS NULL)));
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_works_in_check CHECK ((works_in = ANY (ARRAY['store'::text, 'crm'::text, 'both'::text])));
ALTER TABLE public.staff_roster ADD CONSTRAINT staff_roster_day_staff_id_key UNIQUE (day, staff_id);
ALTER TABLE public.staff_roster ADD CONSTRAINT staff_roster_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_settings ADD CONSTRAINT staff_settings_id_check CHECK ((id = 1));
ALTER TABLE public.staff_settings ADD CONSTRAINT staff_settings_pkey PRIMARY KEY (id);
ALTER TABLE public.staff_todos ADD CONSTRAINT staff_todos_pkey PRIMARY KEY (id);
ALTER TABLE public.stock_moves ADD CONSTRAINT stock_moves_pkey PRIMARY KEY (id);
ALTER TABLE public.store_buyback ADD CONSTRAINT store_buyback_pkey PRIMARY KEY (id);
ALTER TABLE public.store_cash ADD CONSTRAINT store_cash_pkey PRIMARY KEY (id);
ALTER TABLE public.store_categories ADD CONSTRAINT store_categories_name_key UNIQUE (name);
ALTER TABLE public.store_categories ADD CONSTRAINT store_categories_pkey PRIMARY KEY (id);
ALTER TABLE public.store_coupons ADD CONSTRAINT store_coupons_pkey PRIMARY KEY (code);
ALTER TABLE public.store_daycloses ADD CONSTRAINT store_daycloses_pkey PRIMARY KEY (id);
ALTER TABLE public.store_order_issues ADD CONSTRAINT store_order_issues_issue_type_check CHECK ((issue_type = ANY (ARRAY['refund'::text, 'replacement'::text, 'other'::text])));
ALTER TABLE public.store_order_issues ADD CONSTRAINT store_order_issues_pkey PRIMARY KEY (id);
ALTER TABLE public.store_orders ADD CONSTRAINT store_orders_pkey PRIMARY KEY (id);
ALTER TABLE public.store_products ADD CONSTRAINT store_products_pkey PRIMARY KEY (id);
ALTER TABLE public.store_refunds ADD CONSTRAINT store_refunds_pkey PRIMARY KEY (id);
ALTER TABLE public.store_repairs ADD CONSTRAINT store_repairs_pkey PRIMARY KEY (id);
ALTER TABLE public.store_repairs ADD CONSTRAINT store_repairs_visit_status_check CHECK (((visit_status = ANY (ARRAY['assigned'::text, 'on_the_way'::text, 'reached'::text, 'repaired'::text, 'collected'::text])) OR (visit_status IS NULL)));
ALTER TABLE public.store_reviews ADD CONSTRAINT store_reviews_pkey PRIMARY KEY (id);
ALTER TABLE public.store_reviews ADD CONSTRAINT store_reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)));
ALTER TABLE public.store_roles ADD CONSTRAINT store_roles_pkey PRIMARY KEY (user_id);
ALTER TABLE public.store_sales ADD CONSTRAINT store_sales_pkey PRIMARY KEY (id);
ALTER TABLE public.store_services ADD CONSTRAINT store_services_pkey PRIMARY KEY (id);
ALTER TABLE public.store_settings ADD CONSTRAINT store_settings_id_check CHECK ((id = 1));
ALTER TABLE public.store_settings ADD CONSTRAINT store_settings_pkey PRIMARY KEY (id);
ALTER TABLE public.store_signups ADD CONSTRAINT store_signups_pkey PRIMARY KEY (id);
ALTER TABLE public.ticket_money ADD CONSTRAINT ticket_money_pkey PRIMARY KEY (ticket_id);
ALTER TABLE public.ticket_part_prices ADD CONSTRAINT ticket_part_prices_pkey PRIMARY KEY (ticket_part_id);
ALTER TABLE public.ticket_parts ADD CONSTRAINT ticket_parts_pkey PRIMARY KEY (id);
ALTER TABLE public.ticket_service_costs ADD CONSTRAINT ticket_service_costs_pkey PRIMARY KEY (ticket_service_id);
ALTER TABLE public.ticket_services ADD CONSTRAINT ticket_services_pkey PRIMARY KEY (id);
ALTER TABLE public.trade_counters ADD CONSTRAINT trade_counters_pkey PRIMARY KEY (doc_type, yr);
ALTER TABLE public.trade_docs ADD CONSTRAINT trade_docs_code_key UNIQUE (code);
ALTER TABLE public.trade_docs ADD CONSTRAINT trade_docs_doc_type_check CHECK ((doc_type = ANY (ARRAY['PO'::text, 'SL'::text])));
ALTER TABLE public.trade_docs ADD CONSTRAINT trade_docs_pkey PRIMARY KEY (id);
ALTER TABLE public.trade_docs ADD CONSTRAINT trade_docs_status_check CHECK ((status = ANY (ARRAY['issued'::text, 'received'::text, 'dispatched'::text, 'paid'::text, 'cancelled'::text])));
ALTER TABLE public.work_items ADD CONSTRAINT work_items_pkey PRIMARY KEY (id);
ALTER TABLE public.work_money ADD CONSTRAINT work_money_pkey PRIMARY KEY (work_item_id);
ALTER TABLE public.bill_items ADD CONSTRAINT bill_items_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE;
ALTER TABLE public.bills ADD CONSTRAINT bills_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.bills ADD CONSTRAINT bills_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES repair_tickets(id) ON DELETE SET NULL;
ALTER TABLE public.customers ADD CONSTRAINT customers_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.driver_jobs ADD CONSTRAINT driver_jobs_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES profix_drivers(id);
ALTER TABLE public.driver_jobs ADD CONSTRAINT driver_jobs_assigned_driver_fkey FOREIGN KEY (assigned_driver) REFERENCES profix_drivers(id);
ALTER TABLE public.driver_payouts ADD CONSTRAINT driver_payouts_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES profix_drivers(id);
ALTER TABLE public.driver_payouts ADD CONSTRAINT driver_payouts_job_id_fkey FOREIGN KEY (job_id) REFERENCES driver_jobs(id);
ALTER TABLE public.eng_activity ADD CONSTRAINT eng_activity_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.eng_inventory ADD CONSTRAINT eng_inventory_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.eng_invites ADD CONSTRAINT eng_invites_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.eng_memberships ADD CONSTRAINT eng_memberships_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.eng_memberships ADD CONSTRAINT eng_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.eng_operators ADD CONSTRAINT eng_operators_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.eng_partner_clients ADD CONSTRAINT eng_partner_clients_partner_user_id_fkey FOREIGN KEY (partner_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.eng_partner_clients ADD CONSTRAINT eng_partner_clients_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.eng_patterns ADD CONSTRAINT eng_patterns_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
ALTER TABLE public.eng_tenants ADD CONSTRAINT eng_tenants_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.entities ADD CONSTRAINT entities_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.fields ADD CONSTRAINT fields_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE;
ALTER TABLE public.fields ADD CONSTRAINT fields_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.forge_activity ADD CONSTRAINT forge_activity_app_id_fkey FOREIGN KEY (app_id) REFERENCES forge_apps(id) ON DELETE CASCADE;
ALTER TABLE public.forge_apps ADD CONSTRAINT forge_apps_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.forge_entities ADD CONSTRAINT forge_entities_app_id_fkey FOREIGN KEY (app_id) REFERENCES forge_apps(id) ON DELETE CASCADE;
ALTER TABLE public.forge_fields ADD CONSTRAINT forge_fields_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES forge_entities(id) ON DELETE CASCADE;
ALTER TABLE public.forge_invites ADD CONSTRAINT forge_invites_app_id_fkey FOREIGN KEY (app_id) REFERENCES forge_apps(id) ON DELETE CASCADE;
ALTER TABLE public.forge_members ADD CONSTRAINT forge_members_app_id_fkey FOREIGN KEY (app_id) REFERENCES forge_apps(id) ON DELETE CASCADE;
ALTER TABLE public.forge_members ADD CONSTRAINT forge_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.forge_plans ADD CONSTRAINT forge_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.forge_records ADD CONSTRAINT forge_records_app_id_fkey FOREIGN KEY (app_id) REFERENCES forge_apps(id) ON DELETE CASCADE;
ALTER TABLE public.forge_records ADD CONSTRAINT forge_records_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
ALTER TABLE public.forge_records ADD CONSTRAINT forge_records_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES forge_entities(id) ON DELETE CASCADE;
ALTER TABLE public.forge_records_private ADD CONSTRAINT forge_records_private_app_id_fkey FOREIGN KEY (app_id) REFERENCES forge_apps(id) ON DELETE CASCADE;
ALTER TABLE public.forge_records_private ADD CONSTRAINT forge_records_private_record_id_fkey FOREIGN KEY (record_id) REFERENCES forge_records(id) ON DELETE CASCADE;
ALTER TABLE public.inventory ADD CONSTRAINT inventory_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.kv ADD CONSTRAINT kv_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.memberships ADD CONSTRAINT memberships_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.memberships ADD CONSTRAINT memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.partner_submissions ADD CONSTRAINT partner_submissions_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partner_members(id);
ALTER TABLE public.partner_submissions ADD CONSTRAINT partner_submissions_product_id_fkey FOREIGN KEY (product_id) REFERENCES store_products(id);
ALTER TABLE public.parts ADD CONSTRAINT parts_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.parts_pricing ADD CONSTRAINT parts_pricing_part_id_fkey FOREIGN KEY (part_id) REFERENCES parts(id) ON DELETE CASCADE;
ALTER TABLE public.records ADD CONSTRAINT records_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.records_private ADD CONSTRAINT records_private_record_id_fkey FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE;
ALTER TABLE public.records_private ADD CONSTRAINT records_private_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.registry ADD CONSTRAINT registry_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.repair_tickets ADD CONSTRAINT repair_tickets_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;
ALTER TABLE public.repair_tickets ADD CONSTRAINT repair_tickets_handled_by_fkey FOREIGN KEY (handled_by) REFERENCES auth.users(id);
ALTER TABLE public.repair_tickets ADD CONSTRAINT repair_tickets_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.sales ADD CONSTRAINT sales_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE SET NULL;
ALTER TABLE public.sales ADD CONSTRAINT sales_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.sales_private ADD CONSTRAINT sales_private_sale_id_fkey FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE;
ALTER TABLE public.shop_service_costs ADD CONSTRAINT shop_service_costs_service_id_fkey FOREIGN KEY (service_id) REFERENCES shop_services(id) ON DELETE CASCADE;
ALTER TABLE public.shops ADD CONSTRAINT shops_group_id_fkey FOREIGN KEY (group_id) REFERENCES shop_groups(id) ON DELETE SET NULL;
ALTER TABLE public.staff_advances ADD CONSTRAINT staff_advances_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.staff_attendance ADD CONSTRAINT staff_attendance_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES profix_shops(id);
ALTER TABLE public.staff_attendance ADD CONSTRAINT staff_attendance_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.staff_daily_notes ADD CONSTRAINT staff_daily_notes_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.staff_incentives ADD CONSTRAINT staff_incentives_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.staff_leave ADD CONSTRAINT staff_leave_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.staff_live_location ADD CONSTRAINT staff_live_location_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.staff_members ADD CONSTRAINT staff_members_home_shop_id_fkey FOREIGN KEY (home_shop_id) REFERENCES profix_shops(id);
ALTER TABLE public.staff_roster ADD CONSTRAINT staff_roster_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES profix_shops(id);
ALTER TABLE public.staff_roster ADD CONSTRAINT staff_roster_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.staff_todos ADD CONSTRAINT staff_todos_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff_members(id);
ALTER TABLE public.stock_moves ADD CONSTRAINT stock_moves_doc_id_fkey FOREIGN KEY (doc_id) REFERENCES trade_docs(id);
ALTER TABLE public.stock_moves ADD CONSTRAINT stock_moves_product_id_fkey FOREIGN KEY (product_id) REFERENCES store_products(id);
ALTER TABLE public.store_daycloses ADD CONSTRAINT store_daycloses_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES profix_shops(id);
ALTER TABLE public.store_order_issues ADD CONSTRAINT store_order_issues_order_id_fkey FOREIGN KEY (order_id) REFERENCES store_orders(id);
ALTER TABLE public.store_orders ADD CONSTRAINT store_orders_delivery_staff_id_fkey FOREIGN KEY (delivery_staff_id) REFERENCES staff_members(id);
ALTER TABLE public.store_orders ADD CONSTRAINT store_orders_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES profix_shops(id);
ALTER TABLE public.store_products ADD CONSTRAINT store_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES store_categories(id);
ALTER TABLE public.store_products ADD CONSTRAINT store_products_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partner_members(id);
ALTER TABLE public.store_repairs ADD CONSTRAINT store_repairs_assigned_staff_id_fkey FOREIGN KEY (assigned_staff_id) REFERENCES staff_members(id);
ALTER TABLE public.store_repairs ADD CONSTRAINT store_repairs_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES profix_shops(id);
ALTER TABLE public.store_reviews ADD CONSTRAINT store_reviews_product_id_fkey FOREIGN KEY (product_id) REFERENCES store_products(id) ON DELETE CASCADE;
ALTER TABLE public.store_roles ADD CONSTRAINT store_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.ticket_money ADD CONSTRAINT ticket_money_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES repair_tickets(id) ON DELETE CASCADE;
ALTER TABLE public.ticket_part_prices ADD CONSTRAINT ticket_part_prices_ticket_part_id_fkey FOREIGN KEY (ticket_part_id) REFERENCES ticket_parts(id) ON DELETE CASCADE;
ALTER TABLE public.ticket_parts ADD CONSTRAINT ticket_parts_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE SET NULL;
ALTER TABLE public.ticket_parts ADD CONSTRAINT ticket_parts_part_id_fkey FOREIGN KEY (part_id) REFERENCES parts(id) ON DELETE SET NULL;
ALTER TABLE public.ticket_parts ADD CONSTRAINT ticket_parts_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE public.ticket_parts ADD CONSTRAINT ticket_parts_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES repair_tickets(id) ON DELETE CASCADE;
ALTER TABLE public.ticket_service_costs ADD CONSTRAINT ticket_service_costs_ticket_service_id_fkey FOREIGN KEY (ticket_service_id) REFERENCES ticket_services(id) ON DELETE CASCADE;
ALTER TABLE public.ticket_services ADD CONSTRAINT ticket_services_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES repair_tickets(id) ON DELETE CASCADE;
ALTER TABLE public.trade_docs ADD CONSTRAINT trade_docs_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partner_members(id);
ALTER TABLE public.work_items ADD CONSTRAINT work_items_handled_by_fkey FOREIGN KEY (handled_by) REFERENCES auth.users(id);
ALTER TABLE public.work_items ADD CONSTRAINT work_items_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.work_money ADD CONSTRAINT work_money_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES eng_shops(id) ON DELETE CASCADE;
ALTER TABLE public.work_money ADD CONSTRAINT work_money_work_item_id_fkey FOREIGN KEY (work_item_id) REFERENCES work_items(id) ON DELETE CASCADE;

-- ============================================================
-- INDEXES (45)
-- ============================================================
CREATE INDEX activity_log_shop_idx ON public.activity_log USING btree (shop_id, at DESC);
CREATE INDEX bill_items_bill_idx ON public.bill_items USING btree (bill_id);
CREATE INDEX bill_items_shop_idx ON public.bill_items USING btree (shop_id, created_at DESC);
CREATE INDEX bills_shop_idx ON public.bills USING btree (shop_id);
CREATE INDEX cash_movements_shop_idx ON public.cash_movements USING btree (shop_id, created_at DESC);
CREATE INDEX crm_invites_email_idx ON public.crm_invites USING btree (lower(email));
CREATE INDEX crm_invites_shop_idx ON public.crm_invites USING btree (shop_id);
CREATE INDEX customers_phone_idx ON public.customers USING btree (phone);
CREATE INDEX customers_shop_idx ON public.customers USING btree (shop_id);
CREATE INDEX eng_inv_shop_idx ON public.eng_inventory USING btree (shop_id);
CREATE INDEX eng_patterns_key_idx ON public.eng_patterns USING btree (key);
CREATE INDEX idx_entities_shop ON public.entities USING btree (shop_id, sort);
CREATE INDEX idx_fields_entity ON public.fields USING btree (entity_id, sort);
CREATE INDEX forge_activity_app_idx ON public.forge_activity USING btree (app_id, created_at DESC);
CREATE INDEX forge_members_user_idx ON public.forge_members USING btree (user_id);
CREATE INDEX forge_records_app_entity_idx ON public.forge_records USING btree (app_id, entity_id, created_at DESC);
CREATE INDEX kv_user_idx ON public.kv USING btree (user_id);
CREATE INDEX neet_q_chapter_idx ON public.neet_questions USING btree (chapter);
CREATE INDEX neet_q_difficulty_idx ON public.neet_questions USING btree (difficulty);
CREATE INDEX neet_q_reports_idx ON public.neet_questions USING btree (report_count DESC);
CREATE INDEX neet_q_subject_idx ON public.neet_questions USING btree (subject);
CREATE INDEX idx_sub_status ON public.partner_submissions USING btree (status, created_at DESC);
CREATE INDEX parts_shop_idx ON public.parts USING btree (shop_id);
CREATE INDEX push_subs_phone_idx ON public.push_subscriptions USING btree (phone);
CREATE INDEX push_subs_role_idx ON public.push_subscriptions USING btree (role);
CREATE INDEX idx_records_shop_entity ON public.records USING btree (shop_id, entity_key, created_at DESC);
CREATE UNIQUE INDEX registry_shop_uidx ON public.registry USING btree (shop_id) WHERE (shop_id IS NOT NULL);
CREATE INDEX repair_tickets_parent_idx ON public.repair_tickets USING btree (parent_ticket_id);
CREATE INDEX tickets_customer_idx ON public.repair_tickets USING btree (customer_id);
CREATE INDEX tickets_shop_idx ON public.repair_tickets USING btree (shop_id);
CREATE INDEX tickets_status_idx ON public.repair_tickets USING btree (shop_id, status);
CREATE INDEX idx_sales_shop_day ON public.sales USING btree (shop_id, created_at DESC);
CREATE INDEX idx_adv_staff ON public.staff_advances USING btree (staff_id, created_at);
CREATE INDEX idx_att_staff_day ON public.staff_attendance USING btree (staff_id, clock_in);
CREATE INDEX idx_leave_status ON public.staff_leave USING btree (status, from_day);
CREATE INDEX idx_roster_day ON public.staff_roster USING btree (day);
CREATE INDEX idx_todos_staff ON public.staff_todos USING btree (staff_id, done);
CREATE UNIQUE INDEX uq_dayclose_day_shop ON public.store_daycloses USING btree (day, shop_id);
CREATE INDEX idx_orders_created ON public.store_orders USING btree (created_at DESC);
CREATE INDEX idx_products_cat ON public.store_products USING btree (category_id);
CREATE INDEX idx_bookings_created ON public.store_repairs USING btree (created_at DESC);
CREATE INDEX store_reviews_product_idx ON public.store_reviews USING btree (product_id);
CREATE INDEX ticket_parts_ticket_idx ON public.ticket_parts USING btree (ticket_id);
CREATE INDEX idx_docs_code ON public.trade_docs USING btree (code);
CREATE INDEX work_items_shop_idx ON public.work_items USING btree (shop_id);

-- ============================================================
-- FUNCTIONS / RPCs (134)
-- ============================================================
CREATE OR REPLACE FUNCTION public._driver_auth(p_code text, p_pin text)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id from profix_drivers
   where driver_code = p_code and pin = p_pin and status = 'active'
$function$
;
CREATE OR REPLACE FUNCTION public._driver_force_pending()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_owner() then
    new.status := 'pending';
    new.driver_code := null;
    new.pin := null;
    new.available := false;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public._gen_otp()
 RETURNS text
 LANGUAGE sql
AS $function$
  select lpad((floor(random()*10000))::int::text, 4, '0');
$function$
;
CREATE OR REPLACE FUNCTION public._norm_phone(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select right(regexp_replace(coalesce(p,''), '\D', '', 'g'), 10)
$function$
;
CREATE OR REPLACE FUNCTION public._order_stock_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare it jsonb;
begin
  if (new.status = 'delivered') and (old.status is distinct from 'delivered') then
    perform set_config('app.skip_stock_log','1', true);
    for it in select * from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) loop
      if (it->>'product_id') is not null and coalesce((it->>'qty')::int,0) > 0 then
        update store_products set stock = greatest(coalesce(stock,0) - (it->>'qty')::int, 0)
        where id = (it->>'product_id')::bigint;
        insert into stock_moves (product_id, qty, reason)
        values ((it->>'product_id')::bigint, -(it->>'qty')::int, 'sale');
      end if;
    end loop;
  elsif (old.status = 'delivered') and (new.status is distinct from 'delivered') then
    perform set_config('app.skip_stock_log','1', true);
    for it in select * from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) loop
      if (it->>'product_id') is not null and coalesce((it->>'qty')::int,0) > 0 then
        update store_products set stock = coalesce(stock,0) + (it->>'qty')::int
        where id = (it->>'product_id')::bigint;
        insert into stock_moves (product_id, qty, reason)
        values ((it->>'product_id')::bigint, (it->>'qty')::int, 'sale_reversal');
      end if;
    end loop;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public._partner_auth(p_phone text, p_pin text)
 RETURNS partner_members
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members;
begin
  select * into v from partner_members
  where phone = _norm_phone(p_phone) and active = true;
  if v.id is null or v.pin_hash <> crypt(coalesce(p_pin,''), v.pin_hash) then
    perform pg_sleep(1);
    raise exception 'Wrong phone or PIN';
  end if;
  return v;
end $function$
;
CREATE OR REPLACE FUNCTION public._product_stock_log()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(current_setting('app.skip_stock_log', true),'') = '1' then return new; end if;
  if new.stock is distinct from old.stock then
    insert into stock_moves (product_id, qty, reason)
    values (new.id, coalesce(new.stock,0) - coalesce(old.stock,0), 'adjust');
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public._require_owner()
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_owner() then raise exception 'Owner only'; end if;
end $function$
;
CREATE OR REPLACE FUNCTION public._require_owner_or_staff()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.role() <> 'authenticated' then
    raise exception 'Sign in required';
  end if;
end $function$
;
CREATE OR REPLACE FUNCTION public._staff_auth(p_code text, p_pin text)
 RETURNS staff_members
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  select * into v from staff_members
  where upper(code) = upper(trim(p_code)) and active = true;
  if v.id is null or v.pin_hash <> crypt(coalesce(p_pin,''), v.pin_hash) then
    perform pg_sleep(1);   -- slow brute force
    raise exception 'Wrong staff code or PIN';
  end if;
  return v;
end $function$
;
CREATE OR REPLACE FUNCTION public.add_member(p_shop uuid, p_user uuid, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from public.memberships
    where shop_id = p_shop and user_id = auth.uid() and role = 'owner'
  ) then
    raise exception 'only an owner of this shop can add members';
  end if;
  insert into public.memberships(user_id, shop_id, role)
    values (p_user, p_shop, p_role::public.shop_role)
    on conflict (user_id, shop_id) do update set role = excluded.role;
end $function$
;
CREATE OR REPLACE FUNCTION public.add_ticket_part(p_ticket uuid, p_part uuid, p_qty integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s uuid; pr numeric; tp uuid;
begin
  select shop_id into s from repair_tickets where id = p_ticket;
  if s is null or not exists (select 1 from memberships m where m.shop_id = s and m.user_id = auth.uid())
  then raise exception 'not allowed'; end if;
  select price into pr from parts_pricing where part_id = p_part;
  insert into ticket_parts (ticket_id, shop_id, part_id, qty)
    values (p_ticket, s, p_part, p_qty) returning id into tp;
  insert into ticket_part_prices (ticket_part_id, shop_id, unit_price)
    values (tp, s, coalesce(pr,0));
  update parts set stock_qty = greatest(0, coalesce(stock_qty,0) - p_qty) where id = p_part;
end; $function$
;
CREATE OR REPLACE FUNCTION public.add_ticket_service(p_ticket uuid, p_service uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s uuid; pr numeric; co numeric; nm text; tsid uuid;
begin
  select shop_id into s from repair_tickets where id=p_ticket;
  if s is null or not exists (select 1 from memberships m where m.shop_id=s and m.user_id=auth.uid())
  then raise exception 'not allowed'; end if;
  select name, price into nm, pr from shop_services where id=p_service and shop_id=s and is_active;
  if nm is null then raise exception 'service not found'; end if;
  select cost into co from shop_service_costs where service_id=p_service;
  insert into ticket_services(ticket_id,shop_id,service_id,name,price)
    values(p_ticket,s,p_service,nm,coalesce(pr,0)) returning id into tsid;
  insert into ticket_service_costs(ticket_service_id,shop_id,cost) values(tsid,s,co);
end; $function$
;
CREATE OR REPLACE FUNCTION public.admin_approve_submission(p_sub_id uuid, p_name text, p_brand text, p_price integer, p_qty integer, p_category_id bigint, p_image_url text, p_images text[], p_description text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s partner_submissions; v_pid bigint;
begin
  perform _require_owner();
  select * into s from partner_submissions where id = p_sub_id and status = 'pending' and deleted_at is null;
  if s.id is null then raise exception 'Submission not found or already reviewed'; end if;
  if s.kind = 'new' then
    insert into store_products (name, brand, price, stock, image_url, images, description, category_id, partner_id)
    values (coalesce(left(p_name,120), s.name), coalesce(left(p_brand,60), s.brand),
            coalesce(p_price, s.price), coalesce(p_qty, s.qty),
            coalesce(p_image_url, s.image_url),
            coalesce(p_images, s.images),
            left(coalesce(p_description, s.description, ''),1000),
            p_category_id, s.partner_id)
    returning id into v_pid;
  else
    update store_products set price = coalesce(p_price, s.price)
    where id = s.product_id returning id into v_pid;
  end if;
  update partner_submissions set status='approved', reviewed_at=now(), product_id=v_pid where id = s.id;
  return v_pid;
end $function$
;
CREATE OR REPLACE FUNCTION public.admin_upsert_partner(p_id uuid, p_name text, p_business text, p_phone text, p_pin text, p_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if auth.role() <> 'authenticated' then raise exception 'Not allowed'; end if;
  if length(_norm_phone(p_phone)) <> 10 then raise exception 'Enter a valid 10-digit phone'; end if;
  if p_id is null then
    if p_pin is null or length(p_pin) < 4 then raise exception 'PIN must be at least 4 digits'; end if;
    insert into partner_members (name, business_name, phone, pin_hash, active)
    values (left(p_name,80), left(coalesce(p_business,''),120), _norm_phone(p_phone),
            crypt(p_pin, gen_salt('bf')), coalesce(p_active,true))
    returning id into v_id;
  else
    update partner_members set
      name = coalesce(left(p_name,80), name),
      business_name = coalesce(left(p_business,120), business_name),
      phone = coalesce(_norm_phone(p_phone), phone),
      pin_hash = case when p_pin is not null and length(p_pin) >= 4
                      then crypt(p_pin, gen_salt('bf')) else pin_hash end,
      active = coalesce(p_active, active)
    where id = p_id returning id into v_id;
  end if;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.admin_upsert_staff(p_id uuid, p_name text, p_code text, p_pin text, p_role text, p_wage integer, p_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if auth.role() <> 'authenticated' then
    raise exception 'Not allowed';
  end if;
  if p_id is null then
    if p_pin is null or length(p_pin) < 4 then
      raise exception 'PIN must be at least 4 digits';
    end if;
    insert into staff_members (name, code, pin_hash, role, daily_wage, active)
    values (left(p_name,80), upper(trim(p_code)), crypt(p_pin, gen_salt('bf')),
            coalesce(p_role,'staff'), p_wage, coalesce(p_active,true))
    returning id into v_id;
  else
    update staff_members set
      name = coalesce(left(p_name,80), name),
      code = coalesce(upper(trim(p_code)), code),
      pin_hash = case when p_pin is not null and length(p_pin) >= 4
                      then crypt(p_pin, gen_salt('bf')) else pin_hash end,
      role = coalesce(p_role, role),
      daily_wage = coalesce(p_wage, daily_wage),
      active = coalesce(p_active, active)
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.apply_coupon(c text, sub integer)
 RETURNS TABLE(ok boolean, discount integer, msg text, first_only boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  declare r store_coupons; begin
    select * into r from store_coupons where upper(code)=upper(c) and active=true
      and (expires_at is null or expires_at > now());
    if not found then return query select false,0,'Invalid or expired code',false; return; end if;
    if sub < r.min_order then
      return query select false,0,('Add ₹'||(r.min_order - sub)||' more to use this'), r.first_order_only; return; end if;
    return query select true,
      least(sub, case when r.kind='pct' then (sub * r.value / 100) else r.value end),
      'Applied', r.first_order_only; return;
  end $function$
;
CREATE OR REPLACE FUNCTION public.auto_close_stale_shifts()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  perform _require_owner();
  update staff_attendance
  set clock_out = clock_in + interval '10 hours', auto_closed = true
  where clock_out is null and clock_in < now() - interval '14 hours';
  get diagnostics n = row_count;
  return n;
end $function$
;
CREATE OR REPLACE FUNCTION public.cancel_my_order(p_order_id uuid, p_phone text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_status text;
begin
  select status into v_status from store_orders
  where id = p_order_id and _norm_phone(phone) = _norm_phone(p_phone);
  if v_status is null then
    raise exception 'Order not found for this phone';
  end if;
  -- cancellable only before packing starts (live statuses: new, confirmed)
  if v_status not in ('new','confirmed') then
    raise exception 'Order can no longer be cancelled — please call the shop';
  end if;
  update store_orders set status = 'cancelled',
    notes = coalesce(notes,'') || ' | cancelled by customer ' || to_char(now(),'DD Mon HH24:MI')
  where id = p_order_id;
  return 'cancelled';
end $function$
;
CREATE OR REPLACE FUNCTION public.create_shop(p_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare new_id uuid;
begin
  insert into public.shops(name) values (p_name) returning id into new_id;
  insert into public.memberships(user_id, shop_id, role)
    values (auth.uid(), new_id, 'owner');
  return new_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.create_shop_service(p_shop uuid, p_name text, p_price numeric, p_cost numeric DEFAULT NULL::numeric, p_desc text DEFAULT NULL::text, p_minutes integer DEFAULT NULL::integer, p_category text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare new_id uuid;
begin
  if not is_owner_of(p_shop) then raise exception 'owner only'; end if;
  insert into shop_services(shop_id,name,price,description,estimated_minutes,category)
    values(p_shop,p_name,coalesce(p_price,0),p_desc,p_minutes,p_category) returning id into new_id;
  insert into shop_service_costs(service_id,shop_id,cost) values(new_id,p_shop,p_cost);
  return new_id;
end; $function$
;
CREATE OR REPLACE FUNCTION public.crm_accept_invites()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid uuid := auth.uid();
  em  text := lower(coalesce(auth.jwt() ->> 'email',''));
  n   int  := 0;
begin
  if uid is null or em = '' then return 0; end if;
  insert into memberships (user_id, shop_id, role)
  select uid, i.shop_id, i.role::shop_role
  from crm_invites i
  where lower(i.email) = em
    and not exists (select 1 from memberships m where m.user_id = uid and m.shop_id = i.shop_id);
  get diagnostics n = row_count;
  delete from crm_invites where lower(email) = em;
  return n;
end; $function$
;
CREATE OR REPLACE FUNCTION public.crm_handover_status(p_ticket_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare row crm_handovers;
begin
  if auth.role() <> 'authenticated' then raise exception 'Sign in required'; end if;
  select * into row from crm_handovers where ticket_id = p_ticket_id;
  if row.ticket_id is null then return json_build_object('exists', false); end if;
  return json_build_object('exists', true, 'otp', row.otp,
    'verified', row.verified_at is not null, 'verified_at', row.verified_at);
end $function$
;
CREATE OR REPLACE FUNCTION public.crm_make_otp(p_ticket_id text, p_phone text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_otp text; row crm_handovers;
begin
  if auth.role() <> 'authenticated' then raise exception 'Sign in required'; end if;
  if coalesce(btrim(p_ticket_id),'')='' then raise exception 'No ticket id'; end if;
  select * into row from crm_handovers where ticket_id = p_ticket_id;
  if row.ticket_id is null then
    v_otp := _gen_otp();
    insert into crm_handovers (ticket_id, otp, customer_phone) values (p_ticket_id, v_otp, p_phone);
  else
    v_otp := row.otp;
    if p_phone is not null and row.customer_phone is null then
      update crm_handovers set customer_phone = p_phone where ticket_id = p_ticket_id;
    end if;
  end if;
  return v_otp;
end $function$
;
CREATE OR REPLACE FUNCTION public.crm_verify_otp(p_ticket_id text, p_otp text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare row crm_handovers;
begin
  if auth.role() <> 'authenticated' then raise exception 'Sign in required'; end if;
  select * into row from crm_handovers where ticket_id = p_ticket_id;
  if row.ticket_id is null then raise exception 'No code generated for this ticket yet'; end if;
  if p_otp is null or btrim(p_otp) <> row.otp then raise exception 'Wrong code'; end if;
  update crm_handovers set verified_at = now() where ticket_id = p_ticket_id;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.delete_shop_service(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s uuid;
begin
  select shop_id into s from shop_services where id=p_id;
  if s is null or not is_owner_of(s) then raise exception 'owner only'; end if;
  delete from shop_services where id=p_id;
end; $function$
;
CREATE OR REPLACE FUNCTION public.dispatch_trade_doc(p_doc_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d trade_docs; it jsonb; cnt int := 0;
begin
  perform _require_owner();
  perform set_config('app.skip_stock_log','1', true);
  select * into d from trade_docs where id = p_doc_id and deleted_at is null;
  if d.id is null then raise exception 'Doc not found'; end if;
  if d.doc_type <> 'SL' or d.status <> 'issued' then raise exception 'Only an issued SL can be dispatched'; end if;
  for it in select * from jsonb_array_elements(d.items) loop
    if (it->>'product_id') is not null and coalesce((it->>'qty')::int,0) > 0 then
      update store_products set stock = greatest(coalesce(stock,0) - (it->>'qty')::int, 0)
      where id = (it->>'product_id')::bigint;
      insert into stock_moves (product_id, qty, reason, doc_id)
      values ((it->>'product_id')::bigint, -(it->>'qty')::int, 'sl_dispatched', d.id);
      cnt := cnt + 1;
    end if;
  end loop;
  update trade_docs set status='dispatched' where id = d.id;
  return cnt;
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_accept_job(p_code text, p_pin text, p_job bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint; v_ok int;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return false; end if;
  update driver_jobs
     set accepted_by = v_id, status = 'accepted', accepted_at = now()
   where id = p_job and status = 'open'
     and (assigned_driver is null or assigned_driver = v_id);
  get diagnostics v_ok = row_count;
  return v_ok = 1;   -- first accept wins (atomic)
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_earnings_summary(p_code text, p_pin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return json_build_object('ok', false); end if;
  return (
    select json_build_object(
      'ok', true,
      'today',  coalesce(sum(amount) filter (where created_at::date = current_date), 0),
      'week',   coalesce(sum(amount) filter (where created_at >= date_trunc('week', now())), 0),
      'month',  coalesce(sum(amount) filter (where created_at >= date_trunc('month', now())), 0),
      'total',  coalesce(sum(amount), 0),
      'unpaid', coalesce(sum(amount) filter (where status = 'unpaid'), 0),
      'jobs_done', count(*)
    )
    from driver_payouts where driver_id = v_id
  );
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_job_create(p_type text, p_ref_kind text, p_ref_id text, p_cust_name text, p_cust_phone text, p_from text, p_to text, p_shop bigint, p_fee numeric, p_assigned bigint DEFAULT NULL::bigint, p_notes text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_pick text; v_drop text; v_id bigint;
begin
  if not is_owner() then return json_build_object('ok', false, 'err', 'owner only'); end if;
  v_pick := lpad((floor(random()*10000))::int::text, 4, '0');
  v_drop := lpad((floor(random()*10000))::int::text, 4, '0');
  insert into driver_jobs (job_type, ref_kind, ref_id, customer_name, customer_phone,
    from_addr, to_addr, shop_id, fee, assigned_driver, pickup_otp, drop_otp, notes)
  values (p_type, p_ref_kind, p_ref_id, p_cust_name, p_cust_phone,
    p_from, p_to, p_shop, p_fee, p_assigned, v_pick, v_drop, p_notes)
  returning id into v_id;
  return json_build_object('ok', true, 'id', v_id, 'pickup_otp', v_pick, 'drop_otp', v_drop);
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_jobs_list(p_code text, p_pin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return '[]'::json; end if;
  return coalesce((
    select json_agg(j order by j.created_at desc) from (
      select id, created_at, job_type, customer_name, from_addr, to_addr,
             fee, status, accepted_by, assigned_driver,
             (accepted_by = v_id) as mine
        from driver_jobs
       where status <> 'cancelled'
         and ( (status = 'open' and (assigned_driver is null or assigned_driver = v_id))
               or accepted_by = v_id )
         and (status <> 'dropped' or accepted_by = v_id)
       limit 100
    ) j), '[]'::json);
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_login(p_code text, p_pin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint; v_row profix_drivers;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return json_build_object('ok', false); end if;
  select * into v_row from profix_drivers where id = v_id;
  return json_build_object('ok', true, 'id', v_row.id, 'name', v_row.full_name,
                           'available', v_row.available, 'vehicle', v_row.vehicle);
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_my_earnings(p_code text, p_pin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return '[]'::json; end if;
  return coalesce((
    select json_agg(p order by p.created_at desc) from (
      select dp.amount, dp.status, dp.created_at, dp.paid_at, dp.job_id,
             dj.job_type, dj.from_addr, dj.to_addr
        from driver_payouts dp
        join driver_jobs dj on dj.id = dp.job_id
       where dp.driver_id = v_id
       limit 200
    ) p), '[]'::json);
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_register(p_name text, p_phone text, p_vehicle_type text DEFAULT NULL::text, p_vehicle_number text DEFAULT NULL::text, p_lic text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_area text DEFAULT NULL::text, p_upi text DEFAULT NULL::text, p_emergency text DEFAULT NULL::text, p_id_doc_path text DEFAULT NULL::text, p_photo_path text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  if coalesce(btrim(p_name),'') = '' or coalesce(btrim(p_phone),'') = '' then
    return json_build_object('ok', false, 'err', 'Name and phone required');
  end if;
  insert into profix_drivers (
    full_name, phone, vehicle, vehicle_type, vehicle_number,
    license_last4, address, area, upi_id, emergency_contact,
    id_doc_path, photo_path
  ) values (
    btrim(p_name), btrim(p_phone),
    nullif(btrim(concat_ws(' · ', nullif(btrim(p_vehicle_type),''), nullif(btrim(p_vehicle_number),''))),''),
    nullif(btrim(p_vehicle_type),''), nullif(btrim(p_vehicle_number),''),
    nullif(btrim(p_lic),''), nullif(btrim(p_address),''), nullif(btrim(p_area),''),
    nullif(btrim(p_upi),''), nullif(btrim(p_emergency),''),
    nullif(btrim(p_id_doc_path),''), nullif(btrim(p_photo_path),'')
  ) returning id into v_id;
  return json_build_object('ok', true, 'id', v_id);
exception
  when unique_violation then
    return json_build_object('ok', false, 'err', 'This phone is already registered');
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_set_available(p_code text, p_pin text, p_avail boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return false; end if;
  update profix_drivers set available = p_avail where id = v_id;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_update_status(p_code text, p_pin text, p_job bigint, p_status text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint; v_ok int;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null or p_status not in ('going_pickup') then return false; end if;
  update driver_jobs set status = p_status
   where id = p_job and accepted_by = v_id and status = 'accepted';
  get diagnostics v_ok = row_count;
  return v_ok = 1;
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_verify_drop(p_code text, p_pin text, p_job bigint, p_otp text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint; v_ok int; v_fee numeric;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return false; end if;
  update driver_jobs
     set status = 'dropped', drop_verified_at = now()
   where id = p_job and accepted_by = v_id
     and status = 'picked_up' and drop_otp = p_otp;
  get diagnostics v_ok = row_count;
  if v_ok = 1 then
    select fee into v_fee from driver_jobs where id = p_job;
    insert into driver_payouts (driver_id, job_id, amount)
    values (v_id, p_job, coalesce(v_fee,0))
    on conflict (job_id) do nothing;
  end if;
  return v_ok = 1;
end $function$
;
CREATE OR REPLACE FUNCTION public.driver_verify_pickup(p_code text, p_pin text, p_job bigint, p_otp text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint; v_ok int;
begin
  v_id := _driver_auth(p_code, p_pin);
  if v_id is null then return false; end if;
  update driver_jobs
     set status = 'picked_up', pickup_verified_at = now()
   where id = p_job and accepted_by = v_id
     and status in ('accepted','going_pickup')
     and pickup_otp = p_otp;
  get diagnostics v_ok = row_count;
  return v_ok = 1;
end $function$
;
CREATE OR REPLACE FUNCTION public.eng_accept_invites()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int := 0; r record; em text;
begin
  select lower(email) into em from auth.users where id=auth.uid();
  for r in select * from eng_invites where lower(email)=em loop
    insert into eng_memberships(user_id, shop_id, role) values (auth.uid(), r.shop_id, r.role) on conflict do nothing;
    delete from eng_invites where id=r.id; n := n+1;
  end loop;
  return n;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_add_member(p_shop uuid, p_user uuid, p_role text DEFAULT 'staff'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from eng_memberships m where m.shop_id=p_shop and m.user_id=auth.uid() and m.role='owner') then
    raise exception 'only an owner of this shop can add members';
  end if;
  insert into eng_memberships(user_id,shop_id,role) values (p_user,p_shop,coalesce(p_role,'staff'))
  on conflict (user_id,shop_id) do update set role=excluded.role;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_add_operator(p_email text, p_level text DEFAULT 'partner'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid uuid;
begin
  if not eng_is_operator() then raise exception 'operators only'; end if;
  select id into uid from auth.users where lower(email)=lower(p_email);
  if uid is null then raise exception 'no account for % yet â have them sign in once first', p_email; end if;
  insert into eng_operators(user_id, level, email) values (uid, coalesce(p_level,'partner'), lower(p_email))
    on conflict (user_id) do update set level=excluded.level;
  return 'added '||p_email||' as '||coalesce(p_level,'partner');
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_assign_partner(p_partner_email text, p_shop uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid uuid;
begin
  if not eng_is_operator() then raise exception 'operators only'; end if;
  select id into uid from auth.users where lower(email)=lower(p_partner_email);
  if uid is null then raise exception 'no account for %', p_partner_email; end if;
  insert into eng_partner_clients(partner_user_id, shop_id) values (uid, p_shop) on conflict do nothing;
  return 'assigned '||p_partner_email||' to this client';
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_can_edit_shop(p_shop uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from eng_memberships m where m.shop_id=p_shop and m.user_id=auth.uid())
      or exists(select 1 from eng_operators o where o.user_id=auth.uid() and o.level='operator'); $function$
;
CREATE OR REPLACE FUNCTION public.eng_can_see_shop(p_shop uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from eng_memberships m where m.shop_id=p_shop and m.user_id=auth.uid())
      or exists(select 1 from eng_operators o where o.user_id=auth.uid() and o.level='operator')
      or exists(select 1 from eng_partner_clients pc where pc.shop_id=p_shop and pc.partner_user_id=auth.uid()); $function$
;
CREATE OR REPLACE FUNCTION public.eng_capture_lead(p_subdomain text, p_name text, p_phone text, p_note text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare sid uuid; nm text;
begin
  if coalesce(btrim(p_name),'')='' then return false; end if;
  select shop_id into sid from eng_tenants where subdomain=lower(btrim(p_subdomain)) and capture_on=true;
  if sid is null then return false; end if;            -- unknown shop or capture disabled
  select niche into nm from eng_shops where id=sid;
  insert into work_items(shop_id, niche, customer, phone, status, data)
  values (sid, coalesce(nm,'repair'),
          left(btrim(p_name),80), left(coalesce(btrim(p_phone),''),20), 'New',
          jsonb_build_object('source','lead','note', left(coalesce(p_note,''),500)));
  return true;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_claim_operator()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if exists (select 1 from eng_operators where level='operator') then
    if exists (select 1 from eng_operators where user_id=auth.uid()) then return 'already an operator'; end if;
    raise exception 'an operator already exists; ask them to add you';
  end if;
  insert into eng_operators(user_id, level, email)
    values (auth.uid(), 'operator', (select email from auth.users where id=auth.uid()))
    on conflict (user_id) do update set level='operator';
  return 'you are now the operator';
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_create_shop(p_name text, p_niche text DEFAULT 'repair'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare new_id uuid;
begin
  insert into eng_shops(name,niche) values (p_name, coalesce(p_niche,'repair')) returning id into new_id;
  insert into eng_memberships(user_id,shop_id,role) values (auth.uid(), new_id, 'owner');
  return new_id;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_is_operator()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from eng_operators where user_id=auth.uid() and level='operator'); $function$
;
CREATE OR REPLACE FUNCTION public.eng_is_owner(p_shop uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from eng_memberships m where m.shop_id=p_shop and m.user_id=auth.uid() and m.role='owner'); $function$
;
CREATE OR REPLACE FUNCTION public.eng_is_staffer()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from eng_operators where user_id=auth.uid()); $function$
;
CREATE OR REPLACE FUNCTION public.eng_list_members(p_shop uuid)
 RETURNS TABLE(user_id uuid, email text, role text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (eng_is_owner(p_shop) or eng_is_operator()) then raise exception 'owner only'; end if;
  return query select m.user_id, u.email::text, m.role
    from eng_memberships m join auth.users u on u.id=m.user_id
    where m.shop_id=p_shop order by (m.role='owner') desc, u.email;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_onboard_client(p_name text, p_niche text, p_owner_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare new_id uuid; uid uuid;
begin
  if not eng_is_staffer() then raise exception 'operators / partners only'; end if;
  insert into eng_shops(name, niche) values (p_name, coalesce(p_niche,'repair')) returning id into new_id;
  insert into registry(name, niche, owner, status, shop_id) values (p_name, p_niche, p_owner_email, 'building', new_id);
  select id into uid from auth.users where lower(email)=lower(p_owner_email);
  if uid is not null then
    insert into eng_memberships(user_id, shop_id, role) values (uid, new_id, 'owner') on conflict do nothing;
  else
    insert into eng_invites(email, shop_id, role) values (lower(p_owner_email), new_id, 'owner');
  end if;
  if not eng_is_operator() then  -- a partner who onboards is scoped to that client
    insert into eng_partner_clients(partner_user_id, shop_id) values (auth.uid(), new_id) on conflict do nothing;
  end if;
  return new_id;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_remove_member(p_shop uuid, p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (eng_is_owner(p_shop) or eng_is_operator()) then raise exception 'owner only'; end if;
  if p_user = auth.uid() then raise exception 'cannot remove yourself'; end if;
  delete from eng_memberships where shop_id=p_shop and user_id=p_user;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_save_pattern(p_key text, p_label text, p_accent text, p_item_s text, p_item_p text, p_money text, p_statuses jsonb, p_fields jsonb, p_description text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pid uuid;
begin
  if not eng_is_operator() then raise exception 'operators only'; end if;
  insert into eng_patterns(key,label,accent,item_s,item_p,money,statuses,fields,description,source,created_by)
    values (lower(p_key),p_label,p_accent,p_item_s,p_item_p,p_money,coalesce(p_statuses,'[]'::jsonb),coalesce(p_fields,'[]'::jsonb),p_description,'ai',auth.uid())
    on conflict (key) do update set
      label=excluded.label, accent=excluded.accent, item_s=excluded.item_s, item_p=excluded.item_p,
      money=excluded.money, statuses=excluded.statuses, fields=excluded.fields,
      description=excluded.description, updated_at=now()
    returning id into pid;
  return pid;
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_set_brand(p_shop uuid, p_subdomain text, p_brand text, p_color text, p_logo text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (eng_is_operator() or eng_is_owner(p_shop)) then raise exception 'not allowed'; end if;
  insert into eng_tenants(subdomain, shop_id, brand_name, color, logo_url, updated_at)
    values (lower(p_subdomain), p_shop, p_brand, coalesce(p_color,'#4f7cff'), p_logo, now())
    on conflict (subdomain) do update set
      shop_id=excluded.shop_id, brand_name=excluded.brand_name, color=excluded.color, logo_url=excluded.logo_url, updated_at=now();
end; $function$
;
CREATE OR REPLACE FUNCTION public.eng_set_marketing(p_shop uuid, p_capture_on boolean, p_headline text, p_review_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (eng_is_operator() or eng_is_owner(p_shop)) then raise exception 'not allowed'; end if;
  update eng_tenants set capture_on=coalesce(p_capture_on,false), headline=p_headline, review_url=p_review_url, updated_at=now()
   where shop_id=p_shop;
  if not found then
    raise exception 'set your subdomain/branding first (Team tab), then enable lead capture';
  end if;
end; $function$
;
CREATE OR REPLACE FUNCTION public.forge_api_insert(p_key text, p_entity text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_app forge_apps; v_ent forge_entities; v_id uuid;
begin
  select * into v_app from forge_apps where api_key = p_key;
  if v_app.id is null then raise exception 'invalid API key'; end if;
  select * into v_ent from forge_entities where app_id = v_app.id and key = p_entity;
  if v_ent.id is null then raise exception 'unknown entity %', p_entity; end if;

  insert into forge_records (app_id, entity_id, data)
  values (v_app.id, v_ent.id, coalesce(p_data, '{}'::jsonb))
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'entity', p_entity);
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_check_record_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_owner uuid; v_max int; v_cnt int;
begin
  select owner_id into v_owner from forge_apps where id = new.app_id;
  select max_records into v_max from forge_plans where user_id = v_owner;
  if v_max is null then v_max := 500; end if;
  select count(*) into v_cnt from forge_records where app_id = new.app_id;
  if v_cnt >= v_max then
    raise exception 'Record limit reached (% on this plan). Upgrade to add more.', v_max;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_create_app(p_config jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_app   forge_apps;
  v_slug  text;
  v_ent   jsonb;
  v_fld   jsonb;
  v_eid   uuid;
  v_i     int := 0;
  v_j     int;
  v_cnt   int;
  v_max   int;
begin
  if auth.uid() is null then
    raise exception 'sign in required';
  end if;

  select count(*) into v_cnt from forge_apps
    where owner_id = auth.uid() and status <> 'archived';
  select max_apps into v_max from forge_plans where user_id = auth.uid();
  if v_max is null then v_max := 3; end if;
  if v_cnt >= v_max then
    raise exception 'Plan limit: % active apps. Archive one or upgrade.', v_max;
  end if;

  v_slug := lower(regexp_replace(coalesce(nullif(p_config->>'slug',''), p_config->>'name', 'app'),
                                 '[^a-z0-9]+', '-', 'gi'));
  v_slug := trim(both '-' from v_slug);
  if v_slug = '' then v_slug := 'app'; end if;
  while exists (select 1 from forge_apps a where a.slug = v_slug) loop
    v_slug := v_slug || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 4);
  end loop;

  insert into forge_apps (owner_id, slug, name, tagline, industry, brand, features, config, share_token)
  values (
    auth.uid(), v_slug,
    coalesce(p_config->>'name', 'My App'),
    p_config->>'tagline',
    p_config->>'industry',
    coalesce(p_config->'brand', '{}'::jsonb),
    coalesce(p_config->'features', '[]'::jsonb),
    p_config,
    replace(gen_random_uuid()::text, '-', '')
  )
  returning * into v_app;

  insert into forge_members (app_id, user_id, role) values (v_app.id, auth.uid(), 'owner');

  for v_ent in select * from jsonb_array_elements(coalesce(p_config->'entities', '[]'::jsonb)) loop
    v_i := v_i + 1;
    insert into forge_entities (app_id, key, label, icon, sort, options)
    values (v_app.id, v_ent->>'key', coalesce(v_ent->>'label', v_ent->>'key'), v_ent->>'icon', v_i,
            coalesce(v_ent->'options', '{}'::jsonb))
    returning id into v_eid;

    v_j := 0;
    for v_fld in select * from jsonb_array_elements(coalesce(v_ent->'fields', '[]'::jsonb)) loop
      v_j := v_j + 1;
      insert into forge_fields (entity_id, key, label, type, required, is_private, options, sort)
      values (
        v_eid,
        v_fld->>'key',
        coalesce(v_fld->>'label', v_fld->>'key'),
        coalesce(v_fld->>'type', 'text'),
        coalesce((v_fld->>'required')::boolean, false),
        coalesce((v_fld->>'private')::boolean, false),
        coalesce(v_fld->'options', '{}'::jsonb),
        v_j
      );
    end loop;
  end loop;

  return jsonb_build_object(
    'app_id', v_app.id,
    'slug', v_app.slug,
    'share_token', v_app.share_token,
    'url', '/a/' || v_app.slug
  );
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_create_shop(p_name text, p_niche text DEFAULT NULL::text, p_group uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare new_shop uuid; grp uuid;
begin
  grp := p_group;
  if grp is null then
    insert into shop_groups(name) values (p_name) returning id into grp;
  end if;
  insert into shops(name, niche, group_id, created_by)
    values (p_name, p_niche, grp, auth.uid()) returning id into new_shop;
  insert into memberships(shop_id, user_id, role) values (new_shop, auth.uid(), 'owner');
  return new_shop;
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_gallery()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
    'name', a.name, 'tagline', a.tagline, 'industry', a.industry,
    'brand', a.brand, 'slug', a.slug, 'share_token', a.share_token
  ) order by a.updated_at desc), '[]'::jsonb)
  from forge_apps a
  where a.in_gallery = true and a.status = 'published';
$function$
;
CREATE OR REPLACE FUNCTION public.forge_get_public_app(p_slug text, p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_app forge_apps;
begin
  select * into v_app from forge_apps
    where slug = p_slug and share_token = p_token and status = 'published';
  if v_app.id is null then return null; end if;

  return jsonb_build_object(
    'name', v_app.name, 'tagline', v_app.tagline,
    'brand', v_app.brand, 'features', v_app.features,
    'entities', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'key', e.key, 'label', e.label, 'icon', e.icon,
        'fields', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'key', f.key, 'label', f.label, 'type', f.type,
            'required', f.required, 'options', f.options
          ) order by f.sort), '[]'::jsonb)
          from forge_fields f where f.entity_id = e.id and f.is_private = false
        )
      ) order by e.sort), '[]'::jsonb)
      from forge_entities e where e.app_id = v_app.id
    )
  );
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_invite_create(p_app uuid, p_role text DEFAULT 'staff'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_inv forge_invites; v_slug text;
begin
  if not forge_is_owner(p_app) then
    raise exception 'only the owner can invite';
  end if;
  if p_role not in ('owner','staff') then p_role := 'staff'; end if;

  insert into forge_invites (app_id, role, created_by)
  values (p_app, p_role, auth.uid())
  returning * into v_inv;

  select slug into v_slug from forge_apps where id = p_app;

  return jsonb_build_object(
    'token', v_inv.token,
    'role',  v_inv.role,
    'url',   '/a/' || v_slug || '?join=' || v_inv.token,
    'expires_at', v_inv.expires_at
  );
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_is_member(p_app uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from forge_members m where m.app_id = p_app and m.user_id = auth.uid());
$function$
;
CREATE OR REPLACE FUNCTION public.forge_is_owner(p_app uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from forge_members m where m.app_id = p_app and m.user_id = auth.uid() and m.role = 'owner'
  );
$function$
;
CREATE OR REPLACE FUNCTION public.forge_join(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_inv forge_invites; v_slug text;
begin
  if auth.uid() is null then
    raise exception 'sign in required';
  end if;

  select * into v_inv from forge_invites
    where token = p_token and used_at is null and expires_at > now();
  if v_inv.id is null then
    raise exception 'This invite link is invalid or has expired';
  end if;

  insert into forge_members (app_id, user_id, role)
  values (v_inv.app_id, auth.uid(), v_inv.role)
  on conflict (app_id, user_id) do nothing;

  update forge_invites set used_by = auth.uid(), used_at = now() where id = v_inv.id;

  select slug into v_slug from forge_apps where id = v_inv.app_id;
  return jsonb_build_object('app_id', v_inv.app_id, 'slug', v_slug, 'role', v_inv.role);
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_log_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_entity text;
begin
  select e.key into v_entity from forge_entities e
    where e.id = coalesce(new.entity_id, old.entity_id);
  insert into forge_activity (app_id, actor_id, action, entity_key, record_id, diff)
  values (
    coalesce(new.app_id, old.app_id),
    auth.uid(),
    lower(tg_op),
    v_entity,
    coalesce(new.id, old.id),
    case when tg_op = 'UPDATE' then jsonb_build_object('before', old.data, 'after', new.data)
         when tg_op = 'INSERT' then jsonb_build_object('after', new.data)
         else jsonb_build_object('before', old.data) end
  );
  return coalesce(new, old);
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_template_create(p_app uuid, p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_app forge_apps; v_cfg jsonb; v_tpl forge_templates;
begin
  if not forge_is_owner(p_app) then raise exception 'only the owner can make a template'; end if;
  select * into v_app from forge_apps where id = p_app;

  v_cfg := jsonb_build_object(
    'name', v_app.name, 'tagline', v_app.tagline, 'industry', v_app.industry,
    'brand', v_app.brand, 'features', v_app.features,
    'entities', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'key', e.key, 'label', e.label, 'icon', e.icon, 'options', e.options,
        'fields', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'key', f.key, 'label', f.label, 'type', f.type,
            'required', f.required, 'private', f.is_private, 'options', f.options
          ) order by f.sort), '[]'::jsonb)
          from forge_fields f where f.entity_id = e.id
        )
      ) order by e.sort), '[]'::jsonb)
      from forge_entities e where e.app_id = p_app
    )
  );

  insert into forge_templates (name, config, created_by)
  values (coalesce(nullif(p_name,''), v_app.name || ' template'), v_cfg, auth.uid())
  returning * into v_tpl;

  return jsonb_build_object('token', v_tpl.token, 'name', v_tpl.name, 'url', '/t/' || v_tpl.token);
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_template_get(p_token text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object('name', t.name, 'config', t.config)
  from forge_templates t where t.token = p_token;
$function$
;
CREATE OR REPLACE FUNCTION public.forge_touch()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.forge_webhook_fire()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_url text; v_ent text;
begin
  select webhook_url into v_url from forge_apps where id = new.app_id;
  if v_url is null or v_url = '' then return new; end if;
  if not exists (select 1 from pg_extension where extname = 'pg_net') then return new; end if;
  select key into v_ent from forge_entities where id = new.entity_id;
  begin
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object('event','record.created','entity',v_ent,'record_id',new.id,'data',new.data,'created_at',new.created_at),
      headers := '{"Content-Type":"application/json"}'::jsonb
    );
  exception when others then null;  -- never block the insert
  end;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.generate_invoice(p_ticket uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s uuid; res json;
begin
  select shop_id into s from repair_tickets where id=p_ticket;
  if s is null or not is_owner_of(s) then raise exception 'owner only'; end if;

  select json_build_object(
    'invoice_no', coalesce((select invoice_prefix from shop_settings where shop_id=s),'INV-')
                  || upper(substr(p_ticket::text,1,8)),
    'date', to_char(now(),'DD Mon YYYY'),
    'shop_name', (select name from shops where id=s),
    'settings', (select to_json(x) from (
        select business_name,address,phone,gstin,logo_url,
               coalesce(invoice_prefix,'INV-') as invoice_prefix, terms
        from shop_settings where shop_id=s) x),
    'ticket', (select json_build_object(
        'id', rt.id,
        'device', trim(coalesce(rt.device_brand,'')||' '||coalesce(rt.device_model,'')),
        'complaint', rt.complaint, 'date_in', rt.date_in, 'date_out', rt.date_out)
        from repair_tickets rt where rt.id=p_ticket),
    'customer', (select json_build_object('name', c.name, 'phone', c.phone)
        from repair_tickets rt left join customers c on c.id=rt.customer_id where rt.id=p_ticket),
    'parts', coalesce((select json_agg(json_build_object(
        'name', pa.name, 'qty', tp.qty, 'unit_price', tpp.unit_price,
        'line', tp.qty*coalesce(tpp.unit_price,0)))
        from ticket_parts tp
        left join parts pa on pa.id=tp.part_id
        left join ticket_part_prices tpp on tpp.ticket_part_id=tp.id
        where tp.ticket_id=p_ticket),'[]'::json),
    'services', coalesce((select json_agg(json_build_object('name', ts.name, 'price', ts.price))
        from ticket_services ts where ts.ticket_id=p_ticket),'[]'::json),
    'labour', coalesce((select labour from ticket_money where ticket_id=p_ticket),0),
    'final_price', (select final_price from ticket_money where ticket_id=p_ticket)
  ) into res;
  return res;
end; $function$
;
CREATE OR REPLACE FUNCTION public.get_loyalty(p_phone text)
 RETURNS TABLE(delivered_count integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select count(*)::int from store_orders
  where _norm_phone(phone) = _norm_phone(p_phone)
    and length(_norm_phone(p_phone)) = 10
    and status = 'delivered'
$function$
;
CREATE OR REPLACE FUNCTION public.get_mock()
 RETURNS SETOF neet_questions
 LANGUAGE sql
 STABLE
AS $function$
  (select * from public.neet_questions where subject='Physics'   order by random() limit 45)
  union all
  (select * from public.neet_questions where subject='Chemistry' order by random() limit 45)
  union all
  (select * from public.neet_questions where subject='Botany'    order by random() limit 45)
  union all
  (select * from public.neet_questions where subject='Zoology'   order by random() limit 45);
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_orders(p_phone text)
 RETURNS SETOF store_orders
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from store_orders
  where _norm_phone(phone) = _norm_phone(p_phone)
    and length(_norm_phone(p_phone)) = 10
    and created_at > now() - interval '90 days'
  order by created_at desc limit 20
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_repairs(p_phone text)
 RETURNS SETOF store_repairs
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from store_repairs
  where _norm_phone(phone) = _norm_phone(p_phone)
    and length(_norm_phone(p_phone)) = 10
    and created_at > now() - interval '90 days'
  order by created_at desc limit 20
$function$
;
CREATE OR REPLACE FUNCTION public.get_order_tracking(p_order_id uuid, p_phone text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o store_orders; l staff_live_location; nm text; dist_m double precision;
begin
  select * into o from store_orders
  where id = p_order_id and _norm_phone(phone) = _norm_phone(p_phone);
  if o.id is null then raise exception 'Order not found for this phone'; end if;
  if o.status <> 'out_for_delivery' or o.delivery_staff_id is null then
    return json_build_object('live', false, 'status', o.status, 'eta_at', o.eta_at);
  end if;
  select * into l from staff_live_location
  where staff_id = o.delivery_staff_id and updated_at > now() - interval '5 minutes';
  if l.staff_id is null then
    return json_build_object('live', false, 'status', o.status, 'eta_at', o.eta_at);
  end if;
  select name into nm from staff_members where id = o.delivery_staff_id;
  if o.dest_lat is not null then
    dist_m := 2 * 6371000 * asin(sqrt(
      power(sin(radians(o.dest_lat - l.lat)/2),2) +
      cos(radians(l.lat)) * cos(radians(o.dest_lat)) *
      power(sin(radians(o.dest_lng - l.lng)/2),2)));
  end if;
  return json_build_object('live', true, 'status', o.status, 'eta_at', o.eta_at,
    'staff_name', nm, 'ping_age_sec', floor(extract(epoch from (now() - l.updated_at))),
    'dist_m', round(dist_m));
  -- deliberately NOT returning raw staff coordinates to customers — distance only
end $function$
;
CREATE OR REPLACE FUNCTION public.get_practice(p_subject text DEFAULT NULL::text, p_chapter text DEFAULT NULL::text, p_difficulty text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS SETOF neet_questions
 LANGUAGE sql
 STABLE
AS $function$
  select * from public.neet_questions
  where (p_subject    is null or subject    = p_subject)
    and (p_chapter    is null or chapter    = p_chapter)
    and (p_difficulty is null or difficulty = p_difficulty)
  order by random()
  limit greatest(1, least(p_limit, 100)) offset greatest(0, p_offset);
$function$
;
CREATE OR REPLACE FUNCTION public.get_record(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pub jsonb; priv jsonb; sid uuid;
begin
  select data, shop_id into pub, sid from records where id = p_id;
  if pub is null then return null; end if;
  if not is_member_of(sid) then raise exception 'not a member of shop %', sid; end if;
  if is_owner_of(sid) then
    select data into priv from records_private where record_id = p_id;
    if priv is not null then pub := pub || priv; end if;
  end if;
  return pub;
end $function$
;
CREATE OR REPLACE FUNCTION public.get_repair_visit(p_repair_id uuid, p_phone text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r store_repairs; nm text;
begin
  select * into r from store_repairs
    where id = p_repair_id and _norm_phone(phone) = _norm_phone(p_phone);
  if r.id is null then raise exception 'Repair not found for this phone'; end if;
  if r.assigned_staff_id is null then return json_build_object('assigned', false); end if;
  select name into nm from staff_members where id = r.assigned_staff_id;
  return json_build_object('assigned', true, 'tech_name', nm,
    'visit_status', coalesce(r.visit_status,'assigned'), 'updated_at', r.visit_updated_at);
end $function$
;
CREATE OR REPLACE FUNCTION public.is_member_of(p_shop uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select exists(select 1 from memberships where shop_id=p_shop and user_id=auth.uid()) $function$
;
CREATE OR REPLACE FUNCTION public.is_owner()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from app_roles where user_id = auth.uid() and role = 'owner')
$function$
;
CREATE OR REPLACE FUNCTION public.is_owner_of(p_shop uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid() and m.shop_id = p_shop and m.role = 'owner'
  );
$function$
;
CREATE OR REPLACE FUNCTION public.is_staff()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select exists (select 1 from public.app_roles where user_id = auth.uid()); $function$
;
CREATE OR REPLACE FUNCTION public.list_shop_services_owner(p_shop uuid)
 RETURNS TABLE(id uuid, name text, description text, price numeric, cost numeric, margin numeric, estimated_minutes integer, category text, is_active boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_owner_of(p_shop) then raise exception 'owner only'; end if;
  return query
    select s.id, s.name, s.description, s.price, c.cost,
           (s.price - coalesce(c.cost,0)) as margin,
           s.estimated_minutes, s.category, s.is_active
    from shop_services s left join shop_service_costs c on c.service_id=s.id
    where s.shop_id=p_shop order by s.is_active desc, s.name;
end; $function$
;
CREATE OR REPLACE FUNCTION public.my_shop_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select shop_id from public.memberships where user_id = auth.uid();
$function$
;
CREATE OR REPLACE FUNCTION public.next_trade_code(p_type text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare y int := extract(year from now())::int; v int;
begin
  perform _require_owner();
  if p_type not in ('PO','SL') then raise exception 'Bad type'; end if;
  insert into trade_counters (doc_type, yr, n) values (p_type, y, 1)
  on conflict (doc_type, yr) do update set n = trade_counters.n + 1
  returning n into v;
  return p_type || '-' || y || '-' || lpad(v::text, 4, '0');
end $function$
;
CREATE OR REPLACE FUNCTION public.order_get_otp(p_order_id uuid, p_phone text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r store_orders;
begin
  select * into r from store_orders
    where id = p_order_id and _norm_phone(phone) = _norm_phone(p_phone);
  if r.id is null then raise exception 'Order not found for this phone'; end if;
  return r.handover_otp;   -- may be null if not dispatched yet
end $function$
;
CREATE OR REPLACE FUNCTION public.order_make_otp(p_order_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_otp text; r store_orders;
begin
  perform _require_owner_or_staff();   -- any signed-in shop user
  select * into r from store_orders where id = p_order_id;
  if r.id is null then raise exception 'Order not found'; end if;
  if r.handover_otp is null then
    v_otp := _gen_otp();
    update store_orders set handover_otp = v_otp where id = p_order_id;
  else
    v_otp := r.handover_otp;
  end if;
  return v_otp;
end $function$
;
CREATE OR REPLACE FUNCTION public.order_verify_otp(p_order_id uuid, p_otp text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r store_orders;
begin
  perform _require_owner_or_staff();
  select * into r from store_orders where id = p_order_id;
  if r.id is null then raise exception 'Order not found'; end if;
  if r.handover_otp is null then raise exception 'No code yet — order not dispatched'; end if;
  if p_otp is null or btrim(p_otp) <> r.handover_otp then raise exception 'Wrong code'; end if;
  update store_orders
    set handover_verified_at = now(),
        status = case when status <> 'delivered' then 'delivered' else status end
  where id = p_order_id;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.order_verify_otp_staff(p_code text, p_pin text, p_short text, p_otp text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; r store_orders;
begin
  v := _staff_auth(p_code, p_pin);
  select * into r from store_orders
    where right(replace(id::text,'-',''), 6) = lower(btrim(p_short))
    order by created_at desc limit 1;
  if r.id is null then raise exception 'Order not found for that ID'; end if;
  if r.handover_otp is null then raise exception 'No code yet — not dispatched'; end if;
  if p_otp is null or btrim(p_otp) <> r.handover_otp then raise exception 'Wrong code'; end if;
  update store_orders
    set handover_verified_at = now(),
        status = case when status <> 'delivered' then 'delivered' else status end
  where id = r.id;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_get_doc(p_phone text, p_pin text, p_code text)
 RETURNS trade_docs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members; d trade_docs;
begin
  v := _partner_auth(p_phone, p_pin);
  select * into d from trade_docs
  where code = upper(trim(p_code)) and partner_id = v.id and deleted_at is null;
  if d.id is null then raise exception 'Document not found for this partner'; end if;
  return d;
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_my_docs(p_phone text, p_pin text)
 RETURNS SETOF trade_docs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members;
begin
  v := _partner_auth(p_phone, p_pin);
  return query select * from trade_docs
  where partner_id = v.id and deleted_at is null
  order by created_at desc limit 100;
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_my_products(p_phone text, p_pin text)
 RETURNS TABLE(id bigint, name text, brand text, price integer, stock integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members;
begin
  v := _partner_auth(p_phone, p_pin);
  return query select sp.id, sp.name, sp.brand, sp.price, sp.stock
  from store_products sp where sp.partner_id = v.id order by sp.name;
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_my_submissions(p_phone text, p_pin text)
 RETURNS SETOF partner_submissions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members;
begin
  v := _partner_auth(p_phone, p_pin);
  return query select * from partner_submissions
  where partner_id = v.id and deleted_at is null
  order by created_at desc limit 100;
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_status(p_phone text, p_pin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members;
begin
  v := _partner_auth(p_phone, p_pin);
  return json_build_object('name', v.name, 'business', v.business_name, 'phone', v.phone);
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_submit(p_phone text, p_pin text, p_kind text, p_product_id bigint, p_name text, p_brand text, p_price integer, p_qty integer, p_image_url text, p_note text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members; v_id uuid;
begin
  v := _partner_auth(p_phone, p_pin);
  if p_kind not in ('new','price_change') then raise exception 'Bad kind'; end if;
  if p_kind = 'price_change' and (p_product_id is null
      or not exists (select 1 from store_products where id = p_product_id and partner_id = v.id)) then
    raise exception 'Price change allowed only on your own approved products';
  end if;
  if (select count(*) from partner_submissions
      where partner_id = v.id and created_at > now() - interval '1 day') >= 40 then
    raise exception 'Daily limit reached — try tomorrow or call the shop';
  end if;
  insert into partner_submissions (partner_id, kind, product_id, name, brand, price, qty, image_url, note)
  values (v.id, p_kind, p_product_id, left(p_name,120), left(coalesce(p_brand,''),60),
          p_price, greatest(coalesce(p_qty,0),0), left(coalesce(p_image_url,''),400), left(coalesce(p_note,''),300))
  returning id into v_id;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_submit_v2(p_phone text, p_pin text, p_kind text, p_product_id bigint, p_name text, p_brand text, p_price integer, p_qty integer, p_images text[], p_description text, p_note text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members; v_id uuid;
begin
  v := _partner_auth(p_phone, p_pin);
  if p_kind not in ('new','price_change') then raise exception 'Bad kind'; end if;
  if p_kind = 'price_change' and (p_product_id is null
      or not exists (select 1 from store_products where id = p_product_id and partner_id = v.id)) then
    raise exception 'Price change allowed only on your own approved products';
  end if;
  if (select count(*) from partner_submissions
      where partner_id = v.id and created_at > now() - interval '1 day') >= 40 then
    raise exception 'Daily limit reached — try tomorrow or call the shop';
  end if;
  if p_images is not null and array_length(p_images,1) > 5 then
    raise exception 'Maximum 5 photos';
  end if;
  insert into partner_submissions
    (partner_id, kind, product_id, name, brand, price, qty,
     image_url, images, description, note)
  values
    (v.id, p_kind, p_product_id, left(p_name,120), left(coalesce(p_brand,''),60),
     p_price, greatest(coalesce(p_qty,0),0),
     case when p_images is not null and array_length(p_images,1) >= 1 then p_images[1] else null end,
     p_images, left(coalesce(p_description,''),1000), left(coalesce(p_note,''),300))
  returning id into v_id;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.partner_withdraw_submission(p_phone text, p_pin text, p_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v partner_members; n int;
begin
  v := _partner_auth(p_phone, p_pin);
  update partner_submissions set deleted_at = now()
  where id = p_id and partner_id = v.id and status = 'pending' and deleted_at is null;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'Can only withdraw your own pending submissions'; end if;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.profix_notify_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare payload jsonb;
begin
  payload := jsonb_build_object('type', TG_OP, 'table', TG_TABLE_NAME, 'record', to_jsonb(NEW),
    'old_record', case when TG_OP='UPDATE' then to_jsonb(OLD) else null end);
  perform net.http_post(
    url := 'https://toxwbjofyglbyjanxmzv.supabase.co/functions/v1/push',
    headers := jsonb_build_object('Content-Type','application/json'),
    body := payload);
  return NEW;
end $function$
;
CREATE OR REPLACE FUNCTION public.public_ticket_status(p_id uuid)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select json_build_object(
    'ok', true,
    'ticket', substr(t.id::text, 1, 5),
    'status', t.status,
    'device', nullif(trim(coalesce(t.device_brand,'')||' '||coalesce(t.device_model,'')), ''),
    'complaint', t.complaint,
    'shop', s.name,
    'updated', coalesce(t.updated_at, t.date_in, t.created_at)
  )
  from repair_tickets t
  join shops s on s.id = t.shop_id
  where t.id = p_id;
$function$
;
CREATE OR REPLACE FUNCTION public.receive_trade_doc(p_doc_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d trade_docs; it jsonb; cnt int := 0;
begin
  perform _require_owner();
  perform set_config('app.skip_stock_log','1', true);
  select * into d from trade_docs where id = p_doc_id and deleted_at is null;
  if d.id is null then raise exception 'Doc not found'; end if;
  if d.doc_type <> 'PO' or d.status <> 'issued' then raise exception 'Only an issued PO can be received'; end if;
  for it in select * from jsonb_array_elements(d.items) loop
    if (it->>'product_id') is not null and coalesce((it->>'qty')::int,0) > 0 then
      update store_products set stock = coalesce(stock,0) + (it->>'qty')::int
      where id = (it->>'product_id')::bigint;
      insert into stock_moves (product_id, qty, reason, doc_id)
      values ((it->>'product_id')::bigint, (it->>'qty')::int, 'po_received', d.id);
      cnt := cnt + 1;
    end if;
  end loop;
  update trade_docs set status='received' where id = d.id;
  return cnt;
end $function$
;
CREATE OR REPLACE FUNCTION public.repair_get_otp(p_repair_id uuid, p_phone text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r store_repairs;
begin
  select * into r from store_repairs
    where id = p_repair_id and _norm_phone(phone) = _norm_phone(p_phone);
  if r.id is null then raise exception 'Repair not found for this phone'; end if;
  return r.handover_otp;
end $function$
;
CREATE OR REPLACE FUNCTION public.repair_make_otp(p_repair_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_otp text; r store_repairs;
begin
  perform _require_owner_or_staff();
  select * into r from store_repairs where id = p_repair_id;
  if r.id is null then raise exception 'Repair not found'; end if;
  if r.handover_otp is null then
    v_otp := _gen_otp();
    update store_repairs set handover_otp = v_otp where id = p_repair_id;
  else
    v_otp := r.handover_otp;
  end if;
  return v_otp;
end $function$
;
CREATE OR REPLACE FUNCTION public.repair_verify_otp(p_repair_id uuid, p_otp text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r store_repairs;
begin
  perform _require_owner_or_staff();
  select * into r from store_repairs where id = p_repair_id;
  if r.id is null then raise exception 'Repair not found'; end if;
  if r.handover_otp is null then raise exception 'No code yet'; end if;
  if p_otp is null or btrim(p_otp) <> r.handover_otp then raise exception 'Wrong code'; end if;
  update store_repairs
    set handover_verified_at = now(),
        status = case when status <> 'done' then 'done' else status end
  where id = p_repair_id;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.repair_verify_otp_staff(p_code text, p_pin text, p_repair_id uuid, p_otp text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; r store_repairs;
begin
  v := _staff_auth(p_code, p_pin);
  select * into r from store_repairs where id = p_repair_id;
  if r.id is null then raise exception 'Repair not found'; end if;
  -- only the assigned technician can verify their own visit
  if r.assigned_staff_id is not null and r.assigned_staff_id <> v.id then
    raise exception 'Not your visit';
  end if;
  if r.handover_otp is null then raise exception 'No pickup code yet'; end if;
  if p_otp is null or btrim(p_otp) <> r.handover_otp then raise exception 'Wrong code'; end if;
  update store_repairs
    set handover_verified_at = now(),
        status = case when status <> 'done' then 'done' else status end
  where id = r.id;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.report_order_issue(p_order_id uuid, p_phone text, p_type text, p_message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if not exists (select 1 from store_orders where id = p_order_id and _norm_phone(phone) = _norm_phone(p_phone)) then
    raise exception 'Order not found for this phone';
  end if;
  if exists (select 1 from store_order_issues where order_id = p_order_id and status = 'open') then
    raise exception 'An issue is already open for this order';
  end if;
  insert into store_order_issues (order_id, phone, issue_type, message)
  values (p_order_id, _norm_phone(p_phone), p_type, left(coalesce(p_message,''), 500))
  returning id into v_id;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.report_question(p_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.neet_questions set report_count = report_count + 1 where id = p_id;
$function$
;
CREATE OR REPLACE FUNCTION public.request_buyback(p_name text, p_phone text, p_brand text, p_model text, p_condition text, p_age_months integer, p_notes text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if length(_norm_phone(p_phone)) <> 10 then
    raise exception 'Enter a valid 10-digit phone';
  end if;
  if (select count(*) from store_buyback
      where _norm_phone(phone) = _norm_phone(p_phone)
        and created_at > now() - interval '1 day') >= 3 then
    raise exception 'Limit reached — the shop will call you about your earlier request';
  end if;
  insert into store_buyback (customer_name, phone, brand, model, condition, age_months, notes)
  values (left(p_name,80), _norm_phone(p_phone), left(p_brand,40), left(p_model,60),
          p_condition, p_age_months, left(coalesce(p_notes,''),300))
  returning id into v_id;
  return v_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.save_record(p_shop uuid, p_entity_key text, p_public jsonb, p_private jsonb DEFAULT '{}'::jsonb, p_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare rid uuid;
begin
  if not is_member_of(p_shop) then raise exception 'not a member of shop %', p_shop; end if;
  if p_id is null then
    insert into records(shop_id, entity_key, data)
      values (p_shop, p_entity_key, coalesce(p_public, '{}'::jsonb)) returning id into rid;
  else
    update records set data = coalesce(p_public, '{}'::jsonb), updated_at = now()
      where id = p_id and shop_id = p_shop returning id into rid;
    if rid is null then raise exception 'record % not found in shop %', p_id, p_shop; end if;
  end if;
  -- money wall: only owners may persist private data
  if p_private is not null and p_private <> '{}'::jsonb and is_owner_of(p_shop) then
    insert into records_private(record_id, shop_id, data) values (rid, p_shop, p_private)
      on conflict (record_id) do update set data = excluded.data;
  end if;
  return rid;
end $function$
;
CREATE OR REPLACE FUNCTION public.save_shop_gst(p_shop uuid, p_gst_enabled boolean, p_gst_rate numeric, p_gst_inclusive boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from public.memberships m
                 where m.shop_id = p_shop and m.user_id = auth.uid() and m.role = 'owner') then
    raise exception 'not authorised';
  end if;
  update public.shop_settings
     set gst_enabled = p_gst_enabled, gst_rate = p_gst_rate, gst_inclusive = p_gst_inclusive
   where shop_id = p_shop;
end $function$
;
CREATE OR REPLACE FUNCTION public.save_shop_settings(p_shop uuid, p_business_name text, p_address text, p_phone text, p_gstin text, p_logo_url text, p_invoice_prefix text, p_terms text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_owner_of(p_shop) then raise exception 'owner only'; end if;
  insert into shop_settings(shop_id,business_name,address,phone,gstin,logo_url,invoice_prefix,terms,updated_at)
  values(p_shop,p_business_name,p_address,p_phone,p_gstin,p_logo_url,
         coalesce(nullif(p_invoice_prefix,''),'INV-'),p_terms,now())
  on conflict (shop_id) do update set
    business_name=excluded.business_name, address=excluded.address, phone=excluded.phone,
    gstin=excluded.gstin, logo_url=excluded.logo_url, invoice_prefix=excluded.invoice_prefix,
    terms=excluded.terms, updated_at=now();
end; $function$
;
CREATE OR REPLACE FUNCTION public.set_shop_review_url(p_shop uuid, p_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from memberships
    where shop_id = p_shop and user_id = auth.uid() and role = 'owner'
  ) then
    raise exception 'not an owner of this shop';
  end if;
  update shops set review_url = nullif(p_url, '') where id = p_shop;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.shop_dashboard(p_shop uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare rev numeric; pval numeric; m_start timestamptz := date_trunc('month', now());
begin
  if not is_owner_of(p_shop) then
    return json_build_object('revenue',0,'parts_value',0,'month',to_char(m_start,'Mon YYYY'));
  end if;
  select coalesce(sum(coalesce(tm.final_price, rt.estimate, 0)),0) into rev
  from repair_tickets rt left join ticket_money tm on tm.ticket_id = rt.id
  where rt.shop_id = p_shop and rt.date_out >= m_start;
  select coalesce(sum(tp.qty * coalesce(tpp.unit_price,0)),0) into pval
  from ticket_parts tp
  join ticket_part_prices tpp on tpp.ticket_part_id = tp.id
  join repair_tickets rt on rt.id = tp.ticket_id
  where tp.shop_id = p_shop and rt.date_out >= m_start;
  return json_build_object('revenue',rev,'parts_value',pval,'month',to_char(m_start,'Mon YYYY'));
end; $function$
;
CREATE OR REPLACE FUNCTION public.shop_report(p_shop uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m0 timestamptz := date_trunc('month', now());
  m1 timestamptz := date_trunc('month', now()) - interval '1 month';
  tm_rev numeric; tm_tk int; tm_pv numeric;
  lm_rev numeric; lm_tk int; lm_pv numeric;
begin
  if not is_owner_of(p_shop) then return json_build_object('ok',false); end if;

  select coalesce(sum(coalesce(tm.final_price, rt.estimate, 0)),0), count(*)
    into tm_rev, tm_tk
    from repair_tickets rt left join ticket_money tm on tm.ticket_id = rt.id
    where rt.shop_id = p_shop and rt.date_out >= m0;
  select coalesce(sum(tp.qty * coalesce(tpp.unit_price,0)),0) into tm_pv
    from ticket_parts tp join ticket_part_prices tpp on tpp.ticket_part_id = tp.id
    join repair_tickets r on r.id = tp.ticket_id
    where tp.shop_id = p_shop and r.date_out >= m0;

  select coalesce(sum(coalesce(tm.final_price, rt.estimate, 0)),0), count(*)
    into lm_rev, lm_tk
    from repair_tickets rt left join ticket_money tm on tm.ticket_id = rt.id
    where rt.shop_id = p_shop and rt.date_out >= m1 and rt.date_out < m0;
  select coalesce(sum(tp.qty * coalesce(tpp.unit_price,0)),0) into lm_pv
    from ticket_parts tp join ticket_part_prices tpp on tpp.ticket_part_id = tp.id
    join repair_tickets r on r.id = tp.ticket_id
    where tp.shop_id = p_shop and r.date_out >= m1 and r.date_out < m0;

  return json_build_object(
    'ok', true,
    'this_month', json_build_object('revenue',tm_rev,'tickets',tm_tk,'parts_value',tm_pv),
    'last_month', json_build_object('revenue',lm_rev,'tickets',lm_tk,'parts_value',lm_pv),
    'top_services', coalesce((select json_agg(x) from (
        select ts.name as name, count(*) as uses, coalesce(sum(ts.price),0) as revenue
        from ticket_services ts where ts.shop_id = p_shop
        group by ts.name order by revenue desc nulls last limit 5) x),'[]'::json),
    'top_parts', coalesce((select json_agg(x) from (
        select pa.name as name, coalesce(sum(tp.qty),0) as qty,
               coalesce(sum(tp.qty*coalesce(tpp.unit_price,0)),0) as value
        from ticket_parts tp
        left join parts pa on pa.id = tp.part_id
        left join ticket_part_prices tpp on tpp.ticket_part_id = tp.id
        where tp.shop_id = p_shop group by pa.name order by qty desc nulls last limit 5) x),'[]'::json),
    'low_stock', coalesce((select json_agg(x) from (
        select name, stock_qty from parts
        where shop_id = p_shop and coalesce(stock_qty,0) <= 2 order by stock_qty limit 10) x),'[]'::json)
  );
end; $function$
;
CREATE OR REPLACE FUNCTION public.staff_add_daily_note(p_code text, p_pin text, p_note text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; vid uuid;
begin
  v := _staff_auth(p_code, p_pin);
  if coalesce(trim(p_note),'')='' then raise exception 'Write something'; end if;
  insert into staff_daily_notes (staff_id, note) values (v.id, left(p_note,600)) returning id into vid;
  return vid;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_apply_leave(p_code text, p_pin text, p_from date, p_to date, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; vid uuid;
begin
  v := _staff_auth(p_code, p_pin);
  if p_from is null or p_to is null or p_to < p_from then raise exception 'Pick valid dates'; end if;
  if (select count(*) from staff_leave where staff_id=v.id and status='pending') >= 5 then
    raise exception 'You already have several pending requests';
  end if;
  insert into staff_leave (staff_id, from_day, to_day, reason)
  values (v.id, p_from, p_to, left(coalesce(p_reason,''),300)) returning id into vid;
  return vid;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_clock_in(p_code text, p_pin text, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_device text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; existing uuid;
begin
  v := _staff_auth(p_code, p_pin);
  select id into existing from staff_attendance
  where staff_id = v.id and clock_out is null limit 1;
  if existing is not null then
    raise exception 'Already clocked in — clock out first';
  end if;
  insert into staff_attendance (staff_id, in_lat, in_lng, device)
  values (v.id, p_lat, p_lng, left(coalesce(p_device,''),120));
  return json_build_object('ok', true, 'name', v.name, 'at', now());
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_clock_in_shop(p_code text, p_pin text, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_device text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; today date := (now() at time zone 'Asia/Kolkata')::date; sid int;
begin
  v := _staff_auth(p_code, p_pin);
  if exists (select 1 from staff_attendance where staff_id=v.id and clock_out is null) then
    raise exception 'Already clocked in — clock out first';
  end if;
  select shop_id into sid from staff_roster where staff_id=v.id and day=today;
  sid := coalesce(sid, v.home_shop_id, 1);
  insert into staff_attendance (staff_id, in_lat, in_lng, device, shop_id)
  values (v.id, p_lat, p_lng, left(coalesce(p_device,''),120), sid);
  return json_build_object('ok',true,'shop_id',sid);
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_clock_out(p_code text, p_pin text, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; att staff_attendance;
begin
  v := _staff_auth(p_code, p_pin);
  select * into att from staff_attendance
    where staff_id=v.id and clock_out is null order by clock_in desc limit 1;
  if att.id is null then raise exception 'Not clocked in'; end if;
  update staff_attendance
    set clock_out=now(), out_lat=p_lat, out_lng=p_lng
    where id=att.id;
  return json_build_object('ok',true);
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_home(p_code text, p_pin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; today date := (now() at time zone 'Asia/Kolkata')::date;
        shop_row profix_shops; open_in timestamptz; today_secs numeric;
        pend_leave int; open_todos int;
begin
  v := _staff_auth(p_code, p_pin);
  -- today's rostered shop (fallback to home shop)
  select s.* into shop_row from staff_roster r join profix_shops s on s.id=r.shop_id
    where r.staff_id=v.id and r.day=today;
  if shop_row.id is null then
    select * into shop_row from profix_shops where id = coalesce(v.home_shop_id,1);
  end if;
  select clock_in into open_in from staff_attendance
    where staff_id=v.id and clock_out is null order by clock_in desc limit 1;
  select coalesce(sum(extract(epoch from (coalesce(clock_out,now())-clock_in))),0) into today_secs
    from staff_attendance where staff_id=v.id
      and clock_in >= date_trunc('day', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata';
  select count(*) into pend_leave from staff_leave where staff_id=v.id and status='pending';
  select count(*) into open_todos from staff_todos where staff_id=v.id and done=false;
  return json_build_object(
    'name',v.name,'code',v.code,'role',v.role,
    'shop_id',shop_row.id,'shop_name',shop_row.name,'shop_location',shop_row.location,
    'open_in',open_in,'today_seconds',floor(today_secs),
    'pending_leave',pend_leave,'open_todos',open_todos);
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_month(p_code text, p_pin text, p_year integer, p_month integer)
 RETURNS SETOF staff_attendance
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  v := _staff_auth(p_code, p_pin);
  return query select * from staff_attendance
  where staff_id = v.id
    and clock_in >= make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'Asia/Kolkata')
    and clock_in <  make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'Asia/Kolkata') + interval '1 month'
  order by clock_in desc;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_my_daily_notes(p_code text, p_pin text)
 RETURNS SETOF staff_daily_notes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  v := _staff_auth(p_code, p_pin);
  return query select * from staff_daily_notes where staff_id=v.id order by created_at desc limit 60;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_my_incentives(p_code text, p_pin text)
 RETURNS SETOF staff_incentives
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  v := _staff_auth(p_code, p_pin);
  return query select * from staff_incentives
  where staff_id = v.id
  order by created_at desc limit 50;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_my_leave(p_code text, p_pin text)
 RETURNS SETOF staff_leave
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  v := _staff_auth(p_code, p_pin);
  return query select * from staff_leave where staff_id=v.id order by created_at desc limit 50;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_my_todos(p_code text, p_pin text)
 RETURNS SETOF staff_todos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  v := _staff_auth(p_code, p_pin);
  return query select * from staff_todos where staff_id=v.id order by done, created_at desc limit 100;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_my_visits(p_code text, p_pin text)
 RETURNS SETOF store_repairs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  v := _staff_auth(p_code, p_pin);
  return query select * from store_repairs
    where assigned_staff_id = v.id
      and coalesce(visit_status,'assigned') <> 'collected'
    order by created_at desc limit 30;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_ping_location(p_code text, p_pin text, p_lat double precision, p_lng double precision)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members;
begin
  v := _staff_auth(p_code, p_pin);
  if p_lat is null or p_lng is null then raise exception 'No position'; end if;
  insert into staff_live_location (staff_id, lat, lng, updated_at)
  values (v.id, p_lat, p_lng, now())
  on conflict (staff_id) do update set lat=excluded.lat, lng=excluded.lng, updated_at=now();
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_status(p_code text, p_pin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; s staff_attendance; today_secs numeric;
begin
  v := _staff_auth(p_code, p_pin);
  select * into s from staff_attendance
  where staff_id = v.id and clock_out is null
  order by clock_in desc limit 1;
  select coalesce(sum(extract(epoch from (coalesce(clock_out, now()) - clock_in))),0)
    into today_secs
  from staff_attendance
  where staff_id = v.id
    and clock_in >= date_trunc('day', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata';
  return json_build_object(
    'name', v.name, 'role', v.role, 'code', v.code,
    'open_in', s.clock_in, 'today_seconds', floor(today_secs));
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_toggle_todo(p_code text, p_pin text, p_id uuid, p_done boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; n int;
begin
  v := _staff_auth(p_code, p_pin);
  update staff_todos set done=p_done, done_at=case when p_done then now() else null end
    where id=p_id and staff_id=v.id;
  get diagnostics n = row_count;
  if n=0 then raise exception 'Not your task'; end if;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.staff_update_visit(p_code text, p_pin text, p_repair_id uuid, p_status text, p_amount integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v staff_members; r store_repairs;
  ord text[] := array['assigned','on_the_way','reached','repaired','collected'];
begin
  v := _staff_auth(p_code, p_pin);
  select * into r from store_repairs where id = p_repair_id and assigned_staff_id = v.id;
  if r.id is null then raise exception 'Not your visit'; end if;
  if not (p_status = any(ord)) then raise exception 'Bad status'; end if;
  if array_position(ord, p_status) < array_position(ord, coalesce(r.visit_status,'assigned')) then
    raise exception 'Cannot go backwards';
  end if;
  update store_repairs set
    visit_status = p_status,
    visit_updated_at = now(),
    amount_collected = case when p_status='collected' then coalesce(p_amount, amount_collected) else amount_collected end,
    status = case when p_status='collected' then 'done' else status end
  where id = r.id;
  return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.track_orders(oids uuid[])
 RETURNS TABLE(id uuid, status text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, status from store_orders where id = any(oids);
$function$
;
CREATE OR REPLACE FUNCTION public.track_refunds(oids uuid[])
 RETURNS TABLE(order_id uuid, status text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select order_id, status from store_refunds where order_id = any(oids); $function$
;
CREATE OR REPLACE FUNCTION public.update_shop_service(p_id uuid, p_name text, p_price numeric, p_cost numeric DEFAULT NULL::numeric, p_desc text DEFAULT NULL::text, p_minutes integer DEFAULT NULL::integer, p_category text DEFAULT NULL::text, p_active boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s uuid;
begin
  select shop_id into s from shop_services where id=p_id;
  if s is null or not is_owner_of(s) then raise exception 'owner only'; end if;
  update shop_services set name=p_name, price=coalesce(p_price,0), description=p_desc,
    estimated_minutes=p_minutes, category=p_category, is_active=coalesce(p_active,true) where id=p_id;
  insert into shop_service_costs(service_id,shop_id,cost) values(p_id,s,p_cost)
    on conflict (service_id) do update set cost=excluded.cost;
end; $function$
;

-- ============================================================
-- TRIGGERS (10)
-- ============================================================
CREATE TRIGGER forge_apps_touch BEFORE UPDATE ON public.forge_apps FOR EACH ROW EXECUTE FUNCTION forge_touch();
CREATE TRIGGER forge_records_activity AFTER INSERT OR DELETE OR UPDATE ON public.forge_records FOR EACH ROW EXECUTE FUNCTION forge_log_activity();
CREATE TRIGGER forge_records_limit BEFORE INSERT ON public.forge_records FOR EACH ROW EXECUTE FUNCTION forge_check_record_limit();
CREATE TRIGGER forge_records_touch BEFORE UPDATE ON public.forge_records FOR EACH ROW EXECUTE FUNCTION forge_touch();
CREATE TRIGGER forge_records_webhook AFTER INSERT ON public.forge_records FOR EACH ROW EXECUTE FUNCTION forge_webhook_fire();
CREATE TRIGGER trg_driver_force_pending BEFORE INSERT ON public.profix_drivers FOR EACH ROW EXECUTE FUNCTION _driver_force_pending();
CREATE TRIGGER profix_push_insert AFTER INSERT ON public.store_orders FOR EACH ROW EXECUTE FUNCTION profix_notify_push();
CREATE TRIGGER profix_push_update AFTER UPDATE ON public.store_orders FOR EACH ROW EXECUTE FUNCTION profix_notify_push();
CREATE TRIGGER trg_order_stock AFTER UPDATE OF status ON public.store_orders FOR EACH ROW EXECUTE FUNCTION _order_stock_sync();
CREATE TRIGGER trg_product_stock_log AFTER UPDATE OF stock ON public.store_products FOR EACH ROW EXECUTE FUNCTION _product_stock_log();

-- ============================================================
-- ROW LEVEL SECURITY (94)
-- ============================================================
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_handovers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demo_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demo_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demo_shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_partner_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eng_tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_records_private ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forge_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kv ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.neet_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parts_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profix_drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profix_shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.records_private ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repair_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_private ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_service_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_daily_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_incentives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_leave ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_live_location ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_roster ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_moves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_buyback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_cash ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_daycloses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_order_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_repairs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_signups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_money ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_part_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_service_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_docs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_money ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- POLICIES (168)
-- ============================================================
CREATE POLICY al_insert ON public.activity_log AS PERMISSIVE FOR INSERT TO public WITH CHECK (((actor = auth.uid()) AND (EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = activity_log.shop_id) AND (m.user_id = auth.uid()))))));
CREATE POLICY al_select ON public.activity_log AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = activity_log.shop_id) AND (m.user_id = auth.uid())))));
CREATE POLICY "read own role" ON public.app_roles AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = auth.uid()));
CREATE POLICY bi_owner_all ON public.bill_items AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = bill_items.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = bill_items.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY bills_owner_delete ON public.bills AS PERMISSIVE FOR DELETE TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = bills.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY bills_owner_insert ON public.bills AS PERMISSIVE FOR INSERT TO public WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = bills.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY bills_owner_select ON public.bills AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = bills.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY bills_owner_update ON public.bills AS PERMISSIVE FOR UPDATE TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = bills.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY cm_owner_all ON public.cash_movements AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = cash_movements.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = cash_movements.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY "auth crm handovers" ON public.crm_handovers AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "invitee reads own invite" ON public.crm_invites AS PERMISSIVE FOR SELECT TO public USING ((lower(email) = lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text))));
CREATE POLICY "owner manages invites" ON public.crm_invites AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = crm_invites.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = crm_invites.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY customers_delete_owner ON public.customers AS PERMISSIVE FOR DELETE TO public USING (is_owner_of(shop_id));
CREATE POLICY customers_insert ON public.customers AS PERMISSIVE FOR INSERT TO public WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY customers_select ON public.customers AS PERMISSIVE FOR SELECT TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY customers_update ON public.customers AS PERMISSIVE FOR UPDATE TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids)))) WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY "read catalog" ON public.demo_catalog AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY "insert orders" ON public.demo_orders AS PERMISSIVE FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "read orders" ON public.demo_orders AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY "update orders" ON public.demo_orders AS PERMISSIVE FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "read shops" ON public.demo_shops AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY djob_owner_all ON public.driver_jobs AS PERMISSIVE FOR ALL TO public USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY dpay_owner_all ON public.driver_payouts AS PERMISSIVE FOR ALL TO public USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY eng_act_ins ON public.eng_activity AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (eng_can_edit_shop(shop_id));
CREATE POLICY eng_act_read ON public.eng_activity AS PERMISSIVE FOR SELECT TO authenticated USING (eng_can_see_shop(shop_id));
CREATE POLICY eng_inv_owner ON public.eng_inventory AS PERMISSIVE FOR ALL TO authenticated USING (eng_is_owner(shop_id)) WITH CHECK (eng_is_owner(shop_id));
CREATE POLICY eng_inv_read ON public.eng_invites AS PERMISSIVE FOR SELECT TO authenticated USING (eng_is_staffer());
CREATE POLICY eng_mem_read_own ON public.eng_memberships AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = auth.uid()));
CREATE POLICY eng_op_read_own ON public.eng_operators AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = auth.uid()));
CREATE POLICY eng_pc_read_own ON public.eng_partner_clients AS PERMISSIVE FOR SELECT TO authenticated USING (((partner_user_id = auth.uid()) OR eng_is_operator()));
CREATE POLICY eng_pat_read ON public.eng_patterns AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY eng_pat_write ON public.eng_patterns AS PERMISSIVE FOR ALL TO authenticated USING (eng_is_operator()) WITH CHECK (eng_is_operator());
CREATE POLICY eng_shops_read ON public.eng_shops AS PERMISSIVE FOR SELECT TO authenticated USING (eng_can_see_shop(id));
CREATE POLICY eng_shops_upd ON public.eng_shops AS PERMISSIVE FOR UPDATE TO authenticated USING ((eng_is_owner(id) OR eng_is_operator()));
CREATE POLICY eng_tenants_pub ON public.eng_tenants AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY eng_tenants_write ON public.eng_tenants AS PERMISSIVE FOR ALL TO authenticated USING ((eng_is_operator() OR ((shop_id IS NOT NULL) AND eng_is_owner(shop_id)))) WITH CHECK ((eng_is_operator() OR ((shop_id IS NOT NULL) AND eng_is_owner(shop_id))));
CREATE POLICY entities_owner ON public.entities AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY entities_read ON public.entities AS PERMISSIVE FOR SELECT TO public USING (is_member_of(shop_id));
CREATE POLICY fields_owner ON public.fields AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY fields_read ON public.fields AS PERMISSIVE FOR SELECT TO public USING ((is_member_of(shop_id) AND ((NOT is_private) OR is_owner_of(shop_id))));
CREATE POLICY forge_activity_select ON public.forge_activity AS PERMISSIVE FOR SELECT TO public USING (forge_is_member(app_id));
CREATE POLICY forge_apps_delete ON public.forge_apps AS PERMISSIVE FOR DELETE TO public USING (forge_is_owner(id));
CREATE POLICY forge_apps_select ON public.forge_apps AS PERMISSIVE FOR SELECT TO public USING (forge_is_member(id));
CREATE POLICY forge_apps_update ON public.forge_apps AS PERMISSIVE FOR UPDATE TO public USING (forge_is_owner(id));
CREATE POLICY forge_entities_select ON public.forge_entities AS PERMISSIVE FOR SELECT TO public USING (forge_is_member(app_id));
CREATE POLICY forge_entities_write ON public.forge_entities AS PERMISSIVE FOR ALL TO public USING (forge_is_owner(app_id)) WITH CHECK (forge_is_owner(app_id));
CREATE POLICY forge_fields_select ON public.forge_fields AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM forge_entities e
  WHERE ((e.id = forge_fields.entity_id) AND forge_is_member(e.app_id)))));
CREATE POLICY forge_fields_write ON public.forge_fields AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM forge_entities e
  WHERE ((e.id = forge_fields.entity_id) AND forge_is_owner(e.app_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM forge_entities e
  WHERE ((e.id = forge_fields.entity_id) AND forge_is_owner(e.app_id)))));
CREATE POLICY forge_invites_owner ON public.forge_invites AS PERMISSIVE FOR ALL TO public USING (forge_is_owner(app_id)) WITH CHECK (forge_is_owner(app_id));
CREATE POLICY forge_leads_insert ON public.forge_leads AS PERMISSIVE FOR INSERT TO public WITH CHECK (true);
CREATE POLICY forge_members_select ON public.forge_members AS PERMISSIVE FOR SELECT TO public USING (forge_is_member(app_id));
CREATE POLICY forge_members_write ON public.forge_members AS PERMISSIVE FOR ALL TO public USING (forge_is_owner(app_id)) WITH CHECK (forge_is_owner(app_id));
CREATE POLICY forge_plans_self ON public.forge_plans AS PERMISSIVE FOR SELECT TO public USING ((user_id = auth.uid()));
CREATE POLICY forge_records_select ON public.forge_records AS PERMISSIVE FOR SELECT TO public USING (forge_is_member(app_id));
CREATE POLICY forge_records_write ON public.forge_records AS PERMISSIVE FOR ALL TO public USING (forge_is_member(app_id)) WITH CHECK (forge_is_member(app_id));
CREATE POLICY forge_records_private_owner ON public.forge_records_private AS PERMISSIVE FOR ALL TO public USING (forge_is_owner(app_id)) WITH CHECK (forge_is_owner(app_id));
CREATE POLICY forge_templates_own ON public.forge_templates AS PERMISSIVE FOR ALL TO public USING ((created_by = auth.uid())) WITH CHECK ((created_by = auth.uid()));
CREATE POLICY inv_member_read ON public.inventory AS PERMISSIVE FOR SELECT TO public USING ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid()))));
CREATE POLICY inv_member_write ON public.inventory AS PERMISSIVE FOR ALL TO public USING ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid())))) WITH CHECK ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid()))));
CREATE POLICY inventory_owner_all ON public.inventory AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY kv_delete_own ON public.kv AS PERMISSIVE FOR DELETE TO public USING ((auth.uid() = user_id));
CREATE POLICY kv_insert_own ON public.kv AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = user_id));
CREATE POLICY kv_select_own ON public.kv AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() = user_id));
CREATE POLICY kv_update_own ON public.kv AS PERMISSIVE FOR UPDATE TO public USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY memberships_manage_owner ON public.memberships AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY memberships_select ON public.memberships AS PERMISSIVE FOR SELECT TO public USING (((user_id = auth.uid()) OR is_owner_of(shop_id)));
CREATE POLICY neet_read ON public.neet_questions AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY "owner all partner_members" ON public.partner_members AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all partner_submissions" ON public.partner_submissions AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY parts_delete_owner ON public.parts AS PERMISSIVE FOR DELETE TO public USING (is_owner_of(shop_id));
CREATE POLICY parts_insert ON public.parts AS PERMISSIVE FOR INSERT TO public WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY parts_select ON public.parts AS PERMISSIVE FOR SELECT TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY parts_update ON public.parts AS PERMISSIVE FOR UPDATE TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids)))) WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY pp_owner ON public.parts_pricing AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY pp_owner_all ON public.parts_pricing AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = parts_pricing.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = parts_pricing.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY drv_anon_register ON public.profix_drivers AS PERMISSIVE FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY drv_owner_all ON public.profix_drivers AS PERMISSIVE FOR ALL TO public USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner write shops" ON public.profix_shops AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "read shops" ON public.profix_shops AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "push anon insert" ON public.push_subscriptions AS PERMISSIVE FOR INSERT TO anon WITH CHECK ((role = 'customer'::text));
CREATE POLICY "push anon update" ON public.push_subscriptions AS PERMISSIVE FOR UPDATE TO anon USING ((role = 'customer'::text)) WITH CHECK ((role = 'customer'::text));
CREATE POLICY "push staff all" ON public.push_subscriptions AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY records_read ON public.records AS PERMISSIVE FOR SELECT TO public USING (is_member_of(shop_id));
CREATE POLICY records_write ON public.records AS PERMISSIVE FOR ALL TO public USING (is_member_of(shop_id)) WITH CHECK (is_member_of(shop_id));
CREATE POLICY records_private_owner ON public.records_private AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY reg_op ON public.registry AS PERMISSIVE FOR ALL TO authenticated USING ((eng_is_staffer() OR ((shop_id IS NOT NULL) AND eng_is_owner(shop_id)))) WITH CHECK ((eng_is_staffer() OR ((shop_id IS NOT NULL) AND eng_is_owner(shop_id))));
CREATE POLICY tickets_delete_owner ON public.repair_tickets AS PERMISSIVE FOR DELETE TO public USING (is_owner_of(shop_id));
CREATE POLICY tickets_insert ON public.repair_tickets AS PERMISSIVE FOR INSERT TO public WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY tickets_select ON public.repair_tickets AS PERMISSIVE FOR SELECT TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY tickets_update ON public.repair_tickets AS PERMISSIVE FOR UPDATE TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids)))) WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY sales_member ON public.sales AS PERMISSIVE FOR ALL TO public USING ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid())))) WITH CHECK ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid()))));
CREATE POLICY sp_owner_all ON public.sales_private AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = sales_private.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = sales_private.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY groups_member ON public.shop_groups AS PERMISSIVE FOR SELECT TO public USING ((id IN ( SELECT shops.group_id
   FROM shops
  WHERE (shops.id IN ( SELECT my_shop_ids() AS my_shop_ids)))));
CREATE POLICY svccost_owner ON public.shop_service_costs AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY svc_owner_del ON public.shop_services AS PERMISSIVE FOR DELETE TO public USING (is_owner_of(shop_id));
CREATE POLICY svc_owner_ins ON public.shop_services AS PERMISSIVE FOR INSERT TO public WITH CHECK (is_owner_of(shop_id));
CREATE POLICY svc_owner_upd ON public.shop_services AS PERMISSIVE FOR UPDATE TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY svc_read ON public.shop_services AS PERMISSIVE FOR SELECT TO public USING ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid()))));
CREATE POLICY settings_owner ON public.shop_settings AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY shops_select ON public.shops AS PERMISSIVE FOR SELECT TO public USING ((is_owner_of(id) OR (id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY shops_write_owner ON public.shops AS PERMISSIVE FOR ALL TO public USING (is_owner_of(id)) WITH CHECK (is_owner_of(id));
CREATE POLICY "owner advances" ON public.staff_advances AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all staff_attendance" ON public.staff_attendance AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner daily notes" ON public.staff_daily_notes AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all staff_incentives" ON public.staff_incentives AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner leave" ON public.staff_leave AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all staff_live_location" ON public.staff_live_location AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all staff_members" ON public.staff_members AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner roster" ON public.staff_roster AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all staff_settings" ON public.staff_settings AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner todos" ON public.staff_todos AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all stock_moves" ON public.stock_moves AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "staff all buyback" ON public.store_buyback AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "cash staff all" ON public.store_cash AS PERMISSIVE FOR ALL TO authenticated USING (is_staff()) WITH CHECK (is_staff());
CREATE POLICY "categories public read" ON public.store_categories AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY "categories staff all" ON public.store_categories AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "read store_categories" ON public.store_categories AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY "read active coupons" ON public.store_coupons AS PERMISSIVE FOR SELECT TO public USING ((active = true));
CREATE POLICY "staff all daycloses" ON public.store_daycloses AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "staff read issues" ON public.store_order_issues AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff update issues" ON public.store_order_issues AS PERMISSIVE FOR UPDATE TO authenticated USING (true);
CREATE POLICY "create order" ON public.store_orders AS PERMISSIVE FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "orders public insert" ON public.store_orders AS PERMISSIVE FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "orders staff all" ON public.store_orders AS PERMISSIVE FOR ALL TO authenticated USING (is_staff()) WITH CHECK (is_staff());
CREATE POLICY "staff read store_orders" ON public.store_orders AS PERMISSIVE FOR SELECT TO authenticated USING (is_staff());
CREATE POLICY "owner delete products" ON public.store_products AS PERMISSIVE FOR DELETE TO authenticated USING (true);
CREATE POLICY "owner insert products" ON public.store_products AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "owner or staff manage" ON public.store_products AS PERMISSIVE FOR ALL TO authenticated USING (((owner_id = auth.uid()) OR is_staff())) WITH CHECK (((owner_id = auth.uid()) OR is_staff()));
CREATE POLICY "public read published" ON public.store_products AS PERMISSIVE FOR SELECT TO public USING ((published = true));
CREATE POLICY "read store_products" ON public.store_products AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY "store_products auth update" ON public.store_products AS PERMISSIVE FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon insert refunds" ON public.store_refunds AS PERMISSIVE FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "refunds staff all" ON public.store_refunds AS PERMISSIVE FOR ALL TO authenticated USING (is_staff()) WITH CHECK (is_staff());
CREATE POLICY "create booking" ON public.store_repairs AS PERMISSIVE FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "partner reads assigned repairs" ON public.store_repairs AS PERMISSIVE FOR SELECT TO authenticated USING ((assigned_partner = auth.uid()));
CREATE POLICY "partner updates assigned repairs" ON public.store_repairs AS PERMISSIVE FOR UPDATE TO authenticated USING ((assigned_partner = auth.uid())) WITH CHECK ((assigned_partner = auth.uid()));
CREATE POLICY "repairs public insert" ON public.store_repairs AS PERMISSIVE FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "repairs staff all" ON public.store_repairs AS PERMISSIVE FOR ALL TO authenticated USING (is_staff()) WITH CHECK (is_staff());
CREATE POLICY "staff read store_repairs" ON public.store_repairs AS PERMISSIVE FOR SELECT TO authenticated USING (is_staff());
CREATE POLICY "reviews public insert" ON public.store_reviews AS PERMISSIVE FOR INSERT TO anon WITH CHECK ((((rating >= 1) AND (rating <= 5)) AND (char_length(COALESCE(comment, ''::text)) <= 240)));
CREATE POLICY "reviews public read" ON public.store_reviews AS PERMISSIVE FOR SELECT TO public USING (true);
CREATE POLICY "reviews staff all" ON public.store_reviews AS PERMISSIVE FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "read own role" ON public.store_roles AS PERMISSIVE FOR SELECT TO authenticated USING ((auth.uid() = user_id));
CREATE POLICY "staff reads roles" ON public.store_roles AS PERMISSIVE FOR SELECT TO authenticated USING (is_staff());
CREATE POLICY "sales staff all" ON public.store_sales AS PERMISSIVE FOR ALL TO authenticated USING (is_staff()) WITH CHECK (is_staff());
CREATE POLICY "anon insert services" ON public.store_services AS PERMISSIVE FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "services staff all" ON public.store_services AS PERMISSIVE FOR ALL TO authenticated USING (is_staff()) WITH CHECK (is_staff());
CREATE POLICY "anyone reads settings" ON public.store_settings AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "owner updates settings" ON public.store_settings AS PERMISSIVE FOR UPDATE TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "anon insert signups" ON public.store_signups AS PERMISSIVE FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "signups public insert" ON public.store_signups AS PERMISSIVE FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "signups staff all" ON public.store_signups AS PERMISSIVE FOR ALL TO authenticated USING (is_staff()) WITH CHECK (is_staff());
CREATE POLICY tm_owner_all ON public.ticket_money AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = ticket_money.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.shop_id = ticket_money.shop_id) AND (m.user_id = auth.uid()) AND (m.role = 'owner'::shop_role)))));
CREATE POLICY tpp_owner ON public.ticket_part_prices AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY ticket_parts_delete_owner ON public.ticket_parts AS PERMISSIVE FOR DELETE TO public USING (is_owner_of(shop_id));
CREATE POLICY ticket_parts_insert ON public.ticket_parts AS PERMISSIVE FOR INSERT TO public WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY ticket_parts_select ON public.ticket_parts AS PERMISSIVE FOR SELECT TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY ticket_parts_update ON public.ticket_parts AS PERMISSIVE FOR UPDATE TO public USING ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids)))) WITH CHECK ((is_owner_of(shop_id) OR (shop_id IN ( SELECT my_shop_ids() AS my_shop_ids))));
CREATE POLICY tsvccost_owner ON public.ticket_service_costs AS PERMISSIVE FOR ALL TO public USING (is_owner_of(shop_id)) WITH CHECK (is_owner_of(shop_id));
CREATE POLICY tsvc_del ON public.ticket_services AS PERMISSIVE FOR DELETE TO public USING ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid()))));
CREATE POLICY tsvc_read ON public.ticket_services AS PERMISSIVE FOR SELECT TO public USING ((shop_id IN ( SELECT memberships.shop_id
   FROM memberships
  WHERE (memberships.user_id = auth.uid()))));
CREATE POLICY "owner all trade_counters" ON public.trade_counters AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY "owner all trade_docs" ON public.trade_docs AS PERMISSIVE FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner());
CREATE POLICY wi_del ON public.work_items AS PERMISSIVE FOR DELETE TO authenticated USING (eng_can_edit_shop(shop_id));
CREATE POLICY wi_ins ON public.work_items AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (eng_can_edit_shop(shop_id));
CREATE POLICY wi_read ON public.work_items AS PERMISSIVE FOR SELECT TO authenticated USING (eng_can_see_shop(shop_id));
CREATE POLICY wi_upd ON public.work_items AS PERMISSIVE FOR UPDATE TO authenticated USING (eng_can_edit_shop(shop_id)) WITH CHECK (eng_can_edit_shop(shop_id));
CREATE POLICY wm_owner ON public.work_money AS PERMISSIVE FOR ALL TO authenticated USING (eng_is_owner(shop_id)) WITH CHECK (eng_is_owner(shop_id));

-- ============================================================
-- GRANTS (285)
-- ============================================================
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.activity_log TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.activity_log TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.activity_log TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.app_roles TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.app_roles TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.app_roles TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.bill_items TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.bill_items TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.bill_items TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.bills TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.bills TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.bills TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.cash_movements TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.cash_movements TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.cash_movements TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.crm_handovers TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.crm_handovers TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.crm_handovers TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.crm_invites TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.crm_invites TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.crm_invites TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.customers TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.customers TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.customers TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_catalog TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_catalog TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_catalog TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_orders TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_orders TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_orders TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_shops TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_shops TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.demo_shops TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.driver_jobs TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.driver_jobs TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.driver_jobs TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.driver_payouts TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.driver_payouts TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.driver_payouts TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_activity TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_activity TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_activity TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_inventory TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_inventory TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_inventory TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_invites TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_invites TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_invites TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_memberships TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_memberships TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_memberships TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_operators TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_operators TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_operators TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_partner_clients TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_partner_clients TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_partner_clients TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_patterns TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_patterns TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_patterns TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_shops TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_shops TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_shops TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_tenants TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_tenants TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.eng_tenants TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.entities TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.entities TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.entities TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.fields TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.fields TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.fields TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_activity TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_activity TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_activity TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_apps TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_apps TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_apps TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_entities TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_entities TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_entities TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_fields TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_fields TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_fields TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_invites TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_invites TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_invites TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_leads TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_leads TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_leads TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_members TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_members TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_members TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_plans TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_plans TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_plans TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_records TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_records TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_records TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_records_private TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_records_private TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_records_private TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_templates TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_templates TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.forge_templates TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.inventory TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.inventory TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.inventory TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.kv TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.kv TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.kv TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.memberships TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.memberships TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.memberships TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.neet_flagged TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.neet_flagged TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.neet_flagged TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.neet_questions TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.neet_questions TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.neet_questions TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.partner_members TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.partner_members TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.partner_members TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.partner_submissions TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.partner_submissions TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.partner_submissions TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.parts TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.parts TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.parts TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.parts_pricing TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.parts_pricing TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.parts_pricing TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.platform_admins TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.platform_admins TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.platform_admins TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.profix_drivers TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.profix_drivers TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.profix_drivers TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.profix_shops TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.profix_shops TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.profix_shops TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.push_subscriptions TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.push_subscriptions TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.push_subscriptions TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.records TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.records TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.records TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.records_private TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.records_private TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.records_private TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.registry TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.registry TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.registry TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.repair_tickets TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.repair_tickets TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.repair_tickets TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.sales TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.sales TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.sales TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.sales_private TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.sales_private TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.sales_private TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_groups TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_groups TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_groups TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_service_costs TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_service_costs TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_service_costs TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_services TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_services TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_services TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_settings TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_settings TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shop_settings TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shops TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shops TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.shops TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_advances TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_advances TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_advances TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_attendance TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_attendance TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_attendance TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_daily_notes TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_daily_notes TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_daily_notes TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_incentives TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_incentives TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_incentives TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_leave TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_leave TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_leave TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_live_location TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_live_location TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_live_location TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_members TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_members TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_members TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_roster TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_roster TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_roster TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_settings TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_settings TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_settings TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_todos TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_todos TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.staff_todos TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.stock_moves TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.stock_moves TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.stock_moves TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_buyback TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_buyback TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_buyback TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_cash TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_cash TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_cash TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_categories TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_categories TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_categories TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_coupons TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_coupons TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_coupons TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_daycloses TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_daycloses TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_daycloses TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_order_issues TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_order_issues TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_order_issues TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_orders TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_orders TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_orders TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_products TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_products TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_products TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_refunds TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_refunds TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_refunds TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_repairs TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_repairs TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_repairs TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_reviews TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_reviews TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_reviews TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_roles TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_roles TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_roles TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_sales TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_sales TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_sales TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_services TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_services TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_services TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_settings TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_settings TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_settings TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_signups TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_signups TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.store_signups TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_money TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_money TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_money TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_part_prices TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_part_prices TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_part_prices TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_parts TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_parts TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_parts TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_service_costs TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_service_costs TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_service_costs TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_services TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_services TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.ticket_services TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.trade_counters TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.trade_counters TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.trade_counters TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.trade_docs TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.trade_docs TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.trade_docs TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.work_items TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.work_items TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.work_items TO service_role;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.work_money TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.work_money TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.work_money TO service_role;

