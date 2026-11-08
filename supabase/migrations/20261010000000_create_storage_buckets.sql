-- Supabase Migration: Create Storage Buckets and Policies for Avatars, Person Photos, and Aadhaar Photos
-- Date: 2026-10-10

-- 1. Create storage buckets if they do not already exist
insert into storage.buckets (id, name, public)
values 
  ('avatars', 'avatars', true),
  ('person-photos', 'person-photos', true),
  ('aadhaar-photos', 'aadhaar-photos', true)
on conflict (id) do update set public = true;

-- 2. Storage Policies for avatars
do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Public Access for avatars' and tablename = 'objects') then
    create policy "Public Access for avatars"
      on storage.objects for select
      using (bucket_id = 'avatars');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Authenticated Uploads for avatars' and tablename = 'objects') then
    create policy "Authenticated Uploads for avatars"
      on storage.objects for insert
      with check (bucket_id = 'avatars');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Authenticated Updates for avatars' and tablename = 'objects') then
    create policy "Authenticated Updates for avatars"
      on storage.objects for update
      using (bucket_id = 'avatars');
  end if;
end $$;

-- 3. Storage Policies for person-photos
do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Public Access for person-photos' and tablename = 'objects') then
    create policy "Public Access for person-photos"
      on storage.objects for select
      using (bucket_id = 'person-photos');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Authenticated Uploads for person-photos' and tablename = 'objects') then
    create policy "Authenticated Uploads for person-photos"
      on storage.objects for insert
      with check (bucket_id = 'person-photos');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Authenticated Updates for person-photos' and tablename = 'objects') then
    create policy "Authenticated Updates for person-photos"
      on storage.objects for update
      using (bucket_id = 'person-photos');
  end if;
end $$;

-- 4. Storage Policies for aadhaar-photos
do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Public Access for aadhaar-photos' and tablename = 'objects') then
    create policy "Public Access for aadhaar-photos"
      on storage.objects for select
      using (bucket_id = 'aadhaar-photos');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Authenticated Uploads for aadhaar-photos' and tablename = 'objects') then
    create policy "Authenticated Uploads for aadhaar-photos"
      on storage.objects for insert
      with check (bucket_id = 'aadhaar-photos');
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Authenticated Updates for aadhaar-photos' and tablename = 'objects') then
    create policy "Authenticated Updates for aadhaar-photos"
      on storage.objects for update
      using (bucket_id = 'aadhaar-photos');
  end if;
end $$;
