-- Migration: Security lockdown (RLS, storage, functions, guards)
-- Date: 2026-11-23
--
-- Why: the live project had "Full access" (USING true) policies on every core table
-- granted to the `public` role (incl. `anon`), so anyone holding the publishable key
-- could read/modify/delete all data. Buckets were public, SECURITY DEFINER view/functions
-- were callable by anon, and owners could set their own subscription_plan.
--
-- This migration replaces every policy with owner-scoped ones, moves cross-owner
-- features (guest lookup / blacklist / history) behind narrow SECURITY DEFINER RPCs,
-- makes the aadhaar bucket private + owner-scoped, and guards sensitive columns.

--------------------------------------------------------------------------------
-- 0. Helper functions
--------------------------------------------------------------------------------
create or replace function public.person_used_by_others(p_person_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.stays s
    where s.person_id = p_person_id
      and s.owner_id is distinct from auth.uid()
      and not exists (
        select 1 from public.properties pr
        where pr.id = s.property_id and pr.owner_id = auth.uid()
      )
  );
$$;

--------------------------------------------------------------------------------
-- 1. Schema fixes
--------------------------------------------------------------------------------
-- Deleting an owner must not cascade-delete shared guest profiles that other owners use.
alter table public.persons alter column created_by_owner_id drop not null;
alter table public.persons drop constraint if exists persons_created_by_owner_id_fkey;
alter table public.persons
  add constraint persons_created_by_owner_id_fkey
  foreign key (created_by_owner_id) references public.owners(id) on delete set null;

-- Integrity constraints (NOT VALID: enforced for new/changed rows, legacy rows untouched)
alter table public.payments drop constraint if exists payments_amount_positive;
alter table public.payments add constraint payments_amount_positive check (amount > 0) not valid;
alter table public.payments drop constraint if exists payments_type_valid;
alter table public.payments add constraint payments_type_valid
  check (payment_type in ('deposit','advance','rent','refund')) not valid;
alter table public.stays drop constraint if exists stays_rate_nonneg;
alter table public.stays add constraint stays_rate_nonneg check (agreed_rate >= 0) not valid;
alter table public.reports_log drop constraint if exists reports_log_type_valid;
alter table public.reports_log add constraint reports_log_type_valid
  check (report_type in ('blacklist','police_complaint','flag_for_review')) not valid;
alter table public.contact_messages drop constraint if exists contact_messages_len;
alter table public.contact_messages add constraint contact_messages_len
  check (char_length(message) <= 5000 and char_length(subject) <= 200
         and char_length(name) <= 200 and char_length(contact) <= 200) not valid;

-- Indexes backing the RLS predicates / FK lookups
create index if not exists idx_stays_owner_id on public.stays(owner_id);
create index if not exists idx_stays_person_id on public.stays(person_id);
create index if not exists idx_stays_property_id on public.stays(property_id);
create index if not exists idx_stays_room_id on public.stays(room_id);
create index if not exists idx_payments_stay_id on public.payments(stay_id);
create index if not exists idx_payments_owner_id on public.payments(owner_id);
create index if not exists idx_rooms_property_id on public.rooms(property_id);
create index if not exists idx_properties_owner_id on public.properties(owner_id);
create index if not exists idx_persons_aadhaar_no on public.persons(aadhaar_no);
create index if not exists idx_persons_mobile_no on public.persons(mobile_no);
create index if not exists idx_persons_created_by on public.persons(created_by_owner_id);
create index if not exists idx_persons_blacklisted on public.persons(is_blacklisted) where is_blacklisted;

--------------------------------------------------------------------------------
-- 2. Guard triggers (sensitive columns cannot be changed by clients)
--------------------------------------------------------------------------------
create or replace function public.guard_owner_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- service role / SQL editor / auth hooks (no end-user JWT) are trusted
  if auth.uid() is null then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.subscription_plan := 'free';
    new.created_at := now();
  else
    new.id := old.id;
    new.subscription_plan := old.subscription_plan;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_owner_write on public.owners;
create trigger guard_owner_write
  before insert or update on public.owners
  for each row execute function public.guard_owner_write();

create or replace function public.guard_person_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is null or current_setting('app.guard_bypass', true) = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.is_blacklisted := false;
    new.blacklist_reason := null;
    new.blacklisted_by := null;
    new.blacklisted_at := null;
    new.created_by_owner_id := auth.uid();
  else
    new.id := old.id;
    new.created_by_owner_id := old.created_by_owner_id;
    new.created_at := old.created_at;
    new.is_blacklisted := old.is_blacklisted;
    new.blacklist_reason := old.blacklist_reason;
    new.blacklisted_by := old.blacklisted_by;
    new.blacklisted_at := old.blacklisted_at;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_person_write on public.persons;
