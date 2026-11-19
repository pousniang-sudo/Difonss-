---
name: Difonssé Auto Commerce
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#45464d'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#76777d'
  outline-variant: '#c6c6cd'
  surface-tint: '#565e74'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#131b2e'
  on-primary-container: '#7c839b'
  inverse-primary: '#bec6e0'
  secondary: '#855300'
  on-secondary: '#ffffff'
  secondary-container: '#fea619'
  on-secondary-container: '#684000'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#002113'
  on-tertiary-container: '#009668'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2fd'
  primary-fixed-dim: '#bec6e0'
  on-primary-fixed: '#131b2e'
  on-primary-fixed-variant: '#3f465c'
  secondary-fixed: '#ffddb8'
  secondary-fixed-dim: '#ffb95f'
  on-secondary-fixed: '#2a1700'
  on-secondary-fixed-variant: '#653e00'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '800'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 30px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 26px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
  price-display:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '800'
    lineHeight: 28px
    letterSpacing: -0.02em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1rem
  margin-mobile: 0.75rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system establishes a high-trust, utilitarian automotive commerce platform optimized for urban West African trade contexts, specifically centered in Dakar. The aesthetic merges precision engineering with vibrant commercial vitality—combining the dependability of industrial manufacturing with the street-level reliability essential to digital automotive commerce.

The target audience encompasses vehicle owners, independent garage mechanics, fleet dispatchers, and parts merchants transitioning from traditional markets (like Colobane) to verified digital procurement. The interface must evoke:
- **Absolute mechanical verification:** Eliminating the anxiety of counterfeit or incompatible components.
- **Financial certainty:** Complete transparency in escrow transactions and local currency settlement (FCFA).
- **Tactile immediacy:** Field-ready utility with high contrast and oversized touch interaction points resilient to sun glare, dust, and rapid handheld operation.

The visual style leans into **Precision Utilitarianism with Tactile Feedback**: crisp structural dividers, stark white and slate canvas hierarchies, and high-visibility status signaling.

## Colors

The palette is engineered around high functional differentiation, separating navigation, dynamic action, and trust protocols:

- **Primary (`#0F172A` - Automotive Slate/Navy):** The bedrock structural tone. Anchors top navigation, primary headings, core buttons, and structural silhouettes. Evokes solid steel, heavy machinery, and institutional stability.
- **Secondary (`#F59E0B` - Dakar Energy Gold/Amber):** The catalytic accent. Dedicated to high-intent conversion actions, key highlights, automotive alert ratings, and interactive mechanical callouts.
- **Tertiary (`#10B981` - Escrow Shield Emerald):** Reserved exclusively for transaction security, verified merchant certifications, escrow states (*Séquestre actif*, *Fonds protégés*), and vehicle compatibility confirmations.
- **Neutral Canvas (`#F8FAFC` Base, `#F1F5F9` Elevated Tonal Surface, `#E2E8F0` Border Crisp):** High-albedo, clean background planes engineered to perform under intense ambient light and outdoor sunlight in Dakar street environments.

### System Indicators & Utility Surfaces
- **Escrow Soft Surface:** `#ECFDF5` paired with `#047857` text for protected transaction wrappers.
- **Demo Mode Banner:** `#FEF3C7` background with `#92400E` border and typography for the mandatory persistent environment flag (*MODE DÉMO — aucun argent réel*).
- **Vehicle Match Token:** `#F0FDF4` base with a `#16A34A` hairline stroke for instant visual confirmation of year/make/model alignment.

## Typography

The design system standardizes on **Plus Jakarta Sans** for headlines, interface labels, and dense technical inventories. Its wide apertures, geometric balance, and clean digital legibility ensure high scanning speed across varying device screens and network conditions.

### Numerical & Pricing Convention
- Prices must be rendered using tabular numbers (`font-variant-numeric: tabular-nums`).
- Currency suffix formatting requires strict typographic separation: e.g., `45 000 FCFA` (non-breaking space before currency indicator, currency set to `label-md` or `label-lg` relative to the price integer).
- Vehicle part reference numbers, VIN specifications, and OEM serials should use uppercase tracking via `label-sm`.

## Layout & Spacing

The layout is built mobile-first, targeting viewport boundaries between 360px and 390px (e.g., standard Android and iOS devices prevalent in Dakar). 

### Layout Model
- **Grid Structure:** 4-column fluid layout on mobile devices (`<640px`) with `12px` gutters and `12px` to `16px` outer margins. Content transitions to a 12-column fixed container on screens `>1024px` with a maximum width of `1200px`.
- **Rhythm & Touch Baselines:** Vertical spacing maintains an 8px grid increment (backed by a 4px sub-grid for badges and chip tags). Touch boundaries maintain a mandatory physical hit surface of at least `48px × 48px` to facilitate thumb-driven navigation during physical inspection in field workshops.
- **Sticky Viewport Layers:** 
  - Top: Persistent safety banner (`32px` height) followed immediately by contextual search or vehicle-selector header.
  - Bottom: Fixed checkout/inquiry bar (`64px` height excluding safe-area-insets) pinned to the mobile base for instant transaction access.

