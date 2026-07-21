-- Phase 1: Core platform — legal entities, branches, number sequences, security matrix, audit log
-- Backbone rules: entity scoping (1), number sequences (2), security matrix (5). See CLAUDE.md.

-- ============================================================ legal entities
create table if not exists public.legal_entities (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  gstin text,
  address text,
  base_currency text not null default 'INR',
  fiscal_year_start text not null default '04-01', -- MM-DD (Indian FY)
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  branch_no text not null,
  name text not null,
  crm_shop_id uuid,        -- legacy CRM shops.id
  profix_shop_id integer,  -- legacy profix_shops.id
  is_store boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (entity_id, branch_no)
);

-- ============================================================ number sequences
create table if not exists public.number_sequences (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.legal_entities(id),
  code text not null,                -- e.g. CUST, SO, SINV
  prefix text not null default '',
  suffix text not null default '',
  next_no bigint not null default 1,
  padding int not null default 5,
  reset_policy text not null default 'never' check (reset_policy in ('never','yearly','monthly')),
  last_reset_period text,
  unique (entity_id, code)
);

-- Atomic, gap-free-enough allocation. Row lock (FOR UPDATE) serializes concurrent allocations.
create or replace function public.allocate_number(p_entity uuid, p_code text)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  seq number_sequences%rowtype;
  period text;
  num bigint;
begin
  select * into seq from number_sequences
   where entity_id = p_entity and code = p_code
   for update;
  if not found then
    raise exception 'number sequence "%" not configured for entity %', p_code, p_entity;
  end if;
  period := case seq.reset_policy
              when 'yearly'  then to_char(now(), 'YYYY')
              when 'monthly' then to_char(now(), 'YYYYMM')
              else null end;
  if period is not null and seq.last_reset_period is distinct from period then
    num := 1;
    update number_sequences set next_no = 2, last_reset_period = period where id = seq.id;
  else
    num := seq.next_no;
    update number_sequences set next_no = num + 1 where id = seq.id;
  end if;
  return seq.prefix || lpad(num::text, greatest(seq.padding, length(num::text)), '0') || seq.suffix;
end $$;

revoke all on function public.allocate_number(uuid, text) from public, anon, authenticated;

