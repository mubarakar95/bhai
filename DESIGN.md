# Design System Tokens — Room Rental App (Soft Pastel Glassmorphic)

---
name: Soft Pastel Glass
colors:
  brand-blue: '#347AE2'
  background-start: '#E2EDFC'
  background-end: '#EDF4FE'
  surface-glass: '#FFFFFF'
  surface-glass-opacity: '0.90'
  surface-card: '#FFFFFF'
  text-primary: '#111111'
  text-secondary: '#55555C'
  text-muted: '#8E8E93'
  primary-pill: '#111111'
  on-primary-pill: '#FFFFFF'
  accent-green: '#22C55E'
  verified-bg: '#DCFCE7'
  verified-text: '#15803D'
  accent-red: '#EF4444'
  alert-bg: '#FEE2E2'
  alert-text: '#B91C1C'
  neutral-pill: '#F1F5F9'
  neutral-pill-text: '#334155'
  border-soft: '#E2E8F0'
  divider: '#CBD5E1'

typography:
  font-family: Nunito
  display-lg:
    fontSize: 32px
    fontWeight: '800'
    lineHeight: '1.2'
  headline-md:
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '1.3'
  title-sm:
    fontSize: 16px
    fontWeight: '700'
    lineHeight: '1.4'
  body-md:
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.5'
  label-sm:
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.2'

rounded:
  sm: 8px
  md: 16px
  lg: 24px
  xl: 28px
  full: 9999px

shadows:
  soft-glass:
    color: '#000000'
    opacity: 0.06
    blurRadius: 20px
    spreadRadius: 0px
    offsetY: 8px

---

## 1. Overview & Aesthetics

The design system shifts the Room Rental Application from a cold administrative ledger aesthetic into a warm, soft, glassmorphic experience. It features:
- **Soft Pastel Canvas**: A gentle diagonal gradient from blush pink (`#FBE4EA`) to light lavender (`#E7E2F8`).
- **Frosted Glass Cards**: High opacity white surfaces (90–95%) with soft 24–28px rounded corners and wide, subtle drop shadows.
- **Solid Black Active Pills**: High-contrast `#111111` pill buttons and active tab/filter chips with crisp white text.
- **Rounded Sans Typography**: Warm, readable Nunito font for friendly headers, titles, and body text, with tabular figures applied for financial metrics.

## 2. Police & Aadhaar Verification Adaptation Guidelines

Because this app handles official guest records, identity verification details, and police reporting, identity elements require strict trust patterns:
- **Structured ID Cards**: Guest identity and Aadhaar photo modules maintain clear visual hierarchy with subtle borders and clear section headers.
- **Icon + Label Badges**: Status badges must **never rely on color alone**. Every status pairs an explicit icon with clear text (e.g. green checkmark + `"VERIFIED"`, red alert icon + `"BLACKLISTED"`).
- **Audit-Ready Export**: PDF and Report screens provide explicit, highly visible download and date-filtering controls.

## 3. UI Component Tokens

### Buttons & Selection
- **Active / Primary Button**: Solid black pill (`#111111`) with white text, full radius (`9999px`).
- **Secondary / Action Chip**: Soft gray pill (`#F1F5F9`) with dark slate text (`#334155`).
- **Filter Chips**: Inactive chips use neutral light-gray background; selected chip transforms into solid black pill with white text.

### Stat Cards & Indicators
- **Occupancy Ring**: Dual-tone ring with soft pastel green track and active green fill.
- **Numeric Tables**: Use tabular figures (`fontFeatures: [FontFeature.tabularFigures()]`) for monetary balances and payment histories.

### Avatars & Media
- **Guest Photos**: Circular avatars with a thin green ring for verified guests or red ring for blacklisted guests.
- **Photo Viewer**: Edge-to-edge full-screen viewer with dark scrim overlay and translucent rounded close button.