## Elevation & Depth

Visual hierarchy relies on structural planes and sharp 1px hairline borders (`#E2E8F0` or `#CBD5E1`) rather than heavy blurred drop shadows. This preserves crisp definition under outdoor sun exposure and maintains fast render times on lower-end mobile chipsets.

- **Level 0 (Flat Ground):** Base view surface (`#F8FAFC`).
- **Level 1 (Card Container):** Raised white surface (`#FFFFFF`) framed by a clean border `1px solid #E2E8F0`. Shadows are minimal and neutral: `0 1px 3px 0 rgba(15, 23, 42, 0.06), 0 1px 2px -1px rgba(15, 23, 42, 0.04)`.
- **Level 2 (Active Drawer & Sticky Checkout Bar):** Solid `#FFFFFF` with an upward hairline border (`1px solid #CBD5E1`) supported by a shallow ambient drop: `0 -4px 12px 0 rgba(15, 23, 42, 0.08)`.
- **Level 3 (Modal / Verification Overlay):** `#FFFFFF` with high-contrast structural containment: `0 20px 25px -5px rgba(15, 23, 42, 0.15)`. Backdrops feature a solid 60% opacity overlay of `#0F172A`.

## Shapes

The interface embraces a functional, mechanical corner language. Using soft, restrained geometry (`roundedness: 1` — default `4px`, cards and inputs `8px`, pills reserved exclusively for status labels), the system echoes the precision-machined edges of automotive parts rather than playful consumer app contours.

- **Inputs, Buttons, and Surface Cards:** Standardized to `0.5rem` (`8px`) corner radius (`rounded-lg`).
- **Status Tags, Escrow Indicators, and Micro-Badges:** Standardized to full-radius pills (`9999px`) to immediately isolate analytical verification flags from clickable surfaces.

## Components

### Demo Environment Banner
- Pinned to the extreme top edge of the mobile viewport.
- Height: `32px`, background `#FEF3C7`, text `#92400E`, border bottom `1px solid #FCD34D`.
- Content: Centered, uppercase `label-sm` ("MODE DÉMO — AUCUN ARGENT RÉEL").

### Buttons
- **Touch Target:** Minimum height of `48px`, full-width on mobile viewports for terminal flows.
- **Primary Action (Commercial Conversion):** Background `#F59E0B` (Amber Gold), text `#0F172A` (Heavy Navy), bold weight (`label-lg`), with subtle pressed state (`active:scale-[0.99] active:bg-[#D97706]`).
- **Escrow / Secure Purchase Action:** Background `#0F172A`, text `#FFFFFF`, integrating a lock or shield icon in `#10B981`.
- **Secondary / Filter Action:** Background `#FFFFFF`, border `1px solid #CBD5E1`, text `#0F172A`.

### Vehicle Compatibility Pill (`Compatible avec votre véhicule`)
- Container: Background `#ECFDF5`, border `1px solid #A7F3D0`, border radius `9999px`.
- Layout: Inline horizontal alignment (`padding: 4px 10px`), leading checkmark icon (`16px`) in `#10B981`.
- Typography: `label-sm` in `#065F46`.
- Incompatible state shifts tone to `#FEF2F2` background with `#DC2626` icon and label.

### Escrow Security Card (`Fonds protégés / Séquestre actif`)
- Visual treatment: Boxed panel with `#F8FAFC` background and a distinct `#10B981` 3px left structural accent border.
- Copy layout: Accompanied by secondary label `body-sm` explaining payment release only after garage validation.

### Merchant Verification Badge
- Micro-pill (`padding: 2px 8px`, border radius `9999px`), background `#0F172A`, foreground `#FFFFFF`.
- Features an inset emerald dot (`6px` circular `#10B981`) followed by "Vendeur Vérifié Colobane" or "Distributeur Agréé".

### Product Listing Card (Inventory Grid & Feeds)
- Structural frame: `#FFFFFF` ground, `1px solid #E2E8F0` border, `8px` corner radius.
- Image region: High-contrast neutral background (`#F1F5F9`) with integrated mechanical watermark and part condition badge (`Neuf`, `Occasion Certifiée`) anchored top-left.
- Content stack:
  1. OEM / Part Number (`label-sm`, `#64748B`).
  2. Component Title (`headline-sm`, `#0F172A`).
  3. Vehicle Compatibility Pill.
  4. Pricing row: Bold numerical display (`price-display`, `#0F172A`, e.g., `85 000 FCFA`) paired with delivery SLA indicator.

### Input Fields & Search Bars
- Height: `48px` to guarantee immediate tactile accessibility.
- Border: `1.5px solid #CBD5E1`, focus state transitions to `2px solid #0F172A`.
- Background: `#FFFFFF`. Placeholder text in `#94A3B8`.
- Integrated camera/VIN scan icon button anchored within the trailing edge of global spare-part search bars.