---
description: UI/UX design system rules for the Starpath AI companion platform
globs: ["app/lib/**/*.dart"]
---

# Starpath Design System

**Celestial Dreamscape** — 深色星空壳层：深紫雾星云、生物荧光点缀、大圆角、弱硬边。渐变语言受 Gemini 风格启发（渐变即生命力、圆形即安全感、动效即智感）。**色彩与主题真源：`app/lib/core/theme.dart` · `StarpathColors` + `StarpathTheme.darkTheme`。** 下文「页面规范」与 `discovery_page.dart`、`chat_list_page.dart`、`chat_detail_page.dart`、`agent_studio_page.dart`、`main_scaffold.dart` 一致。

## Color System — 深色主题（`StarpathColors`）

### Primary · Secondary · Brand
- **Primary** `#CC97FF`（Luminescent Lavender）— 主色、链接、强调
- **Primary Dim** `#9F6FD3`
- **Primary Container** `#4A2670` · **On Primary Container** `#E8CFFF`
- **On Primary** `#1A0028` — 铺在饱和主色块上的文字（如 Material 主按钮）
- **Secondary** `#D6B2FC`（Softened Violet）· **On Secondary** `#220038`
- **Tertiary** `#FFDD7C`（Warm Gold）· **On Tertiary** `#3D2A00`
- **`brandGradient`**：`primary` → `secondary`，起点左上、终点右下 — 用户聊天气泡、部分主 CTA
- **`selectedGradient`**：`accentViolet` → `accentIndigo` — 选中 Tab、Chips、导航光晕、未读条、心形选中态等

### Accent（选中 / 光晕）
- **Accent Violet** `#9B72FF`
- **Accent Indigo** `#5B48E8`

### Surface 层级（Level 0 → 导航玻璃）
| Token | HEX | 用途 |
|-------|-----|------|
| `surface` | `#180720` | 页面底色、Scaffold |
| `surfaceContainer` | `#261030` | 一级卡片 / 嵌套底 |
| `surfaceContainerHigh` | `#341545` | 抬高表面、输入底、图标按钮底 |
| `surfaceContainerHighest` | `#42195A` | Hover / 更高阶嵌套 |
| `surfaceBright` | `#3D1F54` | 底栏毛玻璃基色（常叠透明度） |

### 文本与分割
- **On Surface** `#F8DCFF` — 标题、主文案
- **On Surface Variant** `#BCA2C4` — 正文、次要说明
- **Text Tertiary** `#9882A0` — 时间、辅助信息（`StarpathColors.textTertiary`）
- **Outline Variant** — `primary` **15%** 透明度（`#26CC97FF`）— 幽灵描边、分割线轻量替代可用 **`divider`** `#3A2048`

### Emotion Spectrum（伴侣渐变 · 与代码中 `*Gradient` 一致）
- Joy: `#FFD93D` → `#FF6B6B`
- Calm: `#6BCB77` → `#4D96FF`
- Thinking: `#9B59B6` → `#6C63FF`
- Excited: `#FF6B6B` → `#FF85A2`
- Focused: `#4D96FF` → `#00D2FF`

### Functional
- **Success** `#10B981` · **Warning** `#F59E0B` · **Error** `#FF6B6B`（与 `StarpathColors.error` 一致）
- **Currency** `currencyGradient`：`tertiary` → `#F0A840`

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

### Base Card（深色）
- Border radius: **20px**（详情主图区等）；瀑布流 Feed 见下「变体」
- Background: **`surfaceContainer` ~ `surfaceContainerHigh`** 或叠透明度（如 `@ 42%` / `@ 55%`），**不用**浅色半透明白纸
- Shadow: 黑色 **8~16%** blur **12~28**、可选 `primary` 淡晕；重内容区可加强（如详情封面 `blur 28` / `spread -8`）
- Padding: **16px**（通用）；Feed 内边距见页面规范
- Card gap: **12px**（栅格/列表常见值）；发现双列 **10**

### Card Variants
- Image-text card: top image (20px radius) + bottom text/interaction bar
- **发现瀑布流卡片**：圆角 **12**、底栏分离式 footer（见下文「页面规范 — 发现」），与通用 Base Card **20** 并存
- Video card: cover image + play button（圆形 **`surfaceContainer` + blur / 高透明度`onSurface` 图标**）+ duration label
- Dialogue card: simulated chat bubbles + small companion avatar
- Agent profile card: centered companion image + gradient background + skill tags

### Card Interactions
- Tap: `scale(0.96~0.98)` → `1.0`，**110~200ms** `easeOut`（以各页实装为准）
- Long press: **`surfaceContainerHighest` / Material 菜单** 等深色浮层，非浅色磨砂
- Like: 双击/点击心形缩放脉冲、渐变粒子（可用伴侣色或 `#FF6B9D → #9B72FF`）

