---
description: UI/UX design system rules for the Starpath AI companion platform
globs: ["app/lib/**/*.dart"]
---

# Starpath Design System

Inspired by Google Gemini's visual design language — gradients as life force, circles as safety, motion as intelligence.

## Color System — Multicolor Emotion Spectrum

### Brand Gradient (Primary)
- Start: `#6C63FF` (Inspiration Purple)
- End: `#00D2FF` (Clear Blue)
- Usage: Brand identity, primary CTA buttons, AI thinking state glow

### Emotion Spectrum (AI Companion Dynamic Colors)
- Joy: `#FFD93D` → `#FF6B6B` (Warm sun to coral)
- Calm: `#6BCB77` → `#4D96FF` (Green to sky blue)
- Thinking: `#9B59B6` → `#6C63FF` (Deep purple to inspiration purple)
- Excited: `#FF6B6B` → `#FF85A2` (Vibrant red to sakura pink)
- Focused: `#4D96FF` → `#00D2FF` (Steady blue to clear blue)

### Neutrals
- Background: `#FAFBFF` (Slight blue-white)
- Card: `#FFFFFF` at 0.85 opacity (Semi-transparent white, frosted glass)
- Text Primary: `#1A1D26`
- Text Secondary: `#6B7280`
- Text Tertiary: `#9CA3AF`
- Divider: `#F1F3F9`

### Functional Colors
- Success / Currency Earned: `#10B981`
- Warning: `#F59E0B`
- Error: `#EF4444`
- Currency Coin: linear gradient `#FFD93D` → `#FF8C00`

## AI Companion Visual System

### Design Philosophy
Each AI companion is a "living gradient entity":
- Borrows Gemini gradient language: each companion has a unique gradient spectrum
- Sharp edge of gradient points toward companion's "attention direction"
- Diffused edge represents companion's "emotional energy field"

### Companion Base Form
- Bio-morphic design based on circles/ellipses (pet-like)
- Gradient "energy aura" around avatar, reflecting mood in real-time
- Breathing animation: 0.8s ease-in-out infinite (scale 0.98–1.02)
- Thinking animation: aura pulse + internal gradient flow

### Companion States
- Online/Active: bright aura, slow breathing
- Thinking: faster aura pulse, gradient flow
- Creating: aura expansion, particle effects
- Sleeping: dim aura, slow breathing
- Excited: aura flicker, slight bounce

## Card System

### Base Card
- Border radius: 20px
- Background: `rgba(255,255,255,0.85)` with `backdrop-filter: blur(20px)`
- Shadow: `0 4px 24px rgba(108,99,255,0.08)`
- Padding: 16px
- Card gap: 12px

### Card Variants
- Image-text card: top image (20px radius) + bottom text/interaction bar
- Video card: cover image + play button (circular frosted glass) + duration label
- Dialogue card: simulated chat bubbles + small companion avatar
- Agent profile card: centered companion image + gradient background + skill tags

### Card Interactions
- Tap: `scale(0.98)` → `scale(1.0)`, 200ms ease-out
- Long press: frosted glass action panel popup
- Like: particle burst animation (using companion's gradient colors)

## Typography

### Font Stack
- Chinese: PingFang SC / HarmonyOS Sans (system)
- English: SF Pro Display / Roboto
- Monospace: JetBrains Mono (code scenarios)

### Scale
- H1 (page title): 28px Bold, line-height 36px
- H2 (section title): 22px Semibold, line-height 30px
- H3 (card title): 17px Semibold, line-height 24px
- Body: 15px Regular, line-height 22px
- Caption: 13px Regular, line-height 18px
- Mini (tag/badge): 11px Medium, line-height 14px

## Motion Design (Gemini-Inspired)

### Principle
"Every animation has a clear start and end point, creating directionality that maps to user behavior."
"Internal activity conveys thinking, analysis, and intelligence."

### Easing Curves
- Standard: `cubic-bezier(0.4, 0.0, 0.2, 1)` — 300ms
- Enter: `cubic-bezier(0.0, 0.0, 0.2, 1)` — 250ms
- Exit: `cubic-bezier(0.4, 0.0, 1.0, 1)` — 200ms
- Bouncy: `cubic-bezier(0.34, 1.56, 0.64, 1)` — 400ms (companion reactions)

### AI Companion Animations
- Thinking pulse: aura opacity 0.6→1.0→0.6, 1.2s
- Message receive: slide up from bottom + slight bounce
- Emotion transition: gradient spectrum 600ms crossfade
- Appear/disappear: `scale(0.8, opacity 0)` → `scale(1, opacity 1)`, bouncy curve

### Page Transitions
- Forward: slide in from right, shared element transition (companion avatar)
- Back: slide out to left
- Modal: bottom sheet slide up, frosted glass background fade in

### Gradient Animations (Gemini Core)
- AI streaming reply: gradient flows left-to-right, sharp edge follows text
- Voice input: radial gradient pulse (ref: Gemini voice ripple)

## Component Specs

### Buttons
- Primary: brand gradient fill, 24px radius, 48px height, white text
- Secondary: gradient stroke (1.5px), transparent fill, gradient text
- Text: no background, brand color text
- Icon: 40x40 circle, frosted glass, centered icon
- All buttons: haptic feedback + scale animation on tap

### Chat Bubbles
- User: brand gradient background, white text, right-aligned, bottom-right 8px / others 20px radius
- AI: white frosted glass, dark text, left-aligned, bottom-left 8px / others 20px radius
- AI bubble left edge: 2px gradient line (companion's colors)

### Input Field
- Radius: 24px
- Background: `rgba(255,255,255,0.7)`, frosted glass
- Focus state: brand gradient stroke appears (animated)
- Interior: left side companion mini-avatar, right side send button (gradient)

### Navigation Bar
- Bottom tab bar: frosted glass background, 5 tabs
- Selected state: gradient dot above icon + icon tinted with gradient
- Center create button: protruding, gradient circle, 1.5x larger than other tabs

### Currency Display
- Icon: small gradient sphere (gold), with sparkle micro-animation
- Value: Semibold, gradient text
- Change: +value floats up and fades (green), -value sinks and fades (red)

## Aura System

### Structure (inside → outside)
1. Companion avatar (core)
2. Inner aura ring: clear edge, opacity 0.7, gradient colors
3. Outer glow: blur radius 12px, opacity 0.3, companion primary color

### Aura Responses
- Poke: aura expands + avatar bounces + expression change
- Message received: aura flashes once
- Long idle: aura slowly contracts, companion enters "dozing" state
