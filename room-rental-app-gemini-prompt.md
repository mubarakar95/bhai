# Prompt for Gemini: Room Rental / PG Management App

Copy everything below into Gemini as your build prompt.

---

## 1. Project Overview

Build a **multi-property room rental / PG (paying guest) management application** for property owners who rent out rooms on a **daily or monthly basis**. The app must track guests (with government-ID-grade detail for police verification), room allocation, billing, payments, check-in/check-out, and produce police-ready PDF reports. A future **Admin Console** will manage all owners/properties platform-wide, so design the data model with a super-admin role in mind from day one.

**Backend:** Supabase (Postgres + Auth + Storage + Row Level Security + Edge Functions)
**Frontend:** (state your preferred framework — e.g., Flutter, React Native, or React web — Gemini should ask if unspecified)

---

## 2. User Roles

| Role | Access |
|---|---|
| **Owner** | Signs up, manages their own properties, rooms, guests, bookings, payments, reports |
| **Staff** (optional, future) | Owner can invite staff with restricted permissions per property |
| **Super Admin** (future Admin Console) | Cross-tenant visibility into all owners, properties, and guests; manages platform settings, blacklist review |

---

## 3. Core Data Model (Supabase / Postgres)

Design normalized tables with UUID primary keys, `created_at`/`updated_at` timestamps, and soft-delete (`is_deleted`/`deleted_at`) where appropriate.

### 3.1 `owners` (extends `auth.users`)
- id (FK to auth.users)
- full_name, business_name, mobile_no, email
- subscription/plan fields (future-proofing)

### 3.2 `properties`
- id, owner_id (FK)
- name, address, city, state, pincode
- geo-coordinates (optional, for map view)
- property_type (e.g., PG, hostel, guest house, camp)
- contact_no
- photos (array of Storage URLs)

### 3.3 `rooms`
- id, property_id (FK)
- room_number/name
- capacity (integer)
- current_occupancy (derived or maintained)
- rental_type (`daily` | `monthly` | `both`)
- daily_rate, monthly_rate, hourly_rate
- status (`available`, `full`, `maintenance`)
- photos

### 3.4 `persons` (guests) — the sensitive, ID-grade table
- id
- **name*** (text, required)
- **photo*** (Storage URL, required)
- **mobile_no*** (required)
- **aadhaar_no*** (required, **unique across the whole platform** — this is what enables cross-property history lookup)
- **father_name*** (required)
- mother_name (optional)
- wife_name, wife_mobile_no (optional)
- **police_station_circle*** (required)
- aadhaar_card_photo (Storage URL)
- person_photo (Storage URL) — distinct from the primary photo if needed
- **address***, **city***, **state***, **pincode***, **dob*** (all required)
- is_blacklisted (boolean, default false)
- blacklist_reason (text, nullable)
- blacklisted_by (owner_id who flagged), blacklisted_at
- created_by_owner_id (first owner who ever added this Aadhaar)

> **Design note:** Because Aadhaar is unique platform-wide, `persons` should be a **global table, not owner-scoped**. When any owner searches/adds a guest by Aadhaar number, the system checks if that Aadhaar already exists:
> - If it exists → show the existing record + full stay history across *all* properties/owners (read-only, non-editable core identity fields) and let the current owner create a new **stay/booking** against that same person.
> - If it doesn't exist → create a new person record.
> This is the "previous stay history" feature the user described. **Flag to Gemini: this cross-owner visibility of guest history is a deliberate product decision (for police-verification purposes) — implement clear RLS so owners can see a guest's stay history but NOT another owner's business/financial data.**

### 3.5 `stays` / `bookings` (the join between person, room, and time period)
- id, person_id (FK), room_id (FK), property_id (FK), owner_id (FK)
- check_in_date, check_in_time
- check_out_date, check_out_time (nullable while still checked in)
- rental_type_used (`daily` | `monthly` | `hourly`)
- agreed_rate
- status (`active`, `checked_out`, `cancelled`)

