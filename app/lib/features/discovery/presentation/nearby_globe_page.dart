import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    // 拖拽中 或 已选中头像（卡片展示中）→ 冻结地球，停止一切旋转
    if (dt <= 0 || dt > 0.05 || _isDragging || _selected != null) return;

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 使用 LayoutBuilder 获取实际可用区域，避免 MediaQuery 包含导航栏高度
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      // 球半径：取宽高较小值的 42%，确保地球完整显示在屏幕内
      _globeR = (w < h ? w : h) * 0.42;
      // 球心：水平居中，垂直居中偏上一点（留出底部气泡卡片空间）
      _globeCenter = Offset(w / 2, h * 0.46);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
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

            // ② 地球球体（经纬线 + 光晕）
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

            // ③ 球面头像标记
            ..._buildMarkers(_globeCenter, _globeR),

            // ④ 底部提示
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '拖动旋转  探索全球 AI 伙伴',
                  style: TextStyle(
                    fontSize: 12,
                    color: StarpathColors.onSurfaceVariant
                        .withValues(alpha: 0.55),
                    letterSpacing: 0.5,
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
            ),

          // ⑤ 气泡卡片（AnimatedSwitcher 包裹，仅在 selected 变化时播动画）
          Positioned(
            top: 68,
            left: 16,
            right: 16,
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
                  ? _buildBubbleCard(_selected!, key: ValueKey(_selected!.id))
                  : const SizedBox.shrink(key: ValueKey('empty')),
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

  Widget _buildBubbleCard(GlobeAgent agent, {Key? key}) {
    final idx = agent.id.hashCode.abs() % _companionNames.length;
    final companionName = _companionNames[idx];
    final companionDesc = _companionDescs[idx];
    // pravatar.cc img 参数 1-70，用 idx+1 循环确保稳定加载
    final avatarUrl = 'https://i.pravatar.cc/128?img=${(idx % 70) + 1}';

    return Container(
      key: key,
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
          children: [
            // 关闭按钮
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, right: 12),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: StarpathColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            // 头像 + 名称 + 描述
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      avatarUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: StarpathColors.primaryGradient,
                        ),
                        child: Center(
                          child: Text(
                            companionName.characters.first,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                companionName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: StarpathColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
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
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          companionDesc,
                          style: const TextStyle(
                            fontSize: 12,
                            color: StarpathColors.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: StarpathColors.outlineVariant.withValues(alpha: 0.15),
            ),
            // 用户信息行 + 前往聊天
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  UserAvatar(
                    user: agent.userBrief,
                    size: 28,
                    useRandomAvatar: true,
                    cornerRatio: 0.4,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: StarpathColors.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 11, color: StarpathColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              agent.city,
                              style: const TextStyle(
                                fontSize: 11,
                                color: StarpathColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
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
                ],
              ),
            ),
          ],
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
        ..shader = RadialGradient(
          center: const Alignment(-0.30, -0.38),
          radius: 1.30,
          colors: const [
            _purpleLight,
            _purpleMid,
            _purpleDeep,
          ],
          stops: const [0.0, 0.50, 1.0],
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
