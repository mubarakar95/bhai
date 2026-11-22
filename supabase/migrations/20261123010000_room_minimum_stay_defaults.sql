-- Migration: per-room minimum stay (days) and minimum charge, with defaults
-- Date: 2026-11-23
--
-- The app already sent minimum_days / minimum_charge, but the live rooms table never
-- had these columns (an earlier migration was not applied), so saving a room online
-- failed. Defaults: minimum_days = 15, minimum_charge = half the monthly rate.

alter table public.rooms
  add column if not exists minimum_days integer not null default 15,
  add column if not exists minimum_charge numeric(10, 2) not null default 0;

alter table public.rooms drop constraint if exists rooms_minimum_days_range;
alter table public.rooms add constraint rooms_minimum_days_range
  check (minimum_days between 0 and 30) not valid;
alter table public.rooms drop constraint if exists rooms_minimum_charge_nonneg;
alter table public.rooms add constraint rooms_minimum_charge_nonneg
  check (minimum_charge >= 0) not valid;

-- Fill the defaults for existing rooms
update public.rooms
   set minimum_days = 15
 where minimum_days is null or minimum_days <= 0;

update public.rooms
   set minimum_charge = round(coalesce(monthly_rate, 0) / 2, 2)
 where minimum_charge is null or minimum_charge <= 0;

-- New rooms: a blank / zero value means "use the default"
create or replace function public.rooms_apply_minimum_defaults()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.minimum_days is null or new.minimum_days <= 0 then
    new.minimum_days := 15;
  end if;
  if new.minimum_charge is null or new.minimum_charge <= 0 then
    new.minimum_charge := round(coalesce(new.monthly_rate, 0) / 2, 2);
  end if;
  return new;
end;
$$;

revoke execute on function public.rooms_apply_minimum_defaults() from public, anon, authenticated;

drop trigger if exists rooms_apply_minimum_defaults on public.rooms;
create trigger rooms_apply_minimum_defaults
  before insert or update on public.rooms
  for each row execute function public.rooms_apply_minimum_defaults();
