-- Supabase Seed Data for Testing
-- Created: 2026-08-31

-- Note: We first insert into auth.users (which triggers handle_new_owner to insert into public.owners)
-- If running on a hosted Supabase project, you can sign up via the UI and copy the owner ID,
-- but for local testing/migration, we can insert directly into auth.users.

-- Clean up existing (for clean seeding)
truncate table public.payments cascade;
truncate table public.stays cascade;
truncate table public.persons cascade;
truncate table public.rooms cascade;
truncate table public.properties cascade;
delete from auth.users where email in ('owner1@test.com', 'owner2@test.com');

-- 1. Insert dummy owners into auth.users
insert into auth.users (id, email, encrypted_password, raw_user_meta_data, email_confirmed_at, phone)
values 
  (
    '11111111-1111-1111-1111-111111111111', 
    'owner1@test.com', 
    -- 'password123' encrypted
    '$2a$10$wN1p0n18Tf0e9dC01LzC3.eM2qA0pT8Fv99Lq1oYgUjZpA1yP8Xg.', 
    '{"full_name": "Rajesh Kumar", "business_name": "Royal PG & Hostels", "mobile_no": "+919876543210"}',
    now(),
    '+919876543210'
  ),
  (
    '22222222-2222-2222-2222-222222222222', 
    'owner2@test.com', 
    -- 'password123' encrypted
    '$2a$10$wN1p0n18Tf0e9dC01LzC3.eM2qA0pT8Fv99Lq1oYgUjZpA1yP8Xg.', 
    '{"full_name": "Sunita Sharma", "business_name": "Comfort PG Co.", "mobile_no": "+919876543211"}',
    now(),
    '+919876543211'
  );

-- Note: The trigger on_auth_user_created automatically populates public.owners.
-- Let's make sure the trigger fired. If you run these queries together, public.owners will contain:
-- Rajesh Kumar (11111111-1111-1111-1111-111111111111)
-- Sunita Sharma (22222222-2222-2222-2222-222222222222)

-- 2. Properties
insert into public.properties (id, owner_id, name, address, city, state, pincode, property_type, contact_no, photos)
values
  (
    'a1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'Royal PG Sector 62',
    'Plot 45, Sector 62',
    'Noida',
    'Uttar Pradesh',
    '201301',
    'PG',
    '+919876543210',
    array['https://images.unsplash.com/photo-1555854877-bab0e564b8d5']
  ),
  (
    'a2222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    'Comfort Living PG',
    'Street 12, Indiranagar',
    'Bengaluru',
    'Karnataka',
    '560038',
    'hostel',
    '+919876543211',
    array['https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf']
  );

-- 3. Rooms (under Royal PG and Comfort PG)
insert into public.rooms (id, property_id, room_number, capacity, current_occupancy, rental_type, daily_rate, monthly_rate, hourly_rate, status)
values
  -- Royal PG Rooms
  (
    'r1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    '101-A',
    2,
    1,
    'both',
    500.00,
    8000.00,
    50.00,
    'available'
  ),
  (
    'r2222222-2222-2222-2222-222222222222',
    'a1111111-1111-1111-1111-111111111111',
    '102-B',
    1,
    1,
    'monthly',
    0.00,
    10000.00,
    0.00,
    'full'
  ),
  -- Comfort PG Rooms
  (
    'r3333333-3333-3333-3333-333333333333',
    'a2222222-2222-2222-2222-222222222222',
    'G-01',
    3,
    0,
    'both',
    600.00,
    9000.00,
    60.00,
    'available'
  );