create trigger guard_person_write
  before insert or update on public.persons
  for each row execute function public.guard_person_write();

--------------------------------------------------------------------------------
-- 3. Replace ALL policies on app tables
--------------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('owners','persons','properties','rooms','stays','payments',
                        'reports_log','contact_messages','app_config','cf-orders')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- owners
create policy owners_select_own on public.owners for select to authenticated
  using (id = auth.uid());
create policy owners_insert_own on public.owners for insert to authenticated
  with check (id = auth.uid());
create policy owners_update_own on public.owners for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- properties
create policy properties_all_own on public.properties for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- rooms
create policy rooms_all_own on public.rooms for all to authenticated
  using (exists (select 1 from public.properties pr where pr.id = rooms.property_id and pr.owner_id = auth.uid()))
  with check (exists (select 1 from public.properties pr where pr.id = rooms.property_id and pr.owner_id = auth.uid()));

-- stays (owner of the stay OR owner of the property it is in)
create policy stays_select on public.stays for select to authenticated
  using (owner_id = auth.uid()
         or exists (select 1 from public.properties pr where pr.id = stays.property_id and pr.owner_id = auth.uid()));
create policy stays_insert on public.stays for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (select 1 from public.properties pr where pr.id = stays.property_id and pr.owner_id = auth.uid())
    and exists (select 1 from public.rooms r where r.id = stays.room_id and r.property_id = stays.property_id)
  );
create policy stays_update on public.stays for update to authenticated
  using (owner_id = auth.uid()
         or exists (select 1 from public.properties pr where pr.id = stays.property_id and pr.owner_id = auth.uid()))
  with check (owner_id = auth.uid()
         or exists (select 1 from public.properties pr where pr.id = stays.property_id and pr.owner_id = auth.uid()));
create policy stays_delete on public.stays for delete to authenticated
  using (owner_id = auth.uid());

-- payments: append-only ledger (no update / delete for clients)
create policy payments_select on public.payments for select to authenticated
  using (owner_id = auth.uid()
         or exists (select 1 from public.stays s where s.id = payments.stay_id));
create policy payments_insert on public.payments for insert to authenticated
  with check (
    owner_id = auth.uid()
    and recorded_by = auth.uid()
    and exists (select 1 from public.stays s where s.id = payments.stay_id and s.person_id = payments.person_id)
  );

-- persons (shared registry): visible only if you created the profile or have a stay with it.
-- Cross-owner lookup / blacklist go through the RPCs below.
create policy persons_select on public.persons for select to authenticated
  using (created_by_owner_id = auth.uid()
         or exists (select 1 from public.stays s where s.person_id = persons.id));
create policy persons_insert on public.persons for insert to authenticated
  with check (created_by_owner_id = auth.uid());
create policy persons_update on public.persons for update to authenticated
  using (created_by_owner_id = auth.uid()
         or exists (select 1 from public.stays s where s.person_id = persons.id))
  with check (created_by_owner_id = auth.uid()
         or exists (select 1 from public.stays s where s.person_id = persons.id));
create policy persons_delete on public.persons for delete to authenticated
  using ((created_by_owner_id = auth.uid()
          or exists (select 1 from public.stays s where s.person_id = persons.id))
         and not public.person_used_by_others(persons.id));

-- reports_log: read own; rows are written only by blacklist_guest()
create policy reports_select_own on public.reports_log for select to authenticated
  using (reported_by_owner_id = auth.uid());

-- contact_messages
create policy contact_insert on public.contact_messages for insert to authenticated
  with check (owner_id is null or owner_id = auth.uid());
create policy contact_select_own on public.contact_messages for select to authenticated
  using (owner_id = auth.uid());

-- app_config: read-only for everyone (needed for the pre-login update check)
create policy app_config_read on public.app_config for select to anon, authenticated
  using (true);

--------------------------------------------------------------------------------
-- 4. Table privileges (defence in depth)
--------------------------------------------------------------------------------
revoke all on public.owners, public.persons, public.properties, public.rooms, public.stays,
              public.payments, public.reports_log, public.contact_messages from anon;
revoke truncate, references, trigger on public.owners, public.persons, public.properties,
              public.rooms, public.stays, public.payments, public.reports_log,
              public.contact_messages from authenticated;
