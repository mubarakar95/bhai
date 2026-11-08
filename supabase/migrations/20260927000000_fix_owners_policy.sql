-- Migration: Fix Owners Insert Policy & Backfill Missing Auth Users
-- Date: 2026-09-27
-- Description:
-- 1. Adds missing INSERT RLS policy on public.owners so authenticated owners can create/upsert their profile.
-- 2. Backfills any existing users in auth.users into public.owners to satisfy foreign key constraints.

-- Step 1: Add INSERT policy for public.owners
drop policy if exists "Owners can insert their own profile" on public.owners;

create policy "Owners can insert their own profile"
    on public.owners for insert
    with check (auth.uid() = id);

-- Step 2: Backfill existing auth.users into public.owners
insert into public.owners (id, full_name, business_name, mobile_no, email, subscription_plan)
select 
    id, 
    coalesce(raw_user_meta_data->>'full_name', coalesce(email, 'Property Owner')),
    coalesce(raw_user_meta_data->>'business_name', 'Bhai App PG'),
    coalesce(raw_user_meta_data->>'mobile_no', coalesce(phone, '')),
    coalesce(email, ''),
    'free'
from auth.users
on conflict (id) do nothing;