-- 4. Persons (Guests)
-- One shared/global guest, one normal guest for each owner
insert into public.persons (id, name, mobile_no, aadhaar_no, father_name, police_station_circle, address, city, state, pincode, dob, is_blacklisted, blacklist_reason, created_by_owner_id, person_photo)
values
  -- Guest 1 (Created by Owner 1, currently checked into Owner 1's PG)
  (
    'g1111111-1111-1111-1111-111111111111',
    'Amit Sharma',
    '+919999999901',
    '123456789012',
    'Vijay Sharma',
    'Sector 58 Police Station',
    'Sector 15, Near Metro',
    'Noida',
    'Uttar Pradesh',
    '201301',
    '1995-05-15',
    false,
    null,
    '11111111-1111-1111-1111-111111111111',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e'
  ),
  -- Guest 2 (Created by Owner 2, previously stayed at Owner 1's PG - demonstration of history)
  (
    'g2222222-2222-2222-2222-222222222222',
    'Rohan Verma',
    '+919999999902',
    '987654321098',
    'Suresh Verma',
    'Indiranagar Police Station',
    'Koramangala 4th Block',
    'Bengaluru',
    'Karnataka',
    '560034',
    '1998-11-20',
    false,
    null,
    '11111111-1111-1111-1111-111111111111', -- Initially registered by Owner 1
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde'
  ),
  -- Guest 3 (Blacklisted guest across platform)
  (
    'g3333333-3333-3333-3333-333333333333',
    'Vijay Mallya',
    '+919999999903',
    '111122223333',
    'Vittal Mallya',
    'CBI Special Circle',
    'UB City, Lavelle Road',
    'Bengaluru',
    'Karnataka',
    '560001',
    '1955-12-18',
    true,
    'Absconded with dues and property damage',
    '22222222-2222-2222-2222-222222222222',
    'https://images.unsplash.com/photo-1560250097-0b93528c311a'
  );

-- 5. Stays / Bookings
insert into public.stays (id, person_id, room_id, property_id, owner_id, check_in_date, check_out_date, rental_type_used, agreed_rate, status)
values
  -- Amit Sharma staying at Owner 1's PG (Active stay)
  (
    's1111111-1111-1111-1111-111111111111',
    'g1111111-1111-1111-1111-111111111111',
    'r1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    now() - interval '5 days',
    null,
    'monthly',
    8000.00,
    'active'
  ),
  -- Rohan Verma (Stay 1: Completed stay at Owner 1's PG)
  (
    's2222222-2222-2222-2222-222222222222',
    'g2222222-2222-2222-2222-222222222222',
    'r2222222-2222-2222-2222-222222222222',
    'a1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    now() - interval '45 days',
    now() - interval '15 days',
    'monthly',
    10000.00,
    'checked_out'
  );

-- 6. Payments
insert into public.payments (id, stay_id, person_id, owner_id, payment_type, amount, payment_mode, paid_at, notes, recorded_by)
values
  -- Amit Sharma payments
  (
    'p1111111-1111-1111-1111-111111111111',
    's1111111-1111-1111-1111-111111111111',
    'g1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'deposit',
    2000.00,
    'upi',
    now() - interval '5 days',
    'Security deposit',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'p2222222-2222-2222-2222-222222222222',
    's1111111-1111-1111-1111-111111111111',
    'g1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'advance',
    3000.00,
    'upi',
    now() - interval '5 days',
    'Rent advance',
    '11111111-1111-1111-1111-111111111111'
  ),
  -- Rohan Verma payments
  (
    'p3333333-3333-3333-3333-333333333333',
    's2222222-2222-2222-2222-222222222222',
    'g2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'deposit',
    5000.00,
    'bank_transfer',
    now() - interval '45 days',
    'Deposit',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'p4444444-4444-4444-4444-444444444444',
    's2222222-2222-2222-2222-222222222222',
    'g2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'rent',
    10000.00,
    'cash',
    now() - interval '15 days',
    'Full month rent payment & settlement',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'p5555555-5555-5555-5555-555555555555',
    's2222222-2222-2222-2222-222222222222',
    'g2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'refund',
    5000.00,
    'upi',
    now() - interval '15 days',
    'Refund of deposit at checkout',
    '11111111-1111-1111-1111-111111111111'
  );

-- Trigger public.calculate_stay_billing runs automatically on payment and stays inserts,
-- so public.billing_summary will be automatically updated! Let's double check by doing a manual trigger call if needed, 
-- but Postgres trigger handles it.
select public.calculate_stay_billing('s1111111-1111-1111-1111-111111111111');
select public.calculate_stay_billing('s2222222-2222-2222-2222-222222222222');
