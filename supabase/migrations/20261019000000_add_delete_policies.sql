-- Migration: Add DELETE Policy for Persons
-- Date: 2026-10-19
-- Description: Allows property owner users to delete guest profiles they have created or manage.

drop policy if exists "Authenticated owners can delete guest profiles" on public.persons;

create policy "Authenticated owners can delete guest profiles"
    on public.persons for delete
    using (auth.role() = 'authenticated');
