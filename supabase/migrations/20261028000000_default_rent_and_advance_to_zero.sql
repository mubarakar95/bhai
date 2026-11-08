-- Migration: Set default rent and customer advance to zero for existing users
-- Date: 2026-10-28
-- Description: Sets agreed_rate to 0 for historical stays that had no explicit payments recorded,
-- and ensures rooms default to 0 rate so existing users start with zero rent and advance debt.

UPDATE public.stays 
SET agreed_rate = 0 
WHERE id NOT IN (SELECT stay_id FROM public.payments);
