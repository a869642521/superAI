import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/discovery/widgets/user_avatar.dart';

// ── Data Model ────────────────────────────────────────────────────────────────

class GlobeAgent {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String city;

  const GlobeAgent({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.city,
  });

  UserBrief get userBrief => UserBrief(id: id, nickname: name);
}

// ── Mock Data — 60 个球面均匀分布 ─────────────────────────────────────────────

final _mockAgents = _generateAgents();

List<GlobeAgent> _generateAgents() {
  const names = [
    '星际旅人', 'Luna', 'Muse', 'Sakura', 'Aurora', 'Prism', 'Echo', 'Nova',
    'Drift', 'Zen', '夜雨', 'Pixel', 'Lyra', 'Cipher', 'Volta', '光年',
    'Iris', 'Spark', 'Vega', 'Nebula', 'Comet', 'Astra', '晓风', 'Lumen',
    'Sable', 'Quill', '灵曦', 'Blaze', 'Crest', 'Opal', 'Rune', '幻影',
    'Flare', 'Dusk', '云霄', 'Soleil', 'Myra', '凌霄', 'Jinx', 'Halo',
    'Zara', '晨星', 'Clio', 'Ember', '紫烟', 'Fable', 'Onyx', '追风',
    'Vesper', 'Wren', '梦织', 'Axel', 'Celeste', '虹影', 'Phos', 'Seren',
    '流光', 'Kira', 'Thorn', 'Lux',
  ];
  const cities = [
    '北京', '纽约', '巴黎', '东京', '奥斯陆', '悉尼', '伦敦', '新德里',
    '圣保罗', '洛杉矶', '上海', '旧金山', '莫斯科', '新加坡', '约翰内斯堡', '深圳',
    '伊斯坦布尔', '墨西哥城', '迪拜', '蒙特利尔', '首尔', '开罗', '成都', '柏林',
    '阿姆斯特丹', '迈阿密', '孟买', '里约', '多伦多', '香港', '台北', '马德里',
    '雅典', '里斯本', '曼谷', '维也纳', '布宜诺斯艾利斯', '武汉', '雅加达', '奥克兰',
    '拉各斯', '卡拉奇', '德黑兰', '哥本哈根', '斯德哥尔摩', '波哥大', '基辅', '西安',
    '布达佩斯', '华沙', '布拉格', '旧金山', '苏黎世', '杭州', '罗马', '广州',
    '赫尔辛基', '曼彻斯特', '天津', '达拉斯',
  ];
  final rng = Random(0xA1B2C3D4);
  return List.generate(names.length, (i) {
    final theta = acos(1 - 2 * rng.nextDouble());
    final phi = rng.nextDouble() * 2 * pi;
    final lat = (pi / 2 - theta) * 180 / pi;
    final lng = phi * 180 / pi - 180;
    return GlobeAgent(
      id: 'ga${(i + 1).toString().padLeft(2, '0')}',
      name: names[i % names.length],
      lat: lat,
      lng: lng,
      city: cities[i % cities.length],
    );
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

class NearbyGlobePage extends StatefulWidget {
  const NearbyGlobePage({super.key});

  @override
  State<NearbyGlobePage> createState() => _NearbyGlobePageState();
}

class _NearbyGlobePageState extends State<NearbyGlobePage>
    with SingleTickerProviderStateMixin {
  double _rotX = 0.18;
  double _rotY = -1.5;

  double _startGX = 0, _startGY = 0;
  double _rotXStart = 0, _rotYStart = 0;

  double _vX = 0, _vY = 0;
  bool _isDragging = false;

  late Ticker _ticker;
  Duration? _lastTickTime;

  GlobeAgent? _selected;

  // 地球中心 & 半径（供 build 和 _buildMarkers 共享）
  Offset _globeCenter = Offset.zero;
  double _globeR = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start(); // 始终运行，支持自动慢转
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── 自动旋转 + 惯性衰减 ───────────────────────────────────────────────────

  static const _autoVY = 0.18; // rad/s 慢转

  void _onTick(Duration elapsed) {
    if (_lastTickTime == null) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTickTime!).inMicroseconds / 1e6;
    _lastTickTime = elapsed;

    // 拖拽中 → 暂停旋转；选中卡片时地球继续慢转
    if (dt <= 0 || dt > 0.05 || _isDragging) return;

    final decay = exp(-3.2 * dt);
    setState(() {
      _rotX = (_rotX + _vX * dt).clamp(-pi / 2.05, pi / 2.05);
      _rotY += (_vY + _autoVY) * dt;
      _vX *= decay;
      _vY *= decay;
      if (_vX.abs() < 0.01) _vX = 0;
      if (_vY.abs() < 0.01) _vY = 0;
    });
  }

  // ── 球面投影 ──────────────────────────────────────────────────────────────

  ({Offset pos, double depth})? _project(
      double latDeg, double lngDeg, Offset center, double r) {
    final latR = latDeg * pi / 180;
    final lngR = lngDeg * pi / 180;
    return _projectRad(latR, lngR, center, r);
  }

  ({Offset pos, double depth})? _projectRad(
      double latR, double lngR, Offset center, double r) {
    double x0 = cos(latR) * sin(lngR);
    double y0 = sin(latR);
    double z0 = cos(latR) * cos(lngR);

    final cosX = cos(_rotX), sinX = sin(_rotX);
    final y1 = y0 * cosX - z0 * sinX;
    final z1 = y0 * sinX + z0 * cosX;

    final cosY = cos(_rotY), sinY = sin(_rotY);
    final x2 = x0 * cosY + z1 * sinY;
    final z2 = -x0 * sinY + z1 * cosY;

    if (z2 < -0.02) return null;

    final depth = ((z2 + 1) / 2).clamp(0.0, 1.0);
    return (
      pos: Offset(center.dx + x2 * r, center.dy - y1 * r),
      depth: depth,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// 与 [MainScaffold] 一致：extendBody 下内容铺满屏底，需把操作区抬到悬浮导航栏之上。
  /// bottomNavigationBar 为 `Padding(bottom:20) + 高68` → 距屏底约 88px 到导航顶。
  static const double _kMainNavBarReserve =
      20.0 + 68.0 + 24.0; // 外边距 + 导航条 + 与导航的间距

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 使用 LayoutBuilder 获取实际可用区域，避免 MediaQuery 包含导航栏高度
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final bottomSafe = MediaQuery.paddingOf(context).bottom;
      final globeActionsBottom = _kMainNavBarReserve + bottomSafe;

      // 球半径：取宽高较小值的 42%，确保地球完整显示在屏幕内
      _globeR = (w < h ? w : h) * 0.42;
      // 球心：水平居中，整体下移 80px
      // 相对基准下移 60px（原 +80，整体上移 20px）
      _globeCenter = Offset(w / 2, h * 0.42 + 60.0);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 点击空白区域关闭卡片
        onTap: () {
          if (_selected != null) setState(() => _selected = null);
        },
        onPanStart: (d) {
          _isDragging = true;
          _vX = 0;
          _vY = 0;
          _startGX = d.globalPosition.dx;
          _startGY = d.globalPosition.dy;
          _rotXStart = _rotX;
          _rotYStart = _rotY;
        },
        onPanUpdate: (d) {
          setState(() {
            final dx = d.globalPosition.dx - _startGX;
            final dy = d.globalPosition.dy - _startGY;
            _rotX = (_rotXStart + dy / h * pi * 0.75)
                .clamp(-pi / 2.05, pi / 2.05);
            _rotY = _rotYStart + dx / w * pi * 1.0;
          });
        },
        onPanEnd: (d) {
          _isDragging = false;
          _vX = d.velocity.pixelsPerSecond.dy / h * pi * 2.8;
          _vY = d.velocity.pixelsPerSecond.dx / w * pi * 2.8;
          _lastTickTime = null;
        },
        child: Stack(
          children: [
            // ① 星空背景
            const Positioned.fill(
              child: RepaintBoundary(child: _StarfieldBg()),
            ),

            // ② 顶部标题 — 居中于导航栏底部与地球顶部之间
            Positioned(
              top: (_globeCenter.dy - _globeR) * 0.18,
              bottom: h - (_globeCenter.dy - _globeR) + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFCB9EFF)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: const Text(
                          '在全球寻找你的',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFCB9EFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: const Text(
                        'Agent 伙伴',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          height: 1.3,
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 700.ms).slideY(begin: -0.12, curve: Curves.easeOut),
            ),

            // ③ 地球球体（经纬线 + 光晕）
            Positioned(
              left: _globeCenter.dx - _globeR,
              top: _globeCenter.dy - _globeR,
              child: SizedBox(
                width: _globeR * 2,
                height: _globeR * 2,
                child: CustomPaint(
                  painter: _GlobeBodyPainter(
                    rotX: _rotX,
                    rotY: _rotY,
                    radius: _globeR,
                  ),
                ),
              ),
            ),

            // ④ 球面头像标记
            ..._buildMarkers(_globeCenter, _globeR),

            // ④½ 底部「推荐 / 附近 / 随机」快捷图标（主导航栏之上）
            Positioned(
              left: 24,
              right: 24,
              // 相对「-28-80」再上移 50px → bottom 增加 50
              bottom: globeActionsBottom - 28 - 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlobeMiniIcon(
                    icon: Icons.auto_awesome_rounded,
                    label: '推荐',
                    gradientColors: const [
                      Color(0xFF7C3AED),
                      Color(0xFFEC4899),
                    ],
                    onTap: () {},
                  ),
                  const SizedBox(width: 28),
                  _GlobeMiniIcon(
                    icon: Icons.near_me_rounded,
                    label: '附近',
                    gradientColors: const [
                      Color(0xFF0EA5E9),
                      Color(0xFF10B981),
                    ],
                    onTap: () {},
                  ),
                  const SizedBox(width: 28),
                  _GlobeMiniIcon(
                    icon: Icons.shuffle_rounded,
                    label: '随机',
                    gradientColors: const [
                      Color(0xFF8B5CF6),
                      Color(0xFF06B6D4),
                    ],
                    onTap: () {},
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 520.ms, duration: 420.ms).slideY(
                  begin: 0.15,
                  curve: Curves.easeOut,
                ),

          // ⑤ 气泡卡片：避开底部快捷图标 + 主导航栏占位
          Positioned(
            top: 0,
            bottom: globeActionsBottom + 92,
            left: 16,
            right: 16,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.08),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _selected != null
                    ? _buildBubbleCard(_selected!,
                        key: ValueKey(_selected!.id))
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
          ),

          ],
        ),
      );
    });
  }

  // ── 标记点列表 ────────────────────────────────────────────────────────────

  List<Widget> _buildMarkers(Offset center, double globeR) {
    final projected = <({GlobeAgent agent, Offset pos, double depth})>[];

    for (final agent in _mockAgents) {
      final r = _project(agent.lat, agent.lng, center, globeR);
      if (r == null) continue;
      if (r.depth < 0.06) continue;
      projected.add((agent: agent, pos: r.pos, depth: r.depth));
    }

    projected.sort((a, b) => a.depth.compareTo(b.depth));

    return projected.map((p) {
      final scale = 0.32 + p.depth * 0.68;
      final opacity = (0.18 + p.depth * 0.82).clamp(0.0, 1.0);
      final isSelected = _selected?.id == p.agent.id;

      return Positioned(
        left: p.pos.dx,
        top: p.pos.dy,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () => setState(
                    () => _selected = isSelected ? null : p.agent,
                  ),
                  child: _SoulMarker(
                    agent: p.agent,
                    selected: isSelected,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── AI 伙伴气泡卡片 ───────────────────────────────────────────────────────

  static const _companionNames = [
    '星辰', 'Nova AI', '灵感缪斯', 'Lumina', '幻想家', '引路人', 'Aura', '智能先锋',
    '漫游者', 'Oracle', '创作精灵', 'Spark', '深海之声', 'Nexus', '光影师', '量子',
    'Aria', '旅行家', '极光', '梦境编织者',
  ];

  static const _companionDescs = [
    '擅长创意写作，随时激发你的灵感火花',
    '你的全天候旅行规划助手，走遍世界',
    '深度情感陪伴，懂你的每一个心情',
    '精通多语言翻译，沟通无国界',
    '专业代码审查与调试，Bug 克星',
    '健康生活顾问，科学饮食运动方案',
    '音乐创作搭档，谱出你的专属旋律',
    '哲学思辨伙伴，探索存在的意义',
    '财务规划专家，让财富稳步增长',
    '历史文化解说，带你穿越古今',
    '摄影美学导师，每张照片都是艺术',
    '冥想引导师，找回内心的平静',
    '故事讲述者，每个夜晚都有精彩',
    '学习加速器，高效掌握任何技能',
    '心理疏导师，温柔聆听你的困惑',
    '科学探索者，解答宇宙的奥秘',
    '美食推荐官，发现城市里的好味道',
    '职场导师，助力你的职业成长',
    '游戏策略大师，陪你征服每个关卡',
    '未来预测家，洞察时代的脉搏',
  ];

  /// 气泡卡片：仅封面区域 1.5×，内边距与字号等保持初版
  static const double _kBubbleCoverSide = 152.0 * 1.5;
  static const double _kBubbleInset = 14.0;
  static const double _kBubbleCardWidth = _kBubbleCoverSide + _kBubbleInset * 2;

  static const List<String> _kBubbleIpImages = [
    'images/ip0.png', 'images/ip1.png', 'images/ip2.png', 'images/ip3.png',
    'images/ip4.png', 'images/ip5.png', 'images/ip7.png',
  ];

  Widget _buildBubbleCard(GlobeAgent agent, {Key? key}) {
    final idx = agent.id.hashCode.abs() % _companionNames.length;
    final companionName = _companionNames[idx];
    final companionDesc = _companionDescs[idx];
    final ipImage = _kBubbleIpImages[idx % _kBubbleIpImages.length];

    return GestureDetector(
      // 卡片内部点击不冒泡到外层（防止误触关闭）
      onTap: () {},
      child: Container(
        key: key,
        width: _kBubbleCardWidth,
        decoration: BoxDecoration(
          color: StarpathColors.surfaceContainer.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: StarpathColors.primary.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 顶部：头像 + 名称 + 地点（左）｜关闭按钮（右）──────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kBubbleInset,
                _kBubbleInset,
                _kBubbleInset - 4,
                10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UserAvatar(
                    user: agent.userBrief,
                    size: 32,
                    useRandomAvatar: true,
                    cornerRatio: 0.45,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          agent.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: StarpathColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 11, color: StarpathColors.primary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                agent.city,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: StarpathColors.onSurfaceVariant
                                      .withValues(alpha: 0.85),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StarpathColors.surfaceContainerHigh
                            .withValues(alpha: 0.8),
                        border: Border.all(
                          color: StarpathColors.outlineVariant
                              .withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: StarpathColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 封面图 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kBubbleInset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: _kBubbleCoverSide,
                  height: _kBubbleCoverSide,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2D0E5A), Color(0xFF1A0840)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: StarpathColors.primaryGradient,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'AI 伙伴',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Image.asset(
                          ipImage,
                          width: _kBubbleCoverSide,
                          height: _kBubbleCoverSide,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            _kBubbleIpImages[0],
                            width: _kBubbleCoverSide,
                            height: _kBubbleCoverSide,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── AI 伙伴名称 + 描述 ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  _kBubbleInset, 12, _kBubbleInset, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companionName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: StarpathColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    companionDesc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: StarpathColors.onSurfaceVariant,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── 前往聊天 按钮 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  _kBubbleInset, 12, _kBubbleInset, _kBubbleInset),
              child: GestureDetector(
                onTap: () => context.push('/chat/agent/${agent.id}'),
                child: Container(
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: StarpathColors.primaryGradient,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: StarpathColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    '前往聊天',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 地球球体 CustomPainter ────────────────────────────────────────────────────

class _GlobeBodyPainter extends CustomPainter {
  final double rotX;
  final double rotY;
  final double radius;

  const _GlobeBodyPainter({
    required this.rotX,
    required this.rotY,
    required this.radius,
  });

  Offset? _proj(double latR, double lngR) {
    final cx = radius, cy = radius;
    final r = radius;

    double x0 = cos(latR) * sin(lngR);
    double y0 = sin(latR);
    double z0 = cos(latR) * cos(lngR);

    final cosX = cos(rotX), sinX = sin(rotX);
    final y1 = y0 * cosX - z0 * sinX;
    final z1 = y0 * sinX + z0 * cosX;

    final cosY = cos(rotY), sinY = sin(rotY);
    final x2 = x0 * cosY + z1 * sinY;
    final z2 = -x0 * sinY + z1 * cosY;

    if (z2 < 0) return null;
    return Offset(cx + x2 * r, cy - y1 * r);
  }

  // ── 紫色系调色板 ─────────────────────────────────────────────────────────
  static const _purpleDeep   = Color(0xFF0D0520); // 极深紫黑，球心暗部
  static const _purpleMid    = Color(0xFF1E0A4A); // 中深紫
  static const _purpleLight  = Color(0xFF3D1A8A); // 亮侧紫
  static const _violet       = Color(0xFF7C3AED); // 紫色网格线
  static const _violetBright = Color(0xFF9B5FFF); // 赤道加强线
  static const _pinkPurple   = Color(0xFFD175FF); // 极地光晕
  static const _outerGlow1   = Color(0xFF8B3FE8); // 大气外发光核心
  static const _outerGlow2   = Color(0xFFB76EFF); // 大气外发光边缘

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(radius, radius);
    final r = radius;
    final rect = Rect.fromCircle(center: center, radius: r);

    // ── ① 外发光（弱化：减小范围和透明度）──────────────────────────────────
    canvas.drawCircle(
      center,
      r * 1.28,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
        ..color = _outerGlow1.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      center,
      r * 1.08,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..color = _outerGlow2.withValues(alpha: 0.22),
    );

    // ── ② 以下内容裁剪在球体内 ────────────────────────────────────────────
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // 深紫渐变底色：从左上亮紫 → 右下极深紫黑
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.30, -0.38),
          radius: 1.30,
          colors: [
            _purpleLight,
            _purpleMid,
            _purpleDeep,
          ],
          stops: [0.0, 0.50, 1.0],
        ).createShader(rect),
    );

    // 球内底部反光：让底部有一圈紫粉透光感
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.75),
          radius: 0.70,
          colors: [
            _pinkPurple.withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // 纬线（每 30°）
    _drawLatLines(canvas, center, r);

    // 经线（每 30°）
    _drawLngLines(canvas, center, r);

    // 赤道加粗
    _drawEquator(canvas, center, r);

    // 极地光晕
    _drawPolarGlow(canvas, center, r);

    // 镜面高光（左上白色反光）
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.60),
          radius: 0.50,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(rect),
    );

    canvas.restore();

    // ── ③ 边缘暗边：加深轮廓，增加球体立体感 ─────────────────────────────
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [
            Colors.transparent,
            _purpleDeep.withValues(alpha: 0.88),
          ],
          stops: const [0.82, 1.0],
        ).createShader(rect),
    );
  }

  void _drawLatLines(Canvas canvas, Offset center, double r) {
    // 主纬线每 20°，高亮
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _violet.withValues(alpha: 0.55)
      ..isAntiAlias = true;
    // 细分纬线每 10°（主纬线之间），稍暗
    final subPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = _violet.withValues(alpha: 0.28)
      ..isAntiAlias = true;

    for (var latDeg = -80; latDeg <= 80; latDeg += 10) {
      final isMain = latDeg % 20 == 0;
      _drawLatCircle(canvas, latDeg * pi / 180, isMain ? mainPaint : subPaint);
    }
  }

  void _drawLatCircle(Canvas canvas, double latR, Paint paint) {
    final path = Path();
    bool drawing = false;
    for (var lngDeg = -180; lngDeg <= 182; lngDeg += 2) {
      final p = _proj(latR, lngDeg * pi / 180);
      if (p == null) { drawing = false; continue; }
      if (!drawing) { path.moveTo(p.dx, p.dy); drawing = true; }
      else { path.lineTo(p.dx, p.dy); }
    }
    canvas.drawPath(path, paint);
  }

  void _drawLngLines(Canvas canvas, Offset center, double r) {
    // 主经线每 20°
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _violet.withValues(alpha: 0.48)
      ..isAntiAlias = true;
    // 细分经线每 10°
    final subPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = _violet.withValues(alpha: 0.24)
      ..isAntiAlias = true;

    for (var lngDeg = -180; lngDeg < 180; lngDeg += 10) {
      final isMain = lngDeg % 20 == 0;
      _drawLngCircle(canvas, lngDeg * pi / 180, isMain ? mainPaint : subPaint);
    }
  }

  void _drawLngCircle(Canvas canvas, double lngR, Paint paint) {
    final path = Path();
    bool drawing = false;
    for (var latDeg = -90; latDeg <= 92; latDeg += 2) {
      final p = _proj(latDeg * pi / 180, lngR);
      if (p == null) { drawing = false; continue; }
      if (!drawing) { path.moveTo(p.dx, p.dy); drawing = true; }
      else { path.lineTo(p.dx, p.dy); }
    }
    canvas.drawPath(path, paint);
  }

  void _drawEquator(Canvas canvas, Offset center, double r) {
    // 赤道：外层柔光 + 内层亮线
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = _violetBright.withValues(alpha: 0.30)
      ..isAntiAlias = true;
    _drawLatCircle(canvas, 0, glowPaint);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _violetBright.withValues(alpha: 0.88)
      ..isAntiAlias = true;
    _drawLatCircle(canvas, 0, corePaint);
  }

  void _drawPolarGlow(Canvas canvas, Offset center, double r) {
    for (final entry in [(pi / 2, 0.60), (-pi / 2, 0.45)]) {
      final p = _proj(entry.$1, 0);
      if (p == null) continue;
      canvas.drawCircle(
        p,
        r * 0.12,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _pinkPurple.withValues(alpha: entry.$2),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r * 0.12)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlobeBodyPainter old) =>
      old.rotX != rotX || old.rotY != rotY;
}

// ── Soul App 风格头像标记 ──────────────────────────────────────────────────────

class _SoulMarker extends StatelessWidget {
  final GlobeAgent agent;
  final bool selected;

  static const double _avatarSize = 42;

  const _SoulMarker({required this.agent, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = StarpathColors.avatarAccentFor(agent.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _avatarSize + (selected ? 6 : 0),
          height: _avatarSize + (selected ? 6 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? StarpathColors.primary
                  : color.withValues(alpha: 0.6),
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: StarpathColors.primary.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                    )
                  ],
          ),
          child: ClipOval(
            child: UserAvatar(
              user: agent.userBrief,
              size: _avatarSize + (selected ? 6 : 0),
              useRandomAvatar: true,
              cornerRatio: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: StarpathColors.surfaceContainer.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            agent.name,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: selected
                  ? StarpathColors.primary
                  : StarpathColors.onSurface.withValues(alpha: 0.9),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── 地球下方快捷图标（推荐 / 附近 / 随机）──────────────────────────────────────

class _GlobeMiniIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _GlobeMiniIcon({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_GlobeMiniIcon> createState() => _GlobeMiniIconState();
}

class _GlobeMiniIconState extends State<_GlobeMiniIcon> {
  bool _pressed = false;

  /// 略小于 1.5× 初版；下方文案字号不变。
  static const double _circleSide = 60;
  static const double _glyphSize = 30;

  @override
  Widget build(BuildContext context) {
    final g = widget.gradientColors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _circleSide,
              height: _circleSide,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    g[0].withValues(alpha: 0.92),
                    g[1].withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.38),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: g[0].withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: _glyphSize,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Starfield Background ──────────────────────────────────────────────────────

class _StarfieldBg extends StatelessWidget {
  const _StarfieldBg();

  static final List<({Offset pos, double size, double opacity})> _stars =
      _generate();

  static List<({Offset pos, double size, double opacity})> _generate() {
    final rng = Random(42);
    return List.generate(
      150,
      (_) => (
        pos: Offset(rng.nextDouble(), rng.nextDouble()),
        size: 0.6 + rng.nextDouble() * 1.8,
        opacity: 0.15 + rng.nextDouble() * 0.65,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(_stars));
  }
}

class _StarPainter extends CustomPainter {
  final List<({Offset pos, double size, double opacity})> stars;
  const _StarPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0318), Color(0xFF180720), Color(0xFF100520)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size),
    );

    final paint = Paint()..isAntiAlias = true;
    for (final s in stars) {
      paint.color = Colors.white.withValues(alpha: s.opacity);
      canvas.drawCircle(
        Offset(s.pos.dx * size.width, s.pos.dy * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