## Typography

### Font Stack
- **UI 主字体**：**Plus Jakarta Sans**（`GoogleFonts.plusJakartaSans` · `StarpathTheme`）
- 中文回退：系统 **PingFang SC** / **HarmonyOS Sans**（随平台）
- 等宽场景：**JetBrains Mono**

### Scale
- H1 (page title): 28px Bold, line-height 36px — 字色默认 **`onSurface`**
- H2 (section title): 22px Semibold, line-height 30px
- H3 (card title): 17px Semibold, line-height 24px
- Body: 15px Regular — 主文 **`onSurfaceVariant`**，标题级用 **`onSurface`**
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
- Modal: bottom sheet slide up；`surfaceContainer` / 深 **scrim** 遮罩渐入（非浅色磨砂玻璃）

### Gradient Animations (Gemini Core)
- AI streaming reply: gradient flows left-to-right, sharp edge follows text
- Voice input: radial gradient pulse (ref: Gemini voice ripple)

## Component Specs

### Buttons
- Primary: **`brandGradient` 或 `selectedGradient`** 填充（按场景）；圆角常见 **24~100**；高度因布局 **40~48**。文字：**聊天气泡等**用 **白字** 保证对比；**Material 主按钮**上可用 **`onPrimary`**（`#1A0028`）
- Secondary: **1~1.5px** `outlineVariant` 或渐变描边 + **`surface` / `surfaceContainer` 透明底** + `primary` / `onSurface` 字色
- Text / Ghost: 无填充，`primary` 或 `accentViolet` 字色；hover 可加下划线（参见对话页 `_HoverTextButton`）
- Icon: **36~40** 方圆角 **12** 或圆形，底 **`surfaceContainerHigh`**，图标 `onSurface` / `onSurfaceVariant`
- All buttons: haptic + 按压缩放（常见 **0.88~0.98** scale、**110~140ms**）

### Chat Bubbles
- User: `StarpathColors.brandGradient` 填充、白字、右对齐；尾角 **6**、对侧 **20**（`ChatDetailPage` 实装）
- AI: **`surfaceContainerHighest`** 填充、`outlineVariant` 细描边、左对齐；尾角 **6**、对侧 **20**；左侧 **2px** 竖线（伴侣渐变主色 **~55%** opacity）；正文 **`onSurfaceVariant`**
- 助手侧头像：`AuraAvatar` **32**；列表项时间戳 hover 行为见 `ChatDetailPage` 内 `_BubbleWithTimestamp`

### Input Field
- Radius: **24px** 量级
- Background: **`surfaceContainerHigh` ~ `surfaceContainerHighest`**，描边 **`outlineVariant`**
- Focus: **`primary` / `accentViolet` 描边加粗或渐变描边**（动画以实装为准）
- 聊天输入：可含左侧伴侣小头像、右侧 **`selectedGradient` / `brandGradient` 发送钮**

### Navigation Bar（Main Scaffold）
- **4** 个分支：发现 / 对话 / 伙伴 / 我的（`MainScaffold`）；无五栏「中间凸起发布」——发布在创作流等独立路由完成。
- 外层 `Padding`：左右 **20**、底 **20**；栏高 **68**、圆角 **36**。
- 毛玻璃：`BackdropFilter` blur **σ 32**；底 `surfaceBright @ 60%` + `outlineVariant` **1px** 描边。
- 选中光效：`TweenAnimationBuilder`（**300ms** `easeInOut`）驱动 `CustomPainter`：选中格上方 **径向紫→靛光晕**、顶缘 **亮色弧线**、**星点**；随索引连续插值滑动。
- Tab 项：线框/填充图标切换；选中时图标 **渐变着色**、标签字重更高、主色趋向 `onSurface`。

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

---

## 页面规范 — 发现 / 对话 / AI 伙伴

以下与当前实现一一对应，便于评审与迭代时对照。

### 发现（`DiscoveryPage`）

**信息架构**
- 顶栏 **三 Tab**（emoji + 文案）：关注 `👥` / 发现 `✨` / 附近 `📍`；默认 **发现**。
- **关注 / 发现**：`CustomScrollView` + 分类横滑 Chips + **双列瀑布流**（`SliverMasonryGrid`，列间距 **10**）。
- **附近**：全屏 `NearbyGlobePage`（3D 地球）；顶栏 `Positioned` + `SafeArea`，**不参与**外层滚动，避免手势冲突。

