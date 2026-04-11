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

## Juicy Blob Icons（高饱和渐变彩色图标）

用于**带语义颜色的图标容器**（快捷入口、通知角标、功能入口圆钮等），与深色背景形成「软糯 blob + 内发光」质感。**禁止**使用发灰的 pastel 作为主色；中灰混入会降低层次，仅在极少量高光层使用低透明度白。

### 设计原则
1. **饱和度优先**：主体渐变使用 HSB 上明显偏「纯」的色，避免 `#E8E2FF` 类灰薰衣草做主色阶。
2. **垂直渐变**：`topCenter` → `bottomCenter`，三色 stops 约 `0.0 / 0.42~0.48 / 1.0`，顶略亮、底更浓，模拟参考图里的 blob 体积光。
3. **图标图形**：`Icon` 使用 **纯白** `#FFFFFF`，可加极轻 `Shadow`（`black @ ~25% opacity, blur 4`）保证可读性。
4. **顶缘高光**：仅在圆形上半部叠一层 `white @ 0.22~0.32` → `transparent` 的线性高光，**不要**用过亮高光（>0.4）盖住饱和度。
5. **外发光（Bloom）**：两层 `BoxShadow`，颜色取自该 palette 的 **主色与辅色**（与 blob 同色 family），`blurRadius` 约 18~28，`alpha` 约 0.38~0.55；第三层可选更大半径、更低 alpha 的晕圈。
6. **角标 / 小胶囊**：使用与主色同系的 **略更深** 双色 `LinearGradient`（对角），避免与 blob 完全同色块扁平。

### 代码中的唯一数据源
- Flutter：`app/lib/core/theme.dart` 内 `StarpathJuicyIcons`（及 `StarpathJuicyIconPalette`）。
- 新增同类入口时 **复用** 现有三种 palette，或按本节原则新增第四种并写入 `theme.dart` + 在本文件登记用途。

### 预置三色（与实现对齐）

| 语义 | 渐变（上 → 下） | 光晕主色 | 用途示例 |
|------|-----------------|----------|----------|
| **蓝紫（提及 / @）** | `#B794FF` → `#7B5CFF` → `#1E7FFF` | `#3D7CFF` + `#A855FF` | 提及、通知类 |
| **粉珊瑚（点赞 / 心）** | `#FF7A9A` → `#FF3D7A` → `#E91E8C` | `#FF2D7A` + `#FF6BA8` | 点赞、喜欢 |
| **松石绿（新粉丝 / 增长）** | `#4FF5C8` → `#00D9A8` → `#00B894` | `#00D4AA` + `#34E8C7` | 新粉丝、增长、成功态入口 |

### 实现清单（Checklist）
- [ ] Blob 直径常见 **44~52dp**，光晕层可比 blob 大 **4~8dp**，`Stack` `clipBehavior: Clip.none`。
- [ ] 未使用 `ShaderMask` 染图标时，**白图标 + 饱和 blob 底** 优先于灰图标 + 淡底。
- [ ] 深色卡片背景上对比不足时，略增强 `glowA/B` 的 alpha，而不是把 blob 改成灰色。

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
