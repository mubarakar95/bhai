# Follow-up Prompt for Gemini: Bug Fixes & Enhancements — Room Rental App

Copy everything below into Gemini. This is a follow-up round after testing the app built from the original spec — organized into **Bug Fixes** (things that should already work but don't) and **New Features** (additions not in the original spec).

---

## A. Bug Fixes

### A1. Guest Detail Page — Edit not working
The Guest Detail screen has no working way to edit a guest's details after creation.
- Add an "Edit" action on the Guest Detail page that opens the same field set used in "Add Guest" (pre-filled with existing data).
- On save, update the `persons` record and show a confirmation.
- **Decide and confirm with me**: since a person's Aadhaar record can be shared across properties/owners (per the cross-owner history design), should edits to core identity fields (name, Aadhaar no, DOB, etc.) be restricted to the owner who originally created the record, or open to any owner who has that guest checked in? Flag this to me before assuming.

### A2. PDF Export — No save/download button
The generated PDF report has no way to save or download it.
- After generating the PDF, show a clear "Download" / "Save PDF" button (and "Share" if on mobile).
- Confirm the file is actually written to device storage / offered via the OS share sheet, not just rendered in-app with no exit path.

### A3. Pending Balance not showing on Guest Detail
The pending amount field described in the original spec (`billing_summary.pending_amount`) isn't displaying.
- Check that the pending-balance calculation (total due − total paid, from the billing function) is actually being called and returned for the guest's active/most recent stay.
- Display it prominently on the Guest Detail page as originally specified, with clear labeling (e.g., "Pending: ₹X") — not buried in a list.
- If a guest has multiple stays, clarify whether pending balance shown is for the **current active stay** or a **lifetime total across all stays** — implement and label accordingly.

### A4. Home Dashboard — Refresh button not working
- The dashboard's refresh action should re-fetch dashboard stats (occupancy, pending payments, recent check-ins/check-outs) from Supabase and re-render — check that the refresh handler is actually wired to a data re-fetch and not a no-op or a UI-only spinner.
- Add a pull-to-refresh gesture as well if this is a mobile app, in addition to the button.

### A5. Guest Detail Page — Profile section overlapping
The profile/photo area on the Guest Detail page has a layout bug where elements overlap.
- Likely cause: fixed-position or absolutely-positioned photo/text elements not accounting for variable content length (e.g., long names, missing photos, different screen sizes).
- Fix the layout to be responsive: photo, name, and status badges should reflow properly on both small and large screens, and gracefully handle a missing photo (placeholder) without breaking the layout.
- Test specifically on the smallest supported screen width.

---

## B. New Features

### B1. Text font size customization
- Add a font-size setting (e.g., Small / Medium / Large) in the Settings page.
- This should scale text app-wide (not just one screen) — implement via a global text-scale setting (e.g., a theme/typography multiplier) rather than hardcoding sizes per screen, so it stays maintainable.

### B2. State selection — dropdown menu needed
- Replace the free-text "state" field (in guest address details) with a dropdown/picker populated with the standard list of Indian states and union territories.
- Keep it a searchable dropdown if the framework supports it, since there are ~36 entries.

### B3. Check-in / Check-out date filters in PDF generation
- The PDF report filter panel currently supports date, camp/property, and room (per original spec) — add **check-in date range** and **check-out date range** as additional, independent filters.
- Clarify with me: should the existing generic "date" filter be replaced by these two, or kept as a separate filter alongside them? Recommend replacing the ambiguous single "date" filter with explicit check-in/check-out range filters, since that matches what police reports actually ask for.

### B4. About Us page
- Add a simple "About Us" static page accessible from Settings.
- Content should describe the app's purpose (room rental/PG management with police-verification support) — ask me for final copy, or draft a short 2–3 paragraph placeholder for me to review.

### B5. Contact Us / Developer Details page
- Add a "Contact Us" static page accessible from Settings, showing:
  - Developer/company name: **Mubarak Technologies**
  - Location: Kollam, Kerala, India
  - Website: **mubaraktech.com**
- Include a tappable link to the website, and optionally a contact email/phone field (ask me for these if we want them included).

---

## C. Priority Suggestion (adjust as needed)

1. **Fix first (blocking/data-integrity issues):** A3 (pending balance), A1 (edit), A5 (layout bug)
2. **Fix next (usability):** A2 (PDF save), A4 (refresh)
3. **Then features:** B3 (PDF filters — extends existing report feature), B2 (state dropdown), B1 (font size)
4. **Low priority / content pages:** B4 (About Us), B5 (Contact Us)