**顶栏（SliverAppBar）**
- `floating` + `snap`，`surface` 底、`surfaceTint` 透明、无 elevation。
- 左 **搜索**、中 **三 Tab**、右 **通知**；图标 **24**，约束约 **36×36**。
- 选中 Tab：`AnimatedDefaultTextStyle` **200ms**，字号 **16 / 15**、字重 **w700 / w400**；下划指示 **高 2 × 宽 20**、`selectedGradient`、圆角 **2**。

**分类 Chips**
- 条高 **44**；`ListView` 横向，`padding` 左右 **14**，项间距 **8**。
- 选中：`selectedGradient` + 投影（`primary @ 35%`，blur **12**，offset `0,3`）；未选：`surfaceContainerHigh` + `outlineVariant` **0.8** 描边；胶囊圆角 **100**；内边距约 **14×5**；文案 **13**、emoji **14**。

**Feed 卡片（小红书式）**
- 圆角 **12**；`Material` 色 `surfaceContainer @ 42%`；`InkWell` splash / highlight 用 `primary` 透明度。
- 按压：`AnimatedScale` **0.96**，**140ms** `easeOut`。
- 入场：`flutter_animate` 按 index 错开 **~55ms**，**380ms** `fadeIn` + `slideY(0.18)`。
- **封面**：`AspectRatio` 由 `coverAspectRatioForCard` 决定（3:4 或 4:3）；`Hero` tag `card-cover-{id}`；多图角标右上 **8**，黑底 **48%** 圆角 **8**，`layers_rounded` **14**。
- **标题**：`displayTitleForCard`，**13** `w600`，最多 **2** 行。
- **底栏**：`surfaceContainer @ 55%`，内边距 **8 / 7 / 8 / 9**；`UserAvatar` **20**；点赞 `ShaderMask` 心形：已赞渐变 `#FF6B9D → #9B72FF`，未赞 `onSurfaceVariant`；数量 **11**，`k/w` 缩写规则。

**加载 / 空 / 错**
- 加载：`CircularProgressIndicator` **24×24**、stroke **2**、`primary`。
- 错误：云离线图标 **48** + 「加载失败」+ `TextButton` 重试。
- 空：大 emoji **56** + 双行引导文案。

**卡片详情（`CardDetailPage`）**
- 顶区 `SafeArea` + `_DetailTopBar`；主图区 **24** 圆角、重阴影（黑 **16%**，blur **28**，spread **-8**）。
- 图集：`PageView` + 多图页码胶囊（黑 **34%**）+ 底 **6dp** 圆点指示（ active **16×6** ）。
- 双击点赞：中心大红心 **100** + 缩放/淡出动画；与底部栏点赞联动、乐观更新。
- 标题 **22** `w700` `letterSpacing -0.44`；正文 **15**；标签 `_GradientTag`；存在 Agent 时 `_AgentTag`。
- 统计行 `_SocialStatsRow`；评论区标题 **15** `w700`；底栏 `_BottomBar` 固定 `Positioned bottom`（输入/点赞）。

### 对话（`ChatListPage` + `ChatDetailPage`）

**列表页布局**
- 背景 `surface`；顶部预留 `MediaQuery.padding.top + 16`。
- 标题行：**对话**，`titleLarge` + **w800**；左搜索切换（展开 **220ms** `AnimatedSize`）、右 **编辑** 打开「选择联系人」`ModalBottomSheet`（顶圆角 **20**，`surfaceContainer`）。
- **通知横排**：三个 `_NotificationShortcut`（提及 / 点赞 / 新粉丝），等分 `Row`，间距 **12**；实现为 **Juicy Blob**（`StarpathJuicyIcons` 三色 palette）+ **2.4s** 呼吸光晕 + 角标渐变；卡片圆角 **18**、竖向内边距 **16**；hover 上浮 **3px**、紫描边增强。
- **私信**区：`headlineSmall` **w800** + 「全部已读」`_HoverTextButton`（hover 下划线 + `accentViolet`）。
- **会话行 `_UserTile`**：圆角 **20**；未读左侧 **3→5px** 宽 `selectedGradient` 条（hover 加宽）；内边距 **14×12**；头像 **52** + 在线点（绿 `#3DD68C`，带 `surfaceContainer` 边）；标题 **15**（未读 **w700**）；时间 **11** `textTertiary`；预览 **13**；未读紫点 **10** 或 hover **chevron** `accentViolet @ 80%`。
- **头部图标按钮 `_IconBtn`**：**38×38**、圆角 **12**，底 `surfaceContainerHigh`；hover `surfaceContainerHighest` + 淡紫描边；按压缩放 **0.88 / 120ms**。