revoke update, delete on public.payments from authenticated;
revoke insert, update, delete on public.reports_log from authenticated;
revoke update, delete on public.contact_messages from authenticated;
revoke delete on public.owners from authenticated;
revoke insert, update, delete, truncate, references, trigger on public.app_config from anon, authenticated;

-- Leftover template tables from the project's earlier life (unused by the app)
revoke all on public."cf-orders" from anon, authenticated;
revoke all on public.profiles, public.subscriptions, public.trials, public.user_roles from anon;
revoke insert, update, delete, truncate, references, trigger on public.subscription_plans from anon, authenticated;

-- Views run with the caller's RLS instead of the owner's
alter view public.guest_stay_history set (security_invoker = true);
alter view public.user_trial_and_subscription_info set (security_invoker = true);
revoke all on public.guest_stay_history from anon;
revoke insert, update, delete, truncate, references, trigger on public.guest_stay_history from authenticated;
revoke all on public.user_trial_and_subscription_info from anon;
revoke insert, update, delete, truncate, references, trigger on public.user_trial_and_subscription_info from authenticated;

alter default privileges for role postgres in schema public revoke all on tables from anon;

--------------------------------------------------------------------------------
-- 5. RPCs for cross-owner features
--------------------------------------------------------------------------------
-- Exact-match guest lookup by Aadhaar (full row so the check-in form can prefill).
-- Aadhaar card PHOTO is only returned to the owner who uploaded it.
create or replace function public.lookup_person(p_aadhaar text)
returns setof public.persons
language sql stable security definer
set search_path = public
as $$
  select p.id, p.name, p.mobile_no, p.aadhaar_no, p.father_name, p.mother_name, p.wife_name,
         p.wife_mobile_no, p.police_station_circle,
         case when p.created_by_owner_id = auth.uid() then p.aadhaar_card_photo end,
         p.person_photo, p.address, p.city, p.state, p.pincode, p.dob,
         p.is_blacklisted, p.blacklist_reason, p.blacklisted_by, p.blacklisted_at,
         p.created_by_owner_id, p.created_at
  from public.persons p
  where auth.uid() is not null
    and nullif(btrim(p_aadhaar), '') is not null
    and p.aadhaar_no = btrim(p_aadhaar)
  order by (p.created_by_owner_id = auth.uid()) desc nulls last,
           p.is_blacklisted desc, p.created_at desc
  limit 1;
$$;

create or replace function public.check_blacklist(p_aadhaar text default null, p_mobile text default null)
returns setof public.persons
language sql stable security definer
set search_path = public
as $$
  select p.id, p.name, p.mobile_no, p.aadhaar_no, p.father_name, p.mother_name, p.wife_name,
         p.wife_mobile_no, p.police_station_circle,
         case when p.created_by_owner_id = auth.uid() then p.aadhaar_card_photo end,
         p.person_photo, p.address, p.city, p.state, p.pincode, p.dob,
         p.is_blacklisted, p.blacklist_reason, p.blacklisted_by, p.blacklisted_at,
         p.created_by_owner_id, p.created_at
  from public.persons p
  where auth.uid() is not null
    and p.is_blacklisted
    and ((nullif(btrim(p_aadhaar), '') is not null and p.aadhaar_no = btrim(p_aadhaar))
      or (nullif(btrim(p_mobile), '') is not null and p.mobile_no = btrim(p_mobile)))
  limit 1;
$$;

create or replace function public.list_blacklisted()
returns setof public.persons
language sql stable security definer
set search_path = public
as $$
  select p.id, p.name, p.mobile_no, p.aadhaar_no, p.father_name, p.mother_name, p.wife_name,
         p.wife_mobile_no, p.police_station_circle,
         null::text,
         p.person_photo, p.address, p.city, p.state, p.pincode, p.dob,
         p.is_blacklisted, p.blacklist_reason, p.blacklisted_by, p.blacklisted_at,
         p.created_by_owner_id, p.created_at
  from public.persons p
  where auth.uid() is not null and p.is_blacklisted
  order by p.blacklisted_at desc nulls last
  limit 1000;
$$;

create or replace function public.get_owner_contact(p_owner_id uuid)
returns table (id uuid, full_name text, business_name text, mobile_no text)
language sql stable security definer
set search_path = public
as $$
  select o.id, o.full_name, o.business_name, o.mobile_no
  from public.owners o
  where auth.uid() is not null
    and o.id = p_owner_id
    and (o.id = auth.uid()
         or exists (select 1 from public.persons p where p.blacklisted_by = o.id));
