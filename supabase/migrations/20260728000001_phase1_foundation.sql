-- ============================================================================
-- Manazel — Phase 1: Foundation
-- Identity (auth-linked profiles), roles, permissions, hotels, multi-hotel
-- access grants, and the RLS helper functions every later phase depends on.
--
-- Design reference: docs/database_architecture/supabase_schema_design.md
-- (Sections 1-3, 21). Approved decisions 1, 2, 3, 4, 6 apply; decision 5
-- (Treasury/Vault/Settlements consolidation) is explicitly deferred and has
-- no tables in this or any later migration until that review happens.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Extensions
-- ----------------------------------------------------------------------------
create extension if not exists pgcrypto;   -- gen_random_uuid()
create extension if not exists pg_trgm;    -- trigram search, used from Phase 3 onward (suppliers etc.)

-- ----------------------------------------------------------------------------
-- 2. Shared "touch updated_at" trigger function — attached to every table in
-- this and future migrations that has an updated_at column.
-- ----------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- 3. roles — a small, curated set of named roles (seeded in seed.sql).
-- Not user-manageable in Phase 1 (see RLS below); a role-management UI is
-- future work, not part of this phase.
-- ----------------------------------------------------------------------------
create table roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  is_system_role boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_roles_updated_at before update on roles
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- 4. permissions — fine-grained capability codes, module-scoped. Only the
-- codes Phase 1 actually needs are seeded; every later phase adds its own
-- codes in its own migration, never retrofitted here.
-- ----------------------------------------------------------------------------
create table permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  module text not null,
  description text,
  created_at timestamptz not null default now()
);

create table role_permissions (
  role_id uuid not null references roles(id) on delete cascade,
  permission_id uuid not null references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

-- ----------------------------------------------------------------------------
-- 5. hotels
-- ----------------------------------------------------------------------------
create table hotels (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text,
  identity_color_value integer,
  phone text,
  mobile text,
  whatsapp text,
  address text,
  city text,
  status text not null default 'active' check (status in ('active','inactive')),
  archived_at timestamptz,
  archived_by uuid,   -- FK to profiles added below (profiles is created after hotels)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);
create trigger trg_hotels_updated_at before update on hotels
  for each row execute function set_updated_at();
create index idx_hotels_status on hotels(status) where archived_at is null;

-- ----------------------------------------------------------------------------
-- 6. profiles — 1:1 extension of Supabase auth.users. Created automatically
-- for every new auth user via the trigger at the bottom of this file, so the
-- app never has to manually insert a profile row after sign-up.
-- ----------------------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  is_active boolean not null default true,
  default_role_id uuid references roles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_profiles_updated_at before update on profiles
  for each row execute function set_updated_at();

-- Back-fill the two hotels FKs that couldn't reference profiles until now.
alter table hotels
  add constraint fk_hotels_archived_by foreign key (archived_by) references profiles(id),
  add constraint fk_hotels_created_by foreign key (created_by) references profiles(id),
  add constraint fk_hotels_updated_by foreign key (updated_by) references profiles(id);

-- Auto-create a profile row whenever a new Supabase Auth user is created.
-- full_name defaults to the email local-part until the app lets the user set
-- a real name; never left null (profiles.full_name is not-null by design).
create or replace function handle_new_auth_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;
create trigger trg_handle_new_auth_user
  after insert on auth.users
  for each row execute function handle_new_auth_user();

-- ----------------------------------------------------------------------------
-- 7. user_hotel_access — the multi-hotel isolation mechanism. A user has zero
-- or more hotels they can act on, each with a role that may differ per hotel.
-- ----------------------------------------------------------------------------
create table user_hotel_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  hotel_id uuid not null references hotels(id) on delete cascade,
  role_id uuid not null references roles(id),
  granted_at timestamptz not null default now(),
  granted_by uuid references profiles(id),
  archived_at timestamptz,
  unique (user_id, hotel_id)
);
create index idx_user_hotel_access_user on user_hotel_access(user_id) where archived_at is null;
create index idx_user_hotel_access_hotel on user_hotel_access(hotel_id) where archived_at is null;