-- ============================================================ security matrix
create table if not exists public.erp_user_profiles (
  user_id uuid primary key,          -- auth.users.id
  display_name text,
  phone text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_privileges (
  code text primary key,             -- module.function.action e.g. sysadmin.entities.write
  module text not null,
  description text
);

create table if not exists public.erp_role_privileges (
  role_id uuid not null references public.erp_roles(id) on delete cascade,
  privilege_code text not null references public.erp_privileges(code) on delete cascade,
  primary key (role_id, privilege_code)
);

create table if not exists public.erp_user_roles (
  user_id uuid not null,
  role_id uuid not null references public.erp_roles(id) on delete cascade,
  entity_id uuid not null references public.legal_entities(id),
  primary key (user_id, role_id, entity_id)
);

-- ============================================================ audit log
create table if not exists public.erp_audit_log (
  id bigint generated always as identity primary key,
  entity_id uuid,
  actor uuid,
  actor_email text,
  table_name text not null,
  record_id text,
  action text not null,              -- INSERT / UPDATE / DELETE
  diff jsonb,
  at timestamptz not null default now()
);
create index if not exists erp_audit_log_at_idx on public.erp_audit_log (at desc);
create index if not exists erp_audit_log_table_idx on public.erp_audit_log (table_name, record_id);

create or replace function public.erp_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare rid text; ent uuid; d jsonb;
begin
  -- Some junction tables (erp_role_privileges, erp_user_roles) have no id column: guard both lookups.
  if tg_op = 'DELETE' then
    d := to_jsonb(old);
    rid := d ->> 'id';
    ent := nullif(d ->> 'entity_id', '')::uuid;
  else
    rid := to_jsonb(new) ->> 'id';
    ent := nullif(to_jsonb(new) ->> 'entity_id', '')::uuid;
    if tg_op = 'UPDATE' then
      select jsonb_object_agg(n.key, jsonb_build_array(o.value, n.value)) into d
      from jsonb_each(to_jsonb(old)) o join jsonb_each(to_jsonb(new)) n on o.key = n.key
      where o.value is distinct from n.value;
    else
      d := to_jsonb(new);
    end if;
  end if;
  insert into erp_audit_log(entity_id, actor, actor_email, table_name, record_id, action, diff)
  values (ent, auth.uid(), (auth.jwt() ->> 'email'), tg_table_name, rid, tg_op, d);
  return coalesce(new, old);
end $$;

do $$ declare t text;
begin
  foreach t in array array['legal_entities','branches','number_sequences','erp_roles','erp_role_privileges','erp_user_roles']
  loop
    execute format('drop trigger if exists audit_%s on public.%s', t, t);
    execute format('create trigger audit_%s after insert or update or delete on public.%s for each row execute function public.erp_audit()', t, t);
  end loop;
end $$;

-- ============================================================ RLS: reads for signed-in users, writes only via API (service role)
do $$ declare t text;
begin
  foreach t in array array['legal_entities','branches','number_sequences','erp_user_profiles','erp_roles','erp_privileges','erp_role_privileges','erp_user_roles','erp_audit_log']
  loop
    execute format('alter table public.%s enable row level security', t);
    execute format('drop policy if exists %s_read on public.%s', t, t);
    execute format('create policy %s_read on public.%s for select to authenticated using (true)', t, t);
    -- no insert/update/delete policies: only the service role (API tier) can write
  end loop;
end $$;

-- ============================================================ seeds
insert into public.legal_entities (code, name) values ('PROFIX', 'ProFix World')
on conflict (code) do nothing;

-- Existing profixworld branches
insert into public.branches (entity_id, branch_no, name, profix_shop_id)
select e.id, 'BR-' || lpad(s.id::text, 3, '0'), s.name, s.id
from public.profix_shops s
cross join (select id from public.legal_entities where code = 'PROFIX') e
on conflict (entity_id, branch_no) do nothing;

-- Existing CRM shops as branches
insert into public.branches (entity_id, branch_no, name, crm_shop_id)
select e.id, 'BRC-' || lpad((row_number() over (order by s.created_at))::text, 3, '0'), s.name, s.id
from public.shops s
cross join (select id from public.legal_entities where code = 'PROFIX') e
where not exists (select 1 from public.branches b where b.crm_shop_id = s.id)
on conflict (entity_id, branch_no) do nothing;

-- Standard sequences
insert into public.number_sequences (entity_id, code, prefix, padding)
select e.id, v.code, v.prefix, 5
from (values
  ('CUST','CUS-'), ('VEND','VEN-'), ('ITEM','ITM-'), ('EMP','EMP-'),
  ('SQ','SQ-'), ('SO','SO-'), ('SINV','INV-'), ('PO','PO-'), ('GRN','GRN-'),
  ('PINV','PIN-'), ('GLJ','GLJ-'), ('VCH','VCH-'), ('SVC','SVC-'), ('AST','AST-'), ('DOC','DOC-')
) v(code, prefix)
cross join (select id from public.legal_entities where code = 'PROFIX') e
on conflict (entity_id, code) do nothing;

-- Privilege catalog (Phase 1: sysadmin; later phases append their own)
insert into public.erp_privileges (code, module, description) values
  ('sysadmin.entities.read',  'sysadmin', 'View legal entities & branches'),
  ('sysadmin.entities.write', 'sysadmin', 'Manage legal entities & branches'),
  ('sysadmin.sequences.read', 'sysadmin', 'View number sequences'),
  ('sysadmin.sequences.write','sysadmin', 'Manage number sequences'),
  ('sysadmin.users.read',     'sysadmin', 'View users'),
  ('sysadmin.users.write',    'sysadmin', 'Manage users & role assignment'),
  ('sysadmin.roles.read',     'sysadmin', 'View roles'),
  ('sysadmin.roles.write',    'sysadmin', 'Manage roles & privileges'),
  ('sysadmin.audit.read',     'sysadmin', 'View audit log')
on conflict (code) do nothing;

insert into public.erp_roles (name, description) values ('admin', 'Full access')
on conflict (name) do nothing;

insert into public.erp_role_privileges (role_id, privilege_code)
select r.id, p.code from public.erp_roles r cross join public.erp_privileges p where r.name = 'admin'
on conflict do nothing;

-- Bootstrap: give the owner account admin on PROFIX (no-op if the user doesn't exist yet)
insert into public.erp_user_roles (user_id, role_id, entity_id)
select u.id, r.id, e.id
from auth.users u, public.erp_roles r, public.legal_entities e
where u.email = 'sivavasusp@gmail.com' and r.name = 'admin' and e.code = 'PROFIX'
on conflict do nothing;
