create extension if not exists pgcrypto;

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null default '我的旅行',
  budget numeric(14, 2) not null default 0,
  base_currency text not null default 'CNY',
  foreign_currency text not null default 'THB',
  rate numeric(18, 8) not null default 1,
  category_budgets jsonb not null default '{}'::jsonb,
  members jsonb not null default '[]'::jsonb check (jsonb_typeof(members) = 'array'),
  invite_code text not null unique default lower(substr(encode(gen_random_bytes(5), 'hex'), 1, 10)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.trip_members (
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '我',
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (trip_id, user_id)
);

create table if not exists public.bills (
  id text not null,
  trip_id uuid not null references public.trips(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('expense', 'itinerary', 'transfer')),
  amount numeric(14, 2) not null default 0,
  currency text not null default 'CNY',
  fx_rate numeric(18, 8) not null default 1,
  base_amount numeric(14, 2) not null default 0,
  description text not null default '',
  timestamp timestamptz not null default now(),
  category text,
  itinerary_type text,
  itinerary_start timestamptz,
  itinerary_end timestamptz,
  payer text,
  receiver text,
  participants jsonb not null default '[]'::jsonb check (jsonb_typeof(participants) = 'array'),
  location text not null default '',
  note text not null default '',
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (trip_id, id)
);

-- Shared flight info cache (cross-device, cross-user)
create table if not exists public.flight_cache (
  flight_no text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trips_set_updated_at on public.trips;
create trigger trips_set_updated_at
before update on public.trips
for each row execute function public.set_updated_at();

drop trigger if exists bills_set_updated_at on public.bills;
create trigger bills_set_updated_at
before update on public.bills
for each row execute function public.set_updated_at();

create or replace function public.is_trip_member(target_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.trips t
    where t.id = target_trip_id
      and t.owner_id = auth.uid()
  ) or exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = target_trip_id
      and tm.user_id = auth.uid()
  );
$$;

create or replace function public.join_trip_by_invite(invite_code_input text, member_name text default '我')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_trip_id uuid;
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'not authenticated';
  end if;

  select t.id
  into target_trip_id
  from public.trips t
  where t.invite_code = lower(trim(invite_code_input))
  limit 1;

  if target_trip_id is null then
    raise exception 'invalid invite code';
  end if;

  insert into public.trip_members (trip_id, user_id, display_name, role)
  values (target_trip_id, current_user_id, coalesce(nullif(trim(member_name), ''), '我'), 'member')
  on conflict (trip_id, user_id) do update
  set display_name = excluded.display_name;

  return target_trip_id;
end;
$$;

alter table public.trips enable row level security;
alter table public.trip_members enable row level security;
alter table public.bills enable row level security;

drop policy if exists "trips_select_members" on public.trips;
create policy "trips_select_members"
on public.trips for select
using (owner_id = auth.uid() or public.is_trip_member(id));

drop policy if exists "trips_insert_owner" on public.trips;
create policy "trips_insert_owner"
on public.trips for insert
with check (owner_id = auth.uid());

drop policy if exists "trips_update_members" on public.trips;
create policy "trips_update_members"
on public.trips for update
using (public.is_trip_member(id))
with check (public.is_trip_member(id));

drop policy if exists "trips_delete_owner" on public.trips;
create policy "trips_delete_owner"
on public.trips for delete
using (owner_id = auth.uid());

drop policy if exists "trip_members_select_trip_members" on public.trip_members;
create policy "trip_members_select_trip_members"
on public.trip_members for select
using (user_id = auth.uid() or public.is_trip_member(trip_id));

drop policy if exists "trip_members_insert_owner_self" on public.trip_members;
create policy "trip_members_insert_owner_self"
on public.trip_members for insert
with check (
  user_id = auth.uid()
  and role = 'owner'
  and exists (
    select 1
    from public.trips t
    where t.id = trip_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists "trip_members_delete_self_member" on public.trip_members;
create policy "trip_members_delete_self_member"
on public.trip_members for delete
using (user_id = auth.uid() and role = 'member');

drop policy if exists "trip_members_update_self" on public.trip_members;
create policy "trip_members_update_self"
on public.trip_members for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "bills_select_members" on public.bills;
create policy "bills_select_members"
on public.bills for select
using (public.is_trip_member(trip_id));

drop policy if exists "bills_insert_members" on public.bills;
create policy "bills_insert_members"
on public.bills for insert
with check (created_by = auth.uid() and public.is_trip_member(trip_id));

drop policy if exists "bills_update_members" on public.bills;
create policy "bills_update_members"
on public.bills for update
using (public.is_trip_member(trip_id))
with check (public.is_trip_member(trip_id));

drop policy if exists "bills_delete_members" on public.bills;
create policy "bills_delete_members"
on public.bills for delete
using (public.is_trip_member(trip_id));

-- Flight cache: any authenticated user can read/write (shared knowledge base)
alter table public.flight_cache enable row level security;
drop policy if exists "flight_cache_select_auth" on public.flight_cache;
create policy "flight_cache_select_auth"
on public.flight_cache for select
using (auth.role() = 'authenticated');

drop policy if exists "flight_cache_insert_auth" on public.flight_cache;
create policy "flight_cache_insert_auth"
on public.flight_cache for insert
with check (auth.role() = 'authenticated');

drop policy if exists "flight_cache_update_auth" on public.flight_cache;
create policy "flight_cache_update_auth"
on public.flight_cache for update
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.trips to authenticated;
grant select, insert, update, delete on public.trip_members to authenticated;
grant select, insert, update, delete on public.bills to authenticated;
grant select, insert, update on public.flight_cache to authenticated;
grant execute on function public.is_trip_member(uuid) to authenticated;
grant execute on function public.join_trip_by_invite(text, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trips'
    ) then
      alter publication supabase_realtime add table public.trips;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'bills'
    ) then
      alter publication supabase_realtime add table public.bills;
    end if;
  end if;
end $$;