### 3.6 `payments`
- id, stay_id (FK), person_id (FK), owner_id (FK)
- payment_type (`deposit`, `advance`, `rent`, `refund`)
- amount
- payment_mode (`cash`, `upi`, `bank_transfer`, `card`, etc.)
- paid_at (timestamp)
- notes
- recorded_by (owner/staff id)

### 3.7 `billing_summary` (derived/materialized, per stay)
- stay_id
- total_amount_due (calculated from hourly/daily/monthly rate × duration)
- total_paid
- pending_amount (auto-calculated: due − paid)
- last_calculated_at

> **Billing logic to specify explicitly to Gemini:**
> - Hourly rate is the base unit for calculation, even for daily/monthly stays (e.g., daily rate ÷ 24 = effective hourly rate, or store hourly rate directly and derive daily/monthly).
> - On check-out, calculate actual duration in hours and compute the amount due, reconciling against deposits/advances already paid.
> - Ask Gemini to build this as a Postgres function or Edge Function (not just client-side) so the numbers are trustworthy and consistent — this matters since it feeds police reports and payment disputes.

### 3.8 `reports_log` (for the police "report/blacklist" button)
- id, person_id (FK), reported_by_owner_id
- report_type (`blacklist`, `police_complaint`, `flag_for_review`)
- description
- created_at

---

## 4. Screens / Features

### 4.1 Onboarding & Auth
- Owner sign-up/login via Supabase Auth (email/mobile OTP)
- Add property → add rooms under property (with capacity, rental type, rates)

### 4.2 Dashboard
- Consolidated stats: total properties, total rooms, occupancy %, total guests currently checked in, pending payments total, recent check-ins/check-outs
- Drill-down: Property list → tap property → room list → tap room → persons currently in that room

### 4.3 All Guests Screen
- Searchable/filterable list of all guests (by name, Aadhaar, mobile, property, room, date range, blacklist status)
- Tap guest → Guest Detail View

### 4.4 Guest Detail View
- All personal details fields listed above
- Full-screen photo viewer (tap to expand photo and Aadhaar photo)
- Current pending amount (calculated, prominent)
- Cash/payment history table (all payments across all stays)
- Check-in/check-out history (all stays, across properties if applicable)
- Cross-property stay history section (powered by Aadhaar-based lookup)
- "Report / Blacklist" button → opens `reports_log` entry form

### 4.5 Add/Allocate Guest Flow
- Search by Aadhaar first → auto-fill if existing person found, show history
- Else, full new-guest form with all required (*) fields
- Assign to property → room (respecting room capacity)
- Set rental type (daily/monthly), rate, check-in date/time
- Capture initial deposit/advance payment

### 4.6 Payments Screen (per guest or per stay)
- Add payment (type, amount, mode, date)
- Auto-updates pending_amount

### 4.7 Check-in / Check-out Flow
- Check-in: date + time capture, room capacity validation
- Check-out: date + time capture, triggers final billing calculation, shows settlement summary (due vs paid vs refund)

### 4.8 Reports (PDF Export)
- Filter by: date range, property/camp, room, blacklist status
- Export as PDF containing all police-required fields per guest (name, Aadhaar, photo, address, police station circle, stay dates, etc.)
- Should be generatable from both the All Guests screen (filtered list) and per-property/per-room views

### 4.9 Settings
- Owner profile, property management (edit/deactivate), staff invites (future), notification preferences, subscription/plan info (future)

---

## 5. Supabase-Specific Implementation Notes

- **Row Level Security (RLS):** owners can only read/write their own `properties`, `rooms`, `stays`, `payments`. `persons` table needs special RLS: allow read of core identity + stay-history fields to any authenticated owner (for the Aadhaar lookup feature), but restrict edits to the original creator or shared update rules — decide and document this explicitly.
- **Storage:** separate buckets for `person-photos`, `aadhaar-photos`, `property-photos`, with signed URLs and access policies matching the RLS above.
- **Edge Functions:** use for billing calculations, PDF generation (or a report-generation service), and Aadhaar-based lookup/merge logic.
- **Indexes:** unique index on `persons.aadhaar_no`; indexes on `stays.check_in_date`, `stays.check_out_date`, `stays.property_id`, `rooms.property_id` for fast filtering.
- **Audit trail:** consider a lightweight audit log table for edits to `persons` and `payments`, since this data may be scrutinized by police/legal requests.