$$;

create or replace function public.get_guest_stay_history(p_person_id uuid)
returns table (stay_id uuid, person_id uuid, check_in_date timestamptz, check_out_date timestamptz,
               status text, property_type text, property_name text, property_city text, room_number text)
language sql stable security definer
set search_path = public
as $$
  select s.id, s.person_id, s.check_in_date, s.check_out_date, s.status,
         coalesce(p.property_type, 'PG'), coalesce(p.name, 'Property'),
         coalesce(p.city, 'City'), coalesce(r.room_number, 'N/A')
  from public.stays s
  left join public.properties p on p.id = s.property_id
  left join public.rooms r on r.id = s.room_id
  where auth.uid() is not null and s.person_id = p_person_id
  order by s.check_in_date desc;
$$;

create or replace function public.get_active_stay_for_person(p_person_id uuid)
returns table (stay_id uuid, person_id uuid, check_in_date timestamptz, check_out_date timestamptz,
               status text, property_type text, property_name text, property_city text, room_number text)
language sql stable security definer
set search_path = public
as $$
  select s.id, s.person_id, s.check_in_date, s.check_out_date, s.status,
         coalesce(p.property_type, 'PG'), coalesce(p.name, 'Property'),
         coalesce(p.city, 'City'), coalesce(r.room_number, 'N/A')
  from public.stays s
  left join public.properties p on p.id = s.property_id
  left join public.rooms r on r.id = s.room_id
  where auth.uid() is not null and s.person_id = p_person_id and s.status = 'active'
  order by s.check_in_date desc
  limit 1;
$$;

-- Blacklisting: only owners who have actually hosted the guest; always logged.
create or replace function public.blacklist_guest(
  p_person_id uuid,
  p_reason text,
  p_report_type text default 'blacklist'
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_already boolean;
begin
  if v_uid is null then
    raise exception 'Not authorized';
  end if;
  if p_report_type not in ('blacklist','police_complaint','flag_for_review') then
    raise exception 'Invalid report type';
  end if;
  if char_length(coalesce(btrim(p_reason), '')) = 0 or char_length(p_reason) > 1000 then
    raise exception 'A reason (max 1000 characters) is required';
  end if;
  if not exists (
    select 1 from public.stays s
    where s.person_id = p_person_id
      and (s.owner_id = v_uid
           or exists (select 1 from public.properties pr where pr.id = s.property_id and pr.owner_id = v_uid))
  ) then
    raise exception 'You can only report guests who have stayed with you';
  end if;

  select is_blacklisted into v_already from public.persons where id = p_person_id;
  if v_already is null then
    raise exception 'Guest not found';
  end if;

  if not v_already then
    perform set_config('app.guard_bypass', 'on', true);
    update public.persons
       set is_blacklisted = true, blacklist_reason = p_reason,
           blacklisted_by = v_uid, blacklisted_at = now()
     where id = p_person_id;
    perform set_config('app.guard_bypass', 'off', true);
  end if;

  insert into public.reports_log (person_id, reported_by_owner_id, report_type, description)
  values (p_person_id, v_uid, p_report_type, p_reason);
end;
$$;

create or replace function public.unblacklist_guest(p_person_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_by uuid;
begin
  if v_uid is null then
    raise exception 'Not authorized';
  end if;
  select blacklisted_by into v_by from public.persons where id = p_person_id and is_blacklisted;
  if not found then
    return;
  end if;
  if v_by is not null and v_by <> v_uid then
    raise exception 'Only the original owner who blacklisted this person can remove their blacklist status';
  end if;
  if v_by is null and not exists (
    select 1 from public.stays s
    where s.person_id = p_person_id
      and (s.owner_id = v_uid
           or exists (select 1 from public.properties pr where pr.id = s.property_id and pr.owner_id = v_uid))
  ) then
    raise exception 'Not authorized';
  end if;

  perform set_config('app.guard_bypass', 'on', true);
  update public.persons
     set is_blacklisted = false, blacklist_reason = null,
         blacklisted_by = null, blacklisted_at = null
   where id = p_person_id;
  perform set_config('app.guard_bypass', 'off', true);
end;
$$;

-- Account deletion: remove guest profiles nobody else uses, then the auth user
-- (cascades to owners, properties, rooms, stays, payments, reports).
create or replace function public.delete_user_account()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  delete from public.persons p
   where p.created_by_owner_id = v_uid
     and not exists (
       select 1 from public.stays s
       where s.person_id = p.id and s.owner_id <> v_uid
         and not exists (select 1 from public.properties pr where pr.id = s.property_id and pr.owner_id = v_uid)
     );
  delete from auth.users where id = v_uid;
end;
$$;

-- Create the owners row server-side at signup (the client-side upsert was failing,
-- leaving signups without an owners row).
create or replace function public.handle_new_owner()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if new.raw_user_meta_data ? 'mobile_no' or new.raw_user_meta_data ? 'business_name' then
    insert into public.owners (id, full_name, business_name, mobile_no, email)
    values (
      new.id,
      coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), 'New Owner'),
      new.raw_user_meta_data->>'business_name',
      coalesce(new.raw_user_meta_data->>'mobile_no', ''),
      coalesce(new.email, '')
    )
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_owner on auth.users;
create trigger on_auth_user_created_owner
  after insert on auth.users
  for each row execute function public.handle_new_owner();