-- ----------------------------------------------------------------------------
-- 8. RLS helper functions — every later phase's policies call these two.
-- security definer so they can read user_hotel_access/role_permissions
-- regardless of the calling user's own row-level access to those tables.
-- ----------------------------------------------------------------------------
create or replace function is_hotel_accessible(target_hotel_id uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from user_hotel_access uha
    where uha.user_id = auth.uid()
      and uha.hotel_id = target_hotel_id
      and uha.archived_at is null
  );
$$;

create or replace function has_permission(target_hotel_id uuid, perm_code text)
returns boolean language sql stable security definer as $$
  select exists (
    select 1
    from user_hotel_access uha
    join role_permissions rp on rp.role_id = uha.role_id
    join permissions p on p.id = rp.permission_id
    where uha.user_id = auth.uid()
      and uha.hotel_id = target_hotel_id
      and uha.archived_at is null
      and p.code = perm_code
  );
$$;

-- ----------------------------------------------------------------------------
-- 9. Row Level Security — Phase 1 tables
--
-- Hotel/role/permission provisioning (creating a hotel, creating a role,
-- assigning a user's first hotel access) is deliberately NOT exposed to the
-- `authenticated` role in this phase: a brand-new hotel has no
-- user_hotel_access rows yet, so no RLS policy can safely grant an ordinary
-- user insert rights on it without a bootstrapping hole. These stay
-- back-office actions performed with the Supabase service role key until a
-- dedicated admin/provisioning flow is designed — not an oversight.
-- ----------------------------------------------------------------------------

alter table hotels enable row level security;
create policy hotels_select on hotels
  for select using (is_hotel_accessible(id));
-- Updating an EXISTING hotel's own details has no bootstrapping problem (the
-- caller already has a user_hotel_access row for it) — gated by permission.
create policy hotels_update on hotels
  for update using (is_hotel_accessible(id) and has_permission(id, 'hotels.manage'));
-- No insert/delete policy for `authenticated` — creating/removing a hotel
-- itself is a service-role action in Phase 1 (see note above).

alter table roles enable row level security;
create policy roles_select on roles
  for select using (auth.role() = 'authenticated');
-- No write policy for `authenticated` in Phase 1.

alter table permissions enable row level security;
create policy permissions_select on permissions
  for select using (auth.role() = 'authenticated');

alter table role_permissions enable row level security;
create policy role_permissions_select on role_permissions
  for select using (auth.role() = 'authenticated');

alter table profiles enable row level security;
create policy profiles_select_self on profiles
  for select using (id = auth.uid());
create policy profiles_select_shared_hotel on profiles
  for select using (
    exists (
      select 1 from user_hotel_access mine
      join user_hotel_access theirs on theirs.hotel_id = mine.hotel_id
      where mine.user_id = auth.uid()
        and theirs.user_id = profiles.id
        and mine.archived_at is null
        and theirs.archived_at is null
    )
  );
create policy profiles_update_self on profiles
  for update using (id = auth.uid());

alter table user_hotel_access enable row level security;
create policy user_hotel_access_select_self on user_hotel_access
  for select using (user_id = auth.uid());
create policy user_hotel_access_select_shared_hotel on user_hotel_access
  for select using (is_hotel_accessible(hotel_id));
-- Granting access to a hotel the caller ALREADY has access to has no
-- bootstrapping problem — gated by permission, same reasoning as hotels_update.
create policy user_hotel_access_insert on user_hotel_access
  for insert with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'users.manage'));
create policy user_hotel_access_update on user_hotel_access
  for update using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'users.manage'));
-- No delete policy — revoking access is an archive (update archived_at),
-- never a hard delete, consistent with this project's soft-delete rule.
