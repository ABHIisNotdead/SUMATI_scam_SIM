---
name: Sumati Cyber Safety
colors:
  surface: '#f8faf7'
  surface-dim: '#d9dad8'
  surface-bright: '#f8faf7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f2'
  surface-container: '#edeeec'
  surface-container-high: '#e7e9e6'
  surface-container-highest: '#e1e3e1'
  on-surface: '#191c1b'
  on-surface-variant: '#3e4945'
  inverse-surface: '#2e3130'
  inverse-on-surface: '#f0f1ef'
  outline: '#6e7975'
  outline-variant: '#bec9c4'
  surface-tint: '#006b59'
  primary: '#005344'
  on-primary: '#ffffff'
  primary-container: '#006d5b'
  on-primary-container: '#96ebd5'
  inverse-primary: '#81d6c0'
  secondary: '#7e5700'
  on-secondary: '#ffffff'
  secondary-container: '#feb726'
  on-secondary-container: '#6c4a00'
  tertiary: '#960014'
  on-tertiary: '#ffffff'
  tertiary-container: '#ba2027'
  on-tertiary-container: '#ffd0cc'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#9df3dc'
  primary-fixed-dim: '#81d6c0'
  on-primary-fixed: '#00201a'
  on-primary-fixed-variant: '#005143'
  secondary-fixed: '#ffdeac'
  secondary-fixed-dim: '#ffba36'
  on-secondary-fixed: '#281900'
  on-secondary-fixed-variant: '#5f4100'
  tertiary-fixed: '#ffdad7'
  tertiary-fixed-dim: '#ffb3ae'
  on-tertiary-fixed: '#410004'
  on-tertiary-fixed-variant: '#930014'
  background: '#f8faf7'
  on-background: '#191c1b'
  surface-variant: '#e1e3e1'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 19px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 22px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '700'
    lineHeight: 18px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '800'
    lineHeight: 16px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.375rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

This design system is engineered specifically for senior citizens and everyday multi-lingual digital users across India. The brand identity anchors on protection, dignified empowerment, clarity, and instant legibility under cognitive duress. 

### Design Movement: Tactical High-Contrast & Reassuring Materialism
The visual identity draws from high-contrast functionalism paired with warm, reassuring Indian civic tones. Rather than dense, complex cybersecurity styling with dark terminals or intimidating tech jargon, the interface prioritizes:
- **Maximum Cognitive Affordance:** Explicit signposting, unambiguous status markers, and generous touch ergonomics.
- **Multilingual Dignity:** Seamless visual rhythm across Devanagari scripts (Hindi, Marathi) and Latin typography without layout breaks.
- **Reassurance over Alarmism:** Defensive teal establishes calm, authoritative safety; cautionary amber accents smart AI tools; deliberate crimson isolates acute emergency actions.
- **Sensory Clarity:** High-contrast text bounds, thick borders where physical boundaries matter, and tactile interactive surfaces that instill confidence during scam simulations and real-time fraud triage.

## Colors

The color palette is calibrated for AAA WCAG accessibility standards across varied lighting environments, low-cost displays, and aging eyesight.

### Palette Architecture
- **Primary (`#006D5B` / Deep Emerald Teal):** Signifies digital sovereignty, institutional trust, and certified safety. Used for major app bars, safe-state indicators, confirmed practice modules, and primary actions.
- **Secondary (`#E5A100` / Amber Gold):** Signals active evaluation, AI assistance, and practice caution banners. High luminosity against dark text ensures readability without evoking unwarranted panic.
- **Tertiary (`#D9383A` / Alert Crimson):** Dedicated exclusively to immediate risk vectors: the "Emergency Checklist", dialling national cyber helpline (1930), and confirmed scam warnings.
- **Neutral Palette (`#191C1B` to `#F8FAF9`):** A high-contrast off-black on clean mint-tinted warm paper white prevents eye fatigue while preserving absolute edge definition.

### Semantic Tonal Tokens
- **Surface Protective:** `#E6F4F1` (Soft Teal Container) for certified modules and safe badges.
- **Surface Warning / AI:** `#FFF8E7` (Soft Amber Container) with `#8A5800` text for AI analysis containers.
- **Surface Hazard:** `#FDECEB` (Soft Crimson Container) with `#901A1E` text for emergency action cards.
- **Divider & Border Stroke:** `#C4D1CD` with 1.5px minimum stroke weight for explicit card containment.

## Typography

Typography is set in **Plus Jakarta Sans**, chosen for its tall x-height, open counter shapes, and friendly, highly legible letterforms that pair effortlessly with Devanagari system fonts.

