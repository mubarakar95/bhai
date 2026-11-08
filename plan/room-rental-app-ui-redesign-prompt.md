# Prompt for Gemini: Full UI Redesign via Google Stitch MCP — Room Rental App

Copy everything below into Gemini (with Stitch MCP connected). Attach the reference screenshot (the pastel language-app UI) when you send this — Stitch can extract a "Design DNA" from an image input, and this prompt gives it explicit tokens too, so both stay consistent.

---

## 1. Goal

The app is functionally complete but visually plain. Redesign **every screen** to match the modern, soft, rounded aesthetic of the attached reference image, while keeping the app's actual working parts (data density, ID verification module, status flags) legible and trustworthy — this app handles police-facing guest records, not just a consumer app, so a few reference elements need a slight adaptation (noted per-screen below).

**Workflow:**
1. Feed the attached reference image into Stitch to establish a Design DNA / style guide.
2. Use the explicit tokens in Section 2 below to lock down the palette/type/shape so every screen — including ones with no equivalent in the reference — stays consistent.
3. Generate each screen listed in Section 4 through Stitch, one at a time, reusing the same Design DNA.
4. Export as Tailwind CSS/React and integrate into the existing codebase.
5. Produce a `DESIGN.md` documenting the final tokens so future screens stay consistent without re-prompting.

---

## 2. Design Tokens (extracted from reference + adapted)

**Background**
- Soft diagonal gradient, blush pink → light lavender (e.g. `#FBE4EA` → `#E7E2F8`)
- Subtle, never busy — this is the canvas behind floating cards, not a pattern

**Surfaces / Cards**
- Frosted glass cards: white at ~90% opacity, backdrop blur, large corner radius (24–28px)
- Soft, wide, low-opacity drop shadows (no hard borders)

**Type**
- A rounded geometric sans for headings (e.g. Poppins/Quicksand-class) — friendly, modern
- Same family, regular weight, for body text
- Tabular figures for any numeric table (payments, balances) so columns align — the reference is chat/task-based and won't show this, but it matters for this app

**Color accents**
- Primary "selected/active" state: solid black pill (`#111111`) with white text — mirrors the reference's "Make sentences" active list item and outgoing chat bubbles
- Positive/verified: soft green circle badge with checkmark (mirrors the reference's checkmark badges and the "75%" progress ring — reuse this exact pattern for guest verification status)
- Alert/destructive: soft coral-red circle (mirrors the reference's red "end call" button) — reserve for blacklist flags and the check-out/cancel actions
- Neutral icon buttons: translucent light-gray rounded pills (mirrors the video-call control row)

**Shape language**
- Rounded everywhere — buttons, cards, avatars, input fields, filter chips
- Circular avatar photos with a thin soft-colored ring when verified

---

## 3. Where the reference style needs adapting (not copying 1:1)

- The reference is a light social/edtech app with real user photos of models; this app displays **actual guest ID photos and Aadhaar images**, which need to read as secure records, not lifestyle photography. Keep the same glass-card/rounded language, but give the identity/Aadhaar module a distinct treatment: a slightly more structured card (visible thin border, small "Verified"/"Unverified" badge using the green-checkmark pattern from the reference) so it doesn't blend into decorative content.
- The reference's chat screen dark/light bubble contrast maps well to **selected vs. unselected states** elsewhere in this app (active filter chips, selected room/tab, active nav item) — reuse that pattern, not literal chat bubbles, since this app has no chat feature.
- Status must never rely on color alone (accessibility) — every colored badge (verified, blacklisted, pending payment) pairs with an icon + short text label, unlike the reference's color-only progress ring.

---

## 4. Screens to Generate (reuse same Design DNA across all)

1. **Login / Owner sign-up**
2. **Dashboard** — consolidated stats as soft glass stat cards; property list below with occupancy shown as a progress ring (reuse the reference's "75%" ring pattern)
3. **Property → Rooms → Persons drill-down** — nested list views, same card language, room capacity shown as a small filled/outline indicator
4. **All Guests screen** — search bar + filter chips (rounded pill chips, black when active — reuse reference's "Choose a task" list selection style)
5. **Guest Detail view** — identity/Aadhaar module (see Section 3 adaptation) + separate financial card showing pending balance prominently + payment history table + check-in/out history + full-screen photo viewer (edge-to-edge, dark scrim, close button styled like the reference's video-call back button)
6. **Add / Allocate Guest form** — multi-step or single scroll form, rounded inputs, state dropdown as a searchable rounded picker
7. **Payments screen** — add-payment rounded modal/sheet, payment history as a clean list
8. **Check-in / Check-out flow** — settlement summary screen using the same soft card + tabular-figure numbers
9. **Reports / PDF export screen** — filter chips for date, check-in range, check-out range, property, room; generate + download button clearly visible (fixing the earlier no-save-button bug)
10. **Settings** — font-size control, profile, list-style nav to About Us / Contact Us
11. **About Us** — simple centered content page, same soft gradient background
12. **Contact Us** — Mubarak Technologies, Kollam, Kerala, mubaraktech.com, styled as a simple info card

---

## 5. Deliverables

1. `DESIGN.md` — final color/type/shape tokens as Tailwind config values
2. Exported code (Tailwind/React) per screen from Stitch
3. A short note on any screen where the reference aesthetic had to be adapted for legibility/trust reasons, so the design stays defensible if questioned later (e.g., during a police audit of the reporting feature)
