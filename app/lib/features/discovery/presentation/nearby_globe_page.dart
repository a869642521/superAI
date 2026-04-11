import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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

// ── Mock Data ─────────────────────────────────────────────────────────────────

// 球面均匀随机分布，seed 固定保证每次相同
final _mockAgents = _generateAgents();

List<GlobeAgent> _generateAgents() {
  const names = [
    '星际旅人', 'Luna', 'Muse', 'Sakura', 'Aurora',
    'Prism', 'Echo', 'Nova', 'Drift', 'Zen',
    '夜雨', 'Pixel', 'Lyra', 'Cipher', 'Volta',
    '光年', 'Iris', 'Spark', 'Vega', 'Nebula',
  ];
  const cities = [
    '北京', '纽约', '巴黎', '东京', '奥斯陆',
    '悉尼', '伦敦', '新德里', '圣保罗', '洛杉矶',
    '上海', '旧金山', '莫斯科', '新加坡', '约翰内斯堡',
    '深圳', '伊斯坦布尔', '墨西哥城', '迪拜', '蒙特利尔',
  ];
  final rng = Random(0x5A7EBA11);
  return List.generate(names.length, (i) {
    final theta = acos(1 - 2 * rng.nextDouble());
    final phi = rng.nextDouble() * 2 * pi;
    final lat = (pi / 2 - theta) * 180 / pi;
    final lng = phi * 180 / pi - 180;
    return GlobeAgent(
      id: 'ga${(i + 1).toString().padLeft(2, '0')}',
      name: names[i],
      lat: lat,
      lng: lng,
      city: cities[i],
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
    with TickerProviderStateMixin {
  double _rotX = 0.25;
  double _rotY = -2.0; // 初始朝向中国

  double _dragStartGX = 0;
  double _dragStartGY = 0;
  double _rotXStart = 0;
  double _rotYStart = 0;

  // 惯性动画
  late AnimationController _inertiaX;
  late AnimationController _inertiaY;
  FrictionSimulation? _simX;
  FrictionSimulation? _simY;

  GlobeAgent? _selected;

  @override
  void initState() {
    super.initState();
    _inertiaX = AnimationController.unbounded(vsync: this)
      ..addListener(_tickInertia);
    _inertiaY = AnimationController.unbounded(vsync: this)
      ..addListener(_tickInertia);
  }

  @override
  void dispose() {
    _inertiaX.dispose();
    _inertiaY.dispose();
    super.dispose();
  }

  void _tickInertia() {
    setState(() {
      if (_simX != null) _rotX = _simX!.x(_inertiaX.value).clamp(-pi / 2.2, pi / 2.2);
      if (_simY != null) _rotY = _simY!.x(_inertiaY.value);
    });
  }

  void _stopInertia() {
    _inertiaX.stop();
    _inertiaY.stop();
    _simX = null;
    _simY = null;
  }

  // ── 球面投影 ──────────────────────────────────────────────────────────────

  ({Offset pos, double depth})? _project(
    GlobeAgent agent,
    Offset center,
    double radius,
  ) {
    return _projectLatLng(agent.lat, agent.lng, center, radius);
  }

  ({Offset pos, double depth})? _projectLatLng(
    double lat,
    double lng,
    Offset center,
    double radius,
  ) {
    final latR = lat * pi / 180;
    final lngR = lng * pi / 180;

    double x0 = cos(latR) * sin(lngR);
    double y0 = sin(latR);
    double z0 = cos(latR) * cos(lngR);

    final cosX = cos(_rotX), sinX = sin(_rotX);
    final y1 = y0 * cosX - z0 * sinX;
    final z1 = y0 * sinX + z0 * cosX;

    final cosY = cos(_rotY), sinY = sin(_rotY);
    final x2 = x0 * cosY + z1 * sinY;
    final z2 = -x0 * sinY + z1 * cosY;

    if (z2 < -0.05) return null;

    final screenX = center.dx + x2 * radius;
    final screenY = center.dy - y1 * radius;
    final depth = ((z2 + 1) / 2).clamp(0.0, 1.0);

    return (pos: Offset(screenX, screenY), depth: depth);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final globeR = size.width * 0.42;
    final center = Offset(size.width / 2, size.height * 0.42);

    return GestureDetector(
      onPanStart: (d) {
        _stopInertia();
        _dragStartGX = d.globalPosition.dx;
        _dragStartGY = d.globalPosition.dy;
        _rotXStart = _rotX;
        _rotYStart = _rotY;
      },
      onPanUpdate: (d) {
        setState(() {
          final dx = d.globalPosition.dx - _dragStartGX;
          final dy = d.globalPosition.dy - _dragStartGY;
          _rotX = (_rotXStart + dy / size.height * pi * 0.6)
              .clamp(-pi / 2.2, pi / 2.2);
          _rotY = _rotYStart + dx / size.width * pi * 0.8;
        });
      },
      onPanEnd: (d) {
        final vx = d.velocity.pixelsPerSecond.dy / size.height * pi * 0.6;
        final vy = d.velocity.pixelsPerSecond.dx / size.width * pi * 0.8;

        const drag = 2.5;

        if (vx.abs() > 0.05) {
          _simX = FrictionSimulation(drag, _rotX, vx);
          _inertiaX
            ..value = 0
            ..animateWith(_simX!);
        }
        if (vy.abs() > 0.05) {
          _simY = FrictionSimulation(drag, _rotY, vy);
          _inertiaY
            ..value = 0
            ..animateWith(_simY!);
        }
      },
      child: Stack(
        children: [
          Positioned.fill(child: _StarfieldBg()),

          Positioned.fill(
            child: CustomPaint(
              painter: _GlobePainter(rotX: _rotX, rotY: _rotY),
            ),
          ),

          ..._buildMarkers(center, globeR),

          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '拖动旋转地球  探索全球 AI 伙伴',
                style: TextStyle(
                  fontSize: 13,
                  color: StarpathColors.onSurfaceVariant.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
          ),

          if (_selected != null) _buildBubbleCard(_selected!),
        ],
      ),
    );
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  List<Widget> _buildMarkers(Offset center, double globeR) {
    final projected = <({GlobeAgent agent, Offset pos, double depth})>[];

    for (final agent in _mockAgents) {
      final r = _project(agent, center, globeR);
      if (r == null) continue;
      if (r.depth < 0.08) continue; // 过滤极边缘点，避免贴轮廓线
      projected.add((agent: agent, pos: r.pos, depth: r.depth));
    }

    projected.sort((a, b) => a.depth.compareTo(b.depth));

    return projected.map((p) {
      final scale = 0.55 + p.depth * 0.55;
      final opacity = 0.35 + p.depth * 0.65;

      return Positioned(
        left: p.pos.dx,
        top: p.pos.dy,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -1.0),
          child: GestureDetector(
            onTap: () => setState(
              () => _selected = _selected?.id == p.agent.id ? null : p.agent,
            ),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: _AgentMarker(
                  agent: p.agent,
                  avatarSize: 38,
                  selected: _selected?.id == p.agent.id,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── AI 伙伴气泡卡片 ──────────────────────────────────────────────────────────

  static const _companionNames = [
    '星辰', 'Nova AI', '灵感缪斯', 'Lumina', '幻想家',
    '引路人', 'Aura', '智能先锋', '漫游者', 'Oracle',
    '创作精灵', 'Spark', '深海之声', 'Nexus', '光影师',
    '量子', 'Aria', '旅行家', '极光', '梦境编织者',
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

  Widget _buildBubbleCard(GlobeAgent agent) {
    final idx = agent.id.hashCode.abs() % _companionNames.length;
    final companionName = _companionNames[idx];
    final companionDesc = _companionDescs[idx];
    final companionSeed = 'companion_${agent.id}';
    final companionUser = UserBrief(id: companionSeed, nickname: companionName);
    final companionAvatarUrl =
        'https://api.dicebear.com/9.x/adventurer/png?seed=$companionSeed&size=160';

    return Positioned(
      bottom: 80,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: () {}, // 点卡片内部不消失
        child: Container(
          decoration: BoxDecoration(
            color: StarpathColors.surfaceContainer.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: StarpathColors.primary.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: StarpathColors.primary.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 关闭按钮 ──────────────────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, right: 12),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: StarpathColors.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              // ── 顶部：AI 伙伴头像 + 名称 + 徽章 ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        companionAvatarUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => UserAvatar(
                          user: companionUser,
                          size: 56,
                          useRandomAvatar: true,
                          cornerRatio: 0.25,
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
              // ── 分割线 ────────────────────────────────────────────────────
              Divider(
                height: 1,
                thickness: 1,
                color: StarpathColors.outlineVariant.withValues(alpha: 0.15),
              ),
              // ── 底部：创建者 + 前往聊天 ────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              const Icon(
                                Icons.location_on_rounded,
                                size: 11,
                                color: StarpathColors.primary,
                              ),
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
                              color: StarpathColors.primary
                                  .withValues(alpha: 0.4),
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
        )
            .animate()
            .fadeIn(duration: 220.ms)
            .slideY(begin: 0.15, duration: 220.ms, curve: Curves.easeOutCubic),
      ),
    );
  }
}

// ── Agent Marker Widget ───────────────────────────────────────────────────────

class _AgentMarker extends StatelessWidget {
  final GlobeAgent agent;
  final double avatarSize;
  final bool selected;

  const _AgentMarker({
    required this.agent,
    required this.avatarSize,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected
                ? StarpathColors.primaryGradient
                : LinearGradient(
                    colors: [
                      StarpathColors.primary.withValues(alpha: 0.7),
                      StarpathColors.secondary.withValues(alpha: 0.5),
                    ],
                  ),
            boxShadow: [
              BoxShadow(
                color: StarpathColors.primary
                    .withValues(alpha: selected ? 0.8 : 0.45),
                blurRadius: selected ? 18 : 10,
                spreadRadius: selected ? 2 : 0,
              ),
            ],
          ),
          child: ClipOval(
            child: UserAvatar(
              user: agent.userBrief,
              size: avatarSize,
              useRandomAvatar: true,
              cornerRatio: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: StarpathColors.surfaceContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: StarpathColors.primary.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            agent.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: StarpathColors.onSurface,
              height: 1.2,
            ),
          ),
        ),
        // 针尖 — 底部锚定到球面点
        Container(
          width: 2,
          height: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                StarpathColors.primary.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Globe CustomPainter ───────────────────────────────────────────────────────

class _GlobePainter extends CustomPainter {
  final double rotX;
  final double rotY;

  const _GlobePainter({required this.rotX, required this.rotY});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final center = Offset(cx, cy);
    final r = size.width * 0.42;

    // 裁剪球体区域（确保网格/大陆不溢出）
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // 1. 外发光
    final outerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7B4FC8).withValues(alpha: 0.0),
          const Color(0xFF4A1A8A).withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.55, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.45));
    canvas.restore();
    canvas.drawCircle(center, r * 1.45, outerGlow);

    // 重新裁剪
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // 2. 球体渐变主体
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: [
          Color(0xFFB07AE8),
          Color(0xFF7B4FC8),
          Color(0xFF4A20A0),
          Color(0xFF1E0A52),
        ],
        stops: [0.0, 0.38, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    // 3. 极淡经纬网格
    _drawGrid(canvas, center, r);

    // 4. 大陆轮廓
    _drawContinents(canvas, center, r);

    // 5. 球体边缘暗化
    final edgePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.45),
        ],
        stops: const [0.0, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, edgePaint);

    // 6. 高光
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.55),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, highlightPaint);

    canvas.restore();
  }

  // ── 经纬网格（极淡） ───────────────────────────────────────────────────────

  void _drawGrid(Canvas canvas, Offset center, double r) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = StarpathColors.primary.withValues(alpha: 0.08);

    for (int lng = 0; lng < 360; lng += 30) {
      final lngR = lng * pi / 180;
      final path = Path();
      bool first = true;
      for (int lat = -90; lat <= 90; lat += 4) {
        final latR = lat * pi / 180;
        final pt = _projectPoint(latR, lngR, center, r);
        if (pt == null) {
          first = true;
          continue;
        }
        if (first) {
          path.moveTo(pt.dx, pt.dy);
          first = false;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    for (int lat = -60; lat <= 60; lat += 30) {
      final latR = lat * pi / 180;
      final path = Path();
      bool first = true;
      for (int lng = 0; lng <= 360; lng += 4) {
        final lngR = lng * pi / 180;
        final pt = _projectPoint(latR, lngR, center, r);
        if (pt == null) {
          first = true;
          continue;
        }
        if (first) {
          path.moveTo(pt.dx, pt.dy);
          first = false;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }
  }

  // ── 大陆轮廓 ──────────────────────────────────────────────────────────────

  void _drawContinents(Canvas canvas, Offset center, double r) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFCC97FF).withValues(alpha: 0.45);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFE8C4FF).withValues(alpha: 0.65);

    for (final continent in _continents) {
      _drawOneContinent(canvas, center, r, continent, fillPaint, strokePaint);
    }
  }

  void _drawOneContinent(
    Canvas canvas,
    Offset center,
    double r,
    List<(double, double)> points,
    Paint fill,
    Paint stroke,
  ) {
    if (points.length < 3) return;

    // 检测该大陆是否有任何可见点
    final projected = <Offset>[];
    bool anyVisible = false;
    for (final (lat, lng) in points) {
      final pt = _projectPoint(lat * pi / 180, lng * pi / 180, center, r);
      if (pt != null) {
        projected.add(pt);
        anyVisible = true;
      } else {
        // 背面点也取边缘近似，防止大陆被截成锯齿
        projected.add(_projectPointClamped(lat * pi / 180, lng * pi / 180, center, r));
      }
    }
    if (!anyVisible) return;

    final path = Path()..moveTo(projected[0].dx, projected[0].dy);
    for (int i = 1; i < projected.length; i++) {
      path.lineTo(projected[i].dx, projected[i].dy);
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  /// 和 _projectPoint 相同，但 z < 0 时不返回 null，
  /// 而是把点推到球体边缘（夹到赤道圈上）。
  Offset _projectPointClamped(
      double latR, double lngR, Offset center, double r) {
    double x0 = cos(latR) * sin(lngR);
    double y0 = sin(latR);
    double z0 = cos(latR) * cos(lngR);

    final cosX = cos(rotX), sinX = sin(rotX);
    final y1 = y0 * cosX - z0 * sinX;
    final z1 = y0 * sinX + z0 * cosX;

    final cosY = cos(rotY), sinY = sin(rotY);
    final x2 = x0 * cosY + z1 * sinY;
    final z2 = -x0 * sinY + z1 * cosY;

    if (z2 >= 0) {
      return Offset(center.dx + x2 * r, center.dy - y1 * r);
    }

    // 背面：投射到球体视觉边缘
    final len = sqrt(x2 * x2 + y1 * y1);
    if (len < 0.001) return center;
    final nx = x2 / len;
    final ny = -y1 / len;
    return Offset(center.dx + nx * r, center.dy + ny * r);
  }

  Offset? _projectPoint(double latR, double lngR, Offset center, double r) {
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
    return Offset(center.dx + x2 * r, center.dy - y1 * r);
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      old.rotX != rotX || old.rotY != rotY;
}

// ── 简化七大洲海岸线数据 (lat, lng) ──────────────────────────────────────────

const List<List<(double, double)>> _continents = [
  _northAmerica,
  _southAmerica,
  _europe,
  _africa,
  _asia,
  _oceania,
  _middleEast,
];

const _northAmerica = <(double, double)>[
  (49.0, -125.0), (60.0, -140.0), (65.0, -168.0), (71.0, -157.0),
  (71.5, -130.0), (62.0, -114.0), (60.0, -95.0), (63.0, -82.0),
  (55.0, -77.0), (52.0, -56.0), (47.0, -53.0), (45.0, -66.0),
  (42.0, -70.0), (35.0, -75.0), (25.0, -80.0), (25.5, -97.0),
  (20.0, -105.0), (15.0, -92.0), (15.0, -83.0), (10.0, -84.0),
  (8.0, -77.0), (19.0, -104.0), (23.0, -110.0), (31.0, -115.0),
  (38.0, -123.0), (48.0, -124.0), (49.0, -125.0),
];

const _southAmerica = <(double, double)>[
  (12.0, -72.0), (8.0, -77.0), (4.0, -77.5), (-1.0, -80.0),
  (-5.0, -81.0), (-15.0, -75.0), (-18.0, -70.5), (-23.0, -70.0),
  (-28.0, -71.0), (-33.0, -72.0), (-40.0, -73.0), (-46.0, -75.0),
  (-52.0, -70.0), (-55.0, -68.0), (-55.0, -65.0), (-48.0, -65.0),
  (-41.0, -63.0), (-36.0, -57.0), (-33.0, -52.0), (-23.0, -43.0),
  (-13.0, -38.5), (-5.0, -35.0), (-1.0, -50.0), (5.0, -52.0),
  (7.0, -60.0), (10.0, -62.0), (11.0, -72.0), (12.0, -72.0),
];

const _europe = <(double, double)>[
  (36.0, -6.0), (37.0, -1.0), (43.0, 3.0), (44.0, 9.0),
  (46.0, 14.0), (45.0, 19.0), (42.0, 19.0), (39.0, 20.0),
  (35.0, 24.0), (39.0, 26.0), (41.0, 29.0), (43.0, 28.0),
  (46.0, 30.0), (48.0, 24.0), (54.0, 20.0), (55.0, 28.0),
  (60.0, 30.0), (64.0, 28.0), (70.0, 27.0), (71.0, 25.0),
  (68.0, 14.0), (63.0, 11.0), (58.0, 6.0), (56.0, 8.0),
  (54.0, 8.0), (52.0, 5.0), (51.0, 2.0), (48.0, -5.0),
  (43.5, -8.0), (38.0, -9.5), (36.0, -6.0),
];

const _africa = <(double, double)>[
  (35.0, -1.0), (37.0, 10.0), (33.0, 12.0), (32.0, 24.0),
  (31.0, 32.0), (22.0, 36.0), (12.0, 43.0), (2.0, 42.0),
  (-2.0, 41.0), (-11.0, 40.0), (-15.0, 40.5), (-25.0, 35.0),
  (-34.0, 26.0), (-34.5, 18.0), (-29.0, 16.5), (-22.0, 14.0),
  (-17.0, 12.0), (-13.0, 13.0), (-5.0, 12.0), (5.0, 10.0),
  (6.0, 1.0), (5.0, -4.0), (4.0, -7.5), (8.0, -13.0),
  (12.0, -16.0), (15.0, -17.0), (21.0, -17.0), (27.0, -13.0),
  (32.0, -5.0), (35.0, -1.0),
];

const _asia = <(double, double)>[
  (42.0, 30.0), (43.0, 40.0), (39.0, 44.0), (37.0, 50.0),
  (25.0, 56.0), (24.0, 58.0), (22.0, 60.0), (25.0, 62.0),
  (25.0, 68.0), (28.0, 73.0), (23.0, 78.0), (22.0, 88.0),
  (20.0, 93.0), (17.0, 96.0), (10.0, 99.0), (1.0, 104.0),
  (7.0, 117.0), (22.0, 114.0), (26.0, 120.0), (30.0, 122.0),
  (35.0, 129.0), (39.0, 128.0), (43.0, 132.0), (46.0, 143.0),
  (54.0, 143.0), (59.0, 150.0), (60.0, 163.0), (65.0, 171.0),
  (70.0, 170.0), (72.0, 140.0), (73.0, 120.0), (71.0, 80.0),
  (68.0, 60.0), (62.0, 50.0), (55.0, 40.0), (48.0, 38.0),
  (42.0, 30.0),
];

const _oceania = <(double, double)>[
  (-11.0, 132.0), (-14.0, 127.0), (-21.0, 114.0), (-31.0, 115.0),
  (-35.0, 117.0), (-35.0, 138.0), (-38.0, 145.0), (-37.0, 150.0),
  (-28.0, 153.5), (-24.0, 152.0), (-19.0, 147.0), (-16.0, 146.0),
  (-12.0, 142.0), (-11.0, 132.0),
];

const _middleEast = <(double, double)>[
  (31.5, 34.0), (29.5, 34.8), (22.0, 36.0), (13.0, 43.0),
  (12.0, 45.0), (15.0, 52.0), (22.0, 56.0), (24.0, 56.0),
  (26.0, 51.0), (27.0, 50.0), (30.0, 48.0), (30.5, 47.5),
  (33.0, 44.0), (37.0, 42.0), (37.0, 36.0), (35.0, 36.0),
  (33.0, 35.5), (31.5, 34.0),
];

// ── Starfield Background ──────────────────────────────────────────────────────

class _StarfieldBg extends StatelessWidget {
  final List<({Offset pos, double size, double opacity})> _stars;

  _StarfieldBg() : _stars = _generateStars();

  static List<({Offset pos, double size, double opacity})> _generateStars() {
    final rng = Random(777);
    return List.generate(120, (_) {
      return (
        pos: Offset(rng.nextDouble(), rng.nextDouble()),
        size: 0.8 + rng.nextDouble() * 2.0,
        opacity: 0.2 + rng.nextDouble() * 0.7,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarfieldPainter(stars: _stars),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final List<({Offset pos, double size, double opacity})> stars;

  const _StarfieldPainter({required this.stars});

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_StarfieldPainter old) => false;
}
