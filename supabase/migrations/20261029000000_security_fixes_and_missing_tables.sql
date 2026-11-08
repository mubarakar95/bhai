-- Supabase Migration: Production Security Fixes and Missing Tables
-- Date: 2026-10-29
-- Description:
-- 1. Drops wide-open public read policy on aadhaar-photos and scopes it to authenticated owners.
-- 2. Closes critical IDOR vulnerability on public.persons delete policy, restricting deletion to the creating owner.
-- 3. Adds DELETE policy on public.owners and creates security definer delete_user_account() RPC.
-- 4. Creates public.contact_messages table for in-app contact/support requests with RLS.
-- 5. Creates public.app_config table for dynamic version checking and force update management.

-- ==============================================================================
-- 1. Aadhaar Storage Security Hardening
-- ==============================================================================
do $$
begin
  -- Drop overly permissive public read policy if it exists
  if exists (select 1 from pg_policies where policyname = 'Public Access for aadhaar-photos' and tablename = 'objects') then
    drop policy "Public Access for aadhaar-photos" on storage.objects;
  end if;

  -- Create authenticated owner read policy for aadhaar-photos
  if not exists (select 1 from pg_policies where policyname = 'Authenticated owners can view aadhaar-photos' and tablename = 'objects') then
    create policy "Authenticated owners can view aadhaar-photos"
      on storage.objects for select
      using (bucket_id = 'aadhaar-photos' and auth.role() = 'authenticated');
  end if;
end $$;

-- ==============================================================================
-- 2. Persons Table IDOR Fix (Restrict Guest Profile Deletion)
-- ==============================================================================
drop policy if exists "Authenticated owners can delete guest profiles" on public.persons;
drop policy if exists "Owners can delete guest profiles they created" on public.persons;

create policy "Owners can delete guest profiles they created"
    on public.persons for delete
    using (
        created_by_owner_id = auth.uid()
        and not exists (
            select 1 from public.stays
            where public.stays.person_id = public.persons.id
            and public.stays.owner_id != auth.uid()
        )
    );

-- ==============================================================================
-- 3. Account Deletion RPC & Owners Delete Policy (Store Compliance)
-- ==============================================================================
drop policy if exists "Owners can delete their own profile" on public.owners;

create policy "Owners can delete their own profile"
    on public.owners for delete
    using (auth.uid() = id);

create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    calling_user_id uuid;
begin
    calling_user_id := auth.uid();
    if calling_user_id is null then
        raise exception 'Not authenticated';
    end if;

    -- Deleting from auth.users cascades through public.owners to all properties, rooms, stays, payments
    delete from auth.users where id = calling_user_id;
end;
$$;

grant execute on function public.delete_user_account() to authenticated;

-- ==============================================================================
-- 4. Contact Messages Table (Missing Table Remediation)
-- ==============================================================================
create table if not exists public.contact_messages (
    id uuid default gen_random_uuid() primary key,
    owner_id uuid references public.owners(id) on delete set null,
    name text not null,
    contact text not null,
    subject text not null,
    message text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.contact_messages enable row level security;

drop policy if exists "Anyone authenticated can insert contact messages" on public.contact_messages;
create policy "Anyone authenticated can insert contact messages"
    on public.contact_messages for insert
    with check (auth.role() = 'authenticated');

drop policy if exists "Owners can view their own contact messages" on public.contact_messages;
create policy "Owners can view their own contact messages"
    on public.contact_messages for select
    using (owner_id = auth.uid());

-- ==============================================================================
-- 5. App Config Table (For Version Checking & Remote Flags)
-- ==============================================================================
create table if not exists public.app_config (
    key text primary key,
    value jsonb not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.app_config enable row level security;

drop policy if exists "Anyone can read app_config" on public.app_config;
create policy "Anyone can read app_config"
    on public.app_config for select
    using (true);

-- Seed default version configuration if missing
insert into public.app_config (key, value)
values (
    'app_version_config',
    '{
        "latest_version": "1.0.0",
        "min_version": "1.0.0",
        "title": "Update Available",
        "message": "A new version of Bhai App is available with performance improvements and bug fixes.",
        "force_update": false,
        "play_store_url": "https://play.google.com/store/apps/details?id=com.bhai.room_rental"
    }'::jsonb
)
on conflict (key) do nothing;