-- Backfill signups that never got an owners row
insert into public.owners (id, full_name, business_name, mobile_no, email, created_at)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'full_name', ''), 'New Owner'),
       u.raw_user_meta_data->>'business_name',
       coalesce(u.raw_user_meta_data->>'mobile_no', ''),
       coalesce(u.email, ''),
       u.created_at
from auth.users u
where (u.raw_user_meta_data ? 'mobile_no' or u.raw_user_meta_data ? 'business_name')
  and not exists (select 1 from public.owners o where o.id = u.id)
on conflict (id) do nothing;

--------------------------------------------------------------------------------
-- 6. Function privileges
--------------------------------------------------------------------------------
alter function public.handle_new_user() set search_path = public;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.handle_new_owner() from public, anon, authenticated;
revoke execute on function public.guard_owner_write() from public, anon, authenticated;
revoke execute on function public.guard_person_write() from public, anon, authenticated;

do $$
declare f text;
begin
  foreach f in array array[
    'public.person_used_by_others(uuid)',
    'public.lookup_person(text)',
    'public.check_blacklist(text,text)',
    'public.list_blacklisted()',
    'public.get_owner_contact(uuid)',
    'public.get_guest_stay_history(uuid)',
    'public.get_active_stay_for_person(uuid)',
    'public.blacklist_guest(uuid,text,text)',
    'public.unblacklist_guest(uuid)',
    'public.delete_user_account()'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

--------------------------------------------------------------------------------
-- 7. Storage: private, owner-scoped Aadhaar bucket; owner-scoped writes everywhere
--------------------------------------------------------------------------------
update storage.buckets
   set public = false, file_size_limit = 10485760,
       allowed_mime_types = array['image/jpeg','image/png','image/webp']
 where id = 'aadhaar-photos';

update storage.buckets
   set file_size_limit = 10485760,
       allowed_mime_types = array['image/jpeg','image/png','image/webp']
 where id in ('person-photos','avatars');

do $$
declare r record;
begin
  for r in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname in (
        'Public Access for avatars','Authenticated Uploads for avatars','Authenticated Updates for avatars',
        'Public Access for person-photos','Authenticated Uploads for person-photos','Authenticated Updates for person-photos',
        'Public Access for aadhaar-photos','Authenticated Uploads for aadhaar-photos','Authenticated Updates for aadhaar-photos',
        'Authenticated owners can view aadhaar-photos'
      )
  loop
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;
end $$;

-- aadhaar-photos: only the uploading owner (folder = their uid) can read or write
create policy aadhaar_own_select on storage.objects for select to authenticated
  using (bucket_id = 'aadhaar-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy aadhaar_own_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'aadhaar-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy aadhaar_own_update on storage.objects for update to authenticated
  using (bucket_id = 'aadhaar-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'aadhaar-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy aadhaar_own_delete on storage.objects for delete to authenticated
  using (bucket_id = 'aadhaar-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- person-photos / avatars: readable by signed-in owners (shared guest registry);
-- writes only inside your own uid folder.
create policy photos_read_authenticated on storage.objects for select to authenticated
  using (bucket_id in ('person-photos','avatars'));
create policy photos_own_insert on storage.objects for insert to authenticated
  with check (bucket_id in ('person-photos','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy photos_own_update on storage.objects for update to authenticated
  using (bucket_id in ('person-photos','avatars') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('person-photos','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy photos_own_delete on storage.objects for delete to authenticated
  using (bucket_id in ('person-photos','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