---

## 6. Non-Functional Requirements

- Aadhaar numbers and photos are sensitive personal data — encrypt at rest where Supabase allows, restrict Storage bucket access via signed URLs, and never expose Aadhaar numbers in client-side logs or analytics.
- Design the schema so a future **Admin Console** (super-admin role) can query across all owners without restructuring tables — use a consistent `owner_id`/`property_id` tagging everywhere.
- Mobile-first responsive UI (assume most owners will use this on a phone).
- Offline-tolerant check-in/check-out capture is a nice-to-have if using Flutter/React Native.

---

## 7. UI/UX Design Guidelines

This is an **operational tool**, not a marketing site — it will mostly be used quickly, one-handed, at a front desk, often while a guest is standing there. Design for speed and clarity first, with a visual identity that feels official and trustworthy (it's holding ID documents and police-facing data), not generic SaaS or playful.

**Color**
- Background: `#F3F5F4` (cool off-white paper, not warm cream)
- Ink / primary: `#1F2A44` (deep navy — trust, headers, primary actions)
- Verified / checked-in status: `#2F6F5E` (muted teal-green)
- Alert / blacklist / overdue: `#8C2F2F` (muted maroon — reserved *only* for blacklist flags and overdue payments, never decorative)
- Text: `#2B2B2E`; dividers/borders: `#D8D5CE`

**Type**
- Headers: a slab serif (e.g., a Roboto Slab / Zilla Slab class typeface) — gives the register/ledger feel of an official record book.
- Body & data tables: a clean grotesque sans with good tabular-figure support (e.g., IBM Plex Sans or Inter) — needed for aligned numbers in payment and occupancy tables.
- No all-caps labels, no single-word accent styling in headings — sentence case throughout.

**Layout**
- Left-aligned, list/table-dense — not card-grid-heavy. Think ledger pages, not a dashboard full of rounded stat cards.
- Drill-down navigation mirrors the real hierarchy: Property → Rooms → Persons, shown as nested lists rather than modals, so an owner can always tell where they are.
- Guest detail view: identity block (photo, Aadhaar photo, core details) visually distinct from the financial block (pending amount, payment history) — different background tint or bordered "verification card" treatment for the identity block, since that data carries different weight and sensitivity.

**Principles specific to this app**
1. **Status is never color-only.** Blacklisted, pending payment, checked-in/out must each pair a color with an icon and a text label — this data may be read quickly under bad lighting or by someone who is colorblind.
2. **Financial figures get visual weight.** Pending amount is the single most-checked number on the guest detail screen — give it a prominent, tabular-figure treatment, not buried in a list.
3. **The identity/ID module should feel secure and official**, not like a generic profile card — this is what distinguishes the guest-verification part of the app from a typical CRM.
4. **Large touch targets** for check-in/check-out and payment-entry actions — these happen fast, often mid-conversation with a guest.
5. Respect reduced-motion and keep any animation limited to one deliberate moment (e.g., the check-out settlement reveal) — no hover/entrance animation sprinkled across every list row.

---

## 8. Ask Gemini To Deliver

1. Full Postgres schema (SQL) with RLS policies for Supabase.
2. Suggested folder/app architecture for the chosen frontend framework.
3. A short design-token summary (colors, type, layout) following Section 7, adapted to the chosen frontend framework's styling approach.
4. Key screens as code (Dashboard, Guest Detail, Add Guest/Allocate, Payments, Reports).
5. The billing calculation function (hourly-based, reconciling deposits/advances).
6. The PDF report generation approach (client-side library vs. Edge Function/server-side).
7. A migration/seed script with sample data for testing.
