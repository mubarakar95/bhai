-- Migration: Add room minimum days and minimum charge for monthly rentals
-- Created at: 2026-11-04

-- 1. Add minimum_days and minimum_charge columns to public.rooms
alter table public.rooms
  add column if not exists minimum_days integer default 0 not null,
  add column if not exists minimum_charge numeric(10, 2) default 0.00 not null;

-- 2. Update calculate_stay_billing function to take into account room minimum days and minimum charge for monthly rentals
create or replace function public.calculate_stay_billing(target_stay_id uuid)
returns void as $$
declare
    v_check_in timestamp with time zone;
    v_check_out timestamp with time zone;
    v_rental_type rental_billing_type;
    v_agreed_rate numeric(10,2);
    v_hours_stayed double precision;
    v_days_stayed integer;
    v_total_due numeric(10,2) := 0.00;
    v_total_paid numeric(10,2) := 0.00;
    v_owner_id uuid;
    v_room_id uuid;
    v_min_days integer := 0;
    v_min_charge numeric(10,2) := 0.00;
begin
    -- Get stay details
    select check_in_date, check_out_date, rental_type_used, agreed_rate, owner_id, room_id
    into v_check_in, v_check_out, v_rental_type, v_agreed_rate, v_owner_id, v_room_id
    from public.stays
    where id = target_stay_id;

    if not found then
        return;
    end if;

    -- If stay is still active, use current timestamp as check-out for real-time due calculation
    v_check_out := coalesce(v_check_out, now());

    -- Calculate duration in hours and days
    v_hours_stayed := extract(epoch from (v_check_out - v_check_in)) / 3600.0;
    if v_hours_stayed < 0 then
        v_hours_stayed := 0;
    end if;

    v_days_stayed := ceil(v_hours_stayed / 24.0);
    if v_days_stayed < 1 then
        v_days_stayed := 1;
    end if;

    -- Get room minimum days and charge if applicable
    if v_room_id is not null then
        select coalesce(minimum_days, 0), coalesce(minimum_charge, 0.00)
        into v_min_days, v_min_charge
        from public.rooms
        where id = v_room_id;
    end if;

    -- Calculate amount due based on billing type
    case v_rental_type
        when 'hourly' then
            v_total_due := v_agreed_rate * v_hours_stayed;
        when 'daily' then
            -- Pro-rata hourly base: (rate / 24) * hours
            v_total_due := (v_agreed_rate / 24.0) * v_hours_stayed;
        when 'monthly' then
            -- If room has minimum days and minimum charge configured, and stay is <= min days
            if v_min_days > 0 and v_min_charge > 0 and v_days_stayed <= v_min_days then
                v_total_due := v_min_charge;
            else
                -- Full month billing base
                v_total_due := (v_agreed_rate / 720.0) * v_hours_stayed;
            end if;
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