### Font Hierarchy & Senior Accessibility Rules
- **No Body Text Under 15px:** Avoid microscopic footers; body text scales generously (`body-lg` at 17px) to reduce strain.
- **Multilingual Baseline Balance:** Line heights are padded with extra clearance (`+4px` compared to standard defaults) to support Hindi and Marathi matras without clipping.
- **Label Boldness:** Interactive button text and status badges use `fontWeight: 700` and `800` to maintain crisp silhouette contrast under ambient outdoor sunlight.

## Layout & Spacing

The layout is built upon an intentional, vertical-first single-column mobile rhythm tailored to thumb-zone interactions and unambiguous scanning.

### Layout Principles
- **Touch Target Threshold:** Interactive controls, list tiles, and input triggers enforce a strict minimum vertical height of `56px` (exceeding standard 48px guidelines) to accommodate reduced motor precision.
- **Safe Margins:** Standard canvas margin is `1.25rem` (20px), ensuring content is securely insulated from bezel edges and curved display corners.
- **Content Stack:** Cards and practice items maintain a consistent vertical element gap using `space-md` (16px), preventing crowded touch overlaps.
- **Banner Placement:** Critical mode ribbons (such as the yellow `PRACTICE - NOT REAL` stripe) pin flush across top boundaries with persistent visibility.

## Elevation & Depth

This system avoids heavy, disorienting blur effects, using tactile, structural boundaries and crisp surface elevation to preserve physical clarity.

### Depth Mechanics
- **Ground Floor (Base Canvas):** `#F7FAF9` (Subtle tinted warm clean surface).
- **Interactive Card Elevation:** Pure `#FFFFFF` fill supported by a dual-boundary structure: a `1px` to `1.5px` stroke of `#E1E9E6` paired with an ambient shadow `0 2px 8px -1px rgba(0, 77, 65, 0.08)`.
- **Active / Pressed State:** Shifts down with zero blur and an enhanced primary border (`2px solid #006D5B`), giving positive haptic/visual confirmation.
- **Alert Banners & Modals:** Elevated at high layer (`0 8px 24px -4px rgba(25, 28, 27, 0.16)`) to focus complete visual attention on emergency instructions.

## Shapes

With `roundedness: 2`, components adopt a balanced radius structure that feels approachable, gentle, and modern without sacrificing structured legibility.

### Corner Radii Guidelines
- **Core Action Buttons & Cards:** `0.75rem` to `1rem` (12px - 16px) corners for card containers and callout boxes, preventing accidental visual sharpness.
- **Segmented Language Toggles:** Full pill or `0.5rem` internal segment boundaries for tactile toggling between English, Hindi, and Marathi.
- **Status & Channel Chips:** `0.5rem` (8px) for compact tags (`WHATSAPP`, `MEDIUM`, `HARD`) ensuring clear, stamp-like definition.

## Components

### Buttons & Large Touch Actions
- **Primary Hero Action (Teal):** `#006D5B` background, pure white text, 56px height, subtle bottom bevel edge, `rounded-lg`.
- **Secondary AI Action (Gold):** `#E5A100` background, high-contrast dark `#241800` text, full-width thumb trigger.
- **Emergency Helpline Button (Crimson):** `#D9383A` background, pure white text, bold label with instant phone dialer iconography.
- **Secondary Outlined Action:** 2px stroke of `#006D5B`, transparent background, dark teal text.

### Practice & Threat Cards
- **Structure:** White card face, `space-md` inner padding, left icon circle (`48x48px` tinted container), headline, sub-label, and right chevron indicator.
- **Difficulty & Metadata Chips:** Embedded pill badges with high-contrast colored borders and tinted fills (e.g., Yellow `#FFF3D1` with `#7A5200` text for `EASY` / `MEDIUM`, and soft blue for channel identifiers like `WHATSAPP`).

### Emergency Action Checklist
- **Step Containers:** High-contrast bordered rows containing bold action titles (`17px`), clear directional subtext, and a custom `28x28px` high-contrast checkbox target on the right.
- **Urgent Callout Header:** Soft red container (`#FDECEB`) with a deep crimson alert icon, framing calm step-by-step instructions.

### Language Switcher Bar
- Horizontal segmented selector spanning 100% width with equal thirds for **English**, **हिंदी**, and **मराठी**.
- Active state: `#006D5B` fill with checkmark and white typography. Inactive state: `#FFFFFF` fill with high-contrast `#191C1B` text.

### AI Scam Input Field
- Large multiline text box with `1.5px` border in `#748781`, expanding to `2.5px` teal focus ring. Placeholder text uses large `16px` legible type with instructional prompt guidance.