**详情页 — AI 流式对话（`ChatDetailPage`）**
- 全屏竖向渐变：顶 **Agent 渐变起止色 @ 22% / 10%**，底落 `surface`（`stops 0 / 0.5 / 1`）。
- **顶栏**：圆返回钮 **38** + `AuraAvatar` **36**（`CompanionState`：`thinking` / `active`）+ 名称 **15** `w700` + 状态行（在线点 + **11** 文案：`思考中…` 用 `warning`，在线 `success`，否则 `textTertiary`）；右更多 **38** 圆钮。
- **无消息 — 沉浸式**：底部大 `AuraAvatar`（宽约屏 **58%**）+ 底部大光晕（`gradStart @ 30%`，blur **90**）；左上问候 `headlineLarge` **w800** + 副文案 `bodyMedium`；右上状态胶囊（**20** 圆角、`surfaceContainer @ 88%`）。
- **有消息**：`ListView` **16** padding；新消息（index ≥ `_settledCount`）**260ms** `fadeIn` + 用户/助手 **±0.08** `slideX`。
- **气泡**：用户 — `StarpathColors.brandGradient` 填充、白字；圆角 **20**，尾侧 **6**（对侧 **20**）。助手 — **`surfaceContainerHighest`** + `outlineVariant` 边框 + 左 **2px** 伴侣色条；字色 **`onSurfaceVariant`**；左侧 `AuraAvatar` **32**。
- **思考占位**：无流式 token 时单独 `_buildThinkingBubble`。
- **底部**：有历史或已展开文字输入时 `_buildInputBar`；否则三钮 `_VoiceControls`（关 / 闭麦装饰 / 键盘高亮打开输入）。输入条样式以实装 `InputDecoration` 为准（渐变描边/圆角与主题一致）。

### AI 伙伴（`AgentStudioPage`）

**壳层与背景**
- `AnnotatedRegion`：`statusBar` 透明、**浅色图标**（`Brightness.light` on status bar）。
- `Stack`：底层 `surface`；上层 **`PartnerPageBackgroundConfig` 高度** = `statusBarH + gradientBandHeight` 的 `linearGradient`（`partnerBackgroundProvider` 可用户切换）；`Scaffold` **透明** 叠在渐变上。

**页眉**
- 标题 **「我的 AI 伙伴」**：`headlineMedium` 字号 **+8**，**w800**；左文右 **渐变按钮**「创建伙伴」（高 **40**、水平 **16**、`selectedGradient`、阴影 `accentViolet @ 38%`）+ **渐变** `IconButton` 进背景编辑器。

**Spotlight 横滑社区卡**
- 副标题 **「发现并创建属于你的智能伙伴」**：`bodySmall` `onSurfaceVariant`。
- 卡高 **150** + 顶 **破框 bleed 42**（角色图上移与兔耳视觉对齐）；横滑 `ListView.separated`，左 **20**、右留 **36** 露出下一张；间距 **14**。
- 卡体：主容器圆角 **26**；首张背景用 **`PartnerPageBackgroundConfig.gradientColors/stops`**；第二张 **橙→粉→紫** 多 stop 渐变；其余 **暖色纸感**三色渐变。角色图为 **`images/png/ai*.png`**（`agentCoverImageByIndex`），`BoxFit.contain` 底部对齐。
- 交互：按压 **0.97** scale **120ms**；hover 增强双层阴影（紫晕 + 黑）。

**筛选 Chips**
- 节标题 **「超火的ai伙伴」**：`headlineSmall` **w800**。
- 横滑高 **46**；`['全部', …kAgentStyleCategories]`；样式与发现分类一致逻辑：**选中** `selectedGradient` + 紫阴影；**未选** `surfaceContainerHigh @ 85%` + `outlineVariant`；内边距约 **18×8**、文案 **13**。

**网格伙伴卡 `_AgentCard`**
- `SliverGrid`：**2** 列，`mainAxisExtent` **280**，纵横间距 **14**；外边距 **16**。
- 封面：`partnerCoverImageByIndex`（`images/ip*.png`）等，与 Spotlight 资源池区分。
- 空筛选：居中图标 **48** + 标题 + 说明文案引导「全部」或创建。

**数据降级**
- `myAgentsProvider`：`error` 或 **空列表** 时使用内联 `_previewAgents` 预览数据，保证页不为空。

### 跨板块复用要点
- **选中态渐变**：统一 `StarpathColors.selectedGradient`（Juicy 角标、Chips、Tab 下划、私信未读条、部分按钮）。
- **列表错开入场**：发现卡片、私信行等多用 **index × 55ms** 上限封顶的 stagger + `flutter_animate`。
- **按压反馈**：卡片 **0.96~0.98** scale、短 **110~140ms**；图标钮 **0.88~0.93**；配合 `HapticFeedback` 在关键点击处。
- **头像**：发现流 `UserAvatar`；会话列表 `CachedNetworkImage` + DiceBear fallback；对话内 **`AuraAvatar`** 表达伴侣状态。
