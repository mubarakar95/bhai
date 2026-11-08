-- Supabase Migration: Init Room Rental / PG Management Schema
-- Created: 2026-08-31

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Custom Enums / Check constraints
create type rental_billing_type as enum ('hourly', 'daily', 'monthly');
create type room_status_type as enum ('available', 'full', 'maintenance');
create type payment_category as enum ('deposit', 'advance', 'rent', 'refund');
create type report_category as enum ('blacklist', 'police_complaint', 'flag_for_review');

-- 1. Owners Profile (extends auth.users)
create table public.owners (
    id uuid references auth.users on delete cascade primary key,
    full_name text not null,
    business_name text,
    mobile_no text not null,
    email text not null,
    subscription_plan text default 'free' not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on owners
alter table public.owners enable row level security;

create policy "Owners can view their own profile"
    on public.owners for select
    using (auth.uid() = id);

create policy "Owners can update their own profile"
    on public.owners for update
    using (auth.uid() = id);

-- 2. Properties
create table public.properties (
    id uuid default uuid_generate_v4() primary key,
    owner_id uuid references public.owners(id) on delete cascade not null,
    name text not null,
    address text not null,
    city text not null,
    state text not null,
    pincode text not null,
    geo_latitude double precision,
    geo_longitude double precision,
    property_type text not null, -- PG, hostel, guest house, camp, etc.
    contact_no text not null,
    photos text[] default '{}'::text[] not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.properties enable row level security;

create policy "Owners can manage their own properties"
    on public.properties for all
    using (owner_id = auth.uid());

-- 3. Rooms
create table public.rooms (
    id uuid default uuid_generate_v4() primary key,
    property_id uuid references public.properties(id) on delete cascade not null,
    room_number text not null,
    capacity integer not null,
    current_occupancy integer default 0 not null,
    rental_type text not null check (rental_type in ('daily', 'monthly', 'both')),
    daily_rate numeric(10, 2) default 0.00 not null,
    monthly_rate numeric(10, 2) default 0.00 not null,
    hourly_rate numeric(10, 2) default 0.00 not null,
    status room_status_type default 'available'::room_status_type not null,
    photos text[] default '{}'::text[] not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.rooms enable row level security;

create policy "Owners can manage rooms of their properties"
    on public.rooms for all
    using (
        property_id in (
            select id from public.properties where owner_id = auth.uid()
        )
    );

-- 4. Persons (Guests) - Global/Shared Table
create table public.persons (
    id uuid default uuid_generate_v4() primary key,
    name text not null,
    mobile_no text not null,
    aadhaar_no text not null unique,
    father_name text not null,
    mother_name text,
    wife_name text,
    wife_mobile_no text,
    police_station_circle text not null,
    aadhaar_card_photo text, -- Storage URL
    person_photo text not null, -- Storage URL
    address text not null,
    city text not null,
    state text not null,
    pincode text not null,
    dob date not null,
    is_blacklisted boolean default false not null,
    blacklist_reason text,
    blacklisted_by uuid references public.owners(id),
    blacklisted_at timestamp with time zone,
    created_by_owner_id uuid references public.owners(id) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.persons enable row level security;

-- Read policy allows all authenticated owners to search/lookup guest details
create policy "Authenticated owners can view guest identity details"
    on public.persons for select
    using (auth.role() = 'authenticated');

-- Insert policy allows any authenticated owner to add a guest
create policy "Authenticated owners can create guest profiles"
    on public.persons for insert
    with check (auth.role() = 'authenticated' and created_by_owner_id = auth.uid());

-- Update policy: only the creator can update core details
create policy "Original creator owner can edit guest profiles"
    on public.persons for update
    using (created_by_owner_id = auth.uid());

-- 5. Stays / Bookings
create table public.stays (
    id uuid default uuid_generate_v4() primary key,
    person_id uuid references public.persons(id) on delete cascade not null,
    room_id uuid references public.rooms(id) on delete cascade not null,
    property_id uuid references public.properties(id) on delete cascade not null,
    owner_id uuid references public.owners(id) on delete cascade not null,
    check_in_date timestamp with time zone not null,
    check_out_date timestamp with time zone,
    rental_type_used rental_billing_type not null,
    agreed_rate numeric(10, 2) not null,
    status text default 'active' not null check (status in ('active', 'checked_out', 'cancelled')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.stays enable row level security;

create policy "Owners can manage their own stays"
    on public.stays for all
    using (owner_id = auth.uid());

-- 6. Payments
create table public.payments (
    id uuid default uuid_generate_v4() primary key,
    stay_id uuid references public.stays(id) on delete cascade not null,
    person_id uuid references public.persons(id) on delete cascade not null,
    owner_id uuid references public.owners(id) on delete cascade not null,
    payment_type payment_category not null,
    amount numeric(10, 2) not null,
    payment_mode text not null, -- cash, upi, bank_transfer, card
    paid_at timestamp with time zone default timezone('utc'::text, now()) not null,
    notes text,
    recorded_by uuid references auth.users(id) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.payments enable row level security;

create policy "Owners can manage payments under their stays"
    on public.payments for all
    using (owner_id = auth.uid());

-- 7. Billing Summary (Derived/Materialized per stay)
create table public.billing_summary (
    stay_id uuid references public.stays(id) on delete cascade primary key,
    total_amount_due numeric(10, 2) default 0.00 not null,
    total_paid numeric(10, 2) default 0.00 not null,
    pending_amount numeric(10, 2) default 0.00 not null,
    last_calculated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.billing_summary enable row level security;

create policy "Owners can view billing summaries of their stays"
    on public.billing_summary for select
    using (
        stay_id in (
            select id from public.stays where owner_id = auth.uid()
        )
    );

-- 8. Reports Log
create table public.reports_log (
    id uuid default uuid_generate_v4() primary key,
    person_id uuid references public.persons(id) on delete cascade not null,
    reported_by_owner_id uuid references public.owners(id) on delete cascade not null,
    report_type report_category not null,
    description text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.reports_log enable row level security;

create policy "Owners can view and create reports they submitted"
    on public.reports_log for all
    using (reported_by_owner_id = auth.uid());

-- 9. Public Stay History View (excludes financial details)
create or replace view public.guest_stay_history as
select 
    s.id as stay_id,
    s.person_id,
    s.check_in_date,
    s.check_out_date,
    s.status,
    p.property_type,
    p.name as property_name,
    p.city as property_city,
    r.room_number
from public.stays s
join public.properties p on s.property_id = p.id
join public.rooms r on s.room_id = r.id;

grant select on public.guest_stay_history to authenticated;


--------------------------------------------------------------------------------
-- DATABASE FUNCTIONS & TRIGGERS
--------------------------------------------------------------------------------

-- Automatically sync Owners from auth.users on SignUp
create or replace function public.handle_new_owner()
returns trigger as $$
begin
  insert into public.owners (id, full_name, business_name, mobile_no, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'New Owner'),
    new.raw_user_meta_data->>'business_name',
    coalesce(new.raw_user_meta_data->>'mobile_no', coalesce(new.phone, '')),
    coalesce(new.email, '')
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_owner();

-- Billing calculation function
create or replace function public.calculate_stay_billing(target_stay_id uuid)
returns void as $$
declare
    v_check_in timestamp with time zone;
    v_check_out timestamp with time zone;
    v_rental_type rental_billing_type;
    v_agreed_rate numeric(10,2);
    v_hours_stayed double precision;
    v_total_due numeric(10,2) := 0.00;
    v_total_paid numeric(10,2) := 0.00;
    v_owner_id uuid;
begin
    -- Get stay details
    select check_in_date, check_out_date, rental_type_used, agreed_rate, owner_id
    into v_check_in, v_check_out, v_rental_type, v_agreed_rate, v_owner_id
    from public.stays
    where id = target_stay_id;

    if not found then
        return;
    end if;

    -- If stay is still active, use current timestamp as check-out for real-time due calculation
    v_check_out := coalesce(v_check_out, now());

    -- Calculate duration in hours
    v_hours_stayed := extract(epoch from (v_check_out - v_check_in)) / 3600.0;
    if v_hours_stayed < 0 then
        v_hours_stayed := 0;
    end if;

    -- Calculate amount due based on billing type
    case v_rental_type
        when 'hourly' then
            v_total_due := v_agreed_rate * v_hours_stayed;
        when 'daily' then
            -- Pro-rata hourly base: (rate / 24) * hours
            v_total_due := (v_agreed_rate / 24.0) * v_hours_stayed;
        when 'monthly' then
            -- Pro-rata hourly base: (rate / 720) * hours
            v_total_due := (v_agreed_rate / 720.0) * v_hours_stayed;
    end case;

    -- Calculate payments total (deposit + advance + rent - refund)
    select coalesce(sum(
        case 
            when payment_type = 'refund' then -amount
            else amount
        end
    ), 0.00)
    into v_total_paid
    from public.payments
    where stay_id = target_stay_id;

    -- Insert or Update billing_summary
    insert into public.billing_summary (stay_id, total_amount_due, total_paid, pending_amount, last_calculated_at)
    values (
        target_stay_id, 
        round(v_total_due, 2), 
        round(v_total_paid, 2), 
        round(v_total_due - v_total_paid, 2), 
        now()
    )
    on conflict (stay_id) do update
    set 
        total_amount_due = round(v_total_due, 2),
        total_paid = round(v_total_paid, 2),
        pending_amount = round(v_total_due - v_total_paid, 2),
        last_calculated_at = now();

end;
$$ language plpgsql security definer;

-- Trigger to calculate billing whenever payments change
create or replace function public.on_payment_change()
returns trigger as $$
begin
    perform public.calculate_stay_billing(coalesce(new.stay_id, old.stay_id));
    return new;
end;
$$ language plpgsql security definer;

create or replace trigger trigger_on_payment_change
    after insert or update or delete on public.payments
    for each row execute procedure public.on_payment_change();

-- Trigger to calculate billing when stay check-out / rates are updated
create or replace function public.on_stay_change()
returns trigger as $$
begin
    perform public.calculate_stay_billing(new.id);
    return new;
end;
$$ language plpgsql security definer;

create or replace trigger trigger_on_stay_change
    after update of check_out_date, agreed_rate, rental_type_used on public.stays
    for each row execute procedure public.on_stay_change();

-- Blacklist guest function (updates person & logs report)
create or replace function public.blacklist_guest(
    p_person_id uuid,
    p_reason text,
    p_report_type report_category
)
returns void as $$
begin
    -- Check if owner is authenticated
    if auth.uid() is null then
        raise exception 'Not authorized';
    end if;

    -- Update persons table
    update public.persons
    set 
        is_blacklisted = true,
        blacklist_reason = p_reason,
        blacklisted_by = auth.uid(),
        blacklisted_at = now()
    where id = p_person_id;

    -- Log report
    insert into public.reports_log (person_id, reported_by_owner_id, report_type, description)
    values (p_person_id, auth.uid(), p_report_type, p_reason);
end;
$$ language plpgsql security definer;


--------------------------------------------------------------------------------
-- INDEXES FOR PERFORMANCE
--------------------------------------------------------------------------------
create index if not exists idx_persons_aadhaar_no on public.persons(aadhaar_no);
create index if not exists idx_stays_person_id on public.stays(person_id);
create index if not exists idx_stays_room_id on public.stays(room_id);
create index if not exists idx_stays_owner_id on public.stays(owner_id);
create index if not exists idx_stays_check_in_date on public.stays(check_in_date);
create index if not exists idx_payments_stay_id on public.payments(stay_id);
create index if not exists idx_payments_owner_id on public.payments(owner_id);
create index if not exists idx_rooms_property_id on public.rooms(property_id);
create index if not exists idx_properties_owner_id on public.properties(owner_id);
