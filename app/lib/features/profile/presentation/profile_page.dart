import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/profile/data/profile_mock_data.dart';

/// 个人主页：参考社交类个人页排版（头像 + 数据 + 简介 + 操作 + 亮点 + 内容 Tab + 宫格）。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _contentTab = 0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _evictProfileBgFromImageCache();
      });
    }
  }

  /// 调试：替换 `images/bg.webp` 后若仍显示旧图，清掉该资源的解码缓存（仍需一次完整重启才能更新包内资源）。
  void _evictProfileBgFromImageCache() {
    final scale = MediaQuery.devicePixelRatioOf(context);
    final key = AssetBundleImageKey(
      bundle: DefaultAssetBundle.of(context),
      name: _ProfileAmbientBackground.kAssetPath,
      scale: scale,
    );
    imageCache.evict(key);
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: StarpathColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded,
                    color: StarpathColors.accentViolet),
                title: const Text('我的 AI 伙伴'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/agents');
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded,
                    color: StarpathColors.tertiary),
                title: const Text('我的钱包'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/wallet');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded,
                    color: StarpathColors.onSurfaceVariant),
                title: const Text('设置'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('设置即将开放')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const mock = kProfileMockData;

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ProfileAmbientBackground(),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _openMenu,
                              icon: const Icon(Icons.menu_rounded),
                              color: StarpathColors.onSurfaceVariant,
                              tooltip: '更多',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ProfileAvatar(emoji: mock.avatarEmoji),
                      const SizedBox(height: 12),
                      Text(
                        mock.displayName,
                        style: textTheme.titleMedium?.copyWith(
                          color: StarpathColors.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mock.handle,
                        style: textTheme.labelMedium?.copyWith(
                          color: StarpathColors.onSurfaceVariant
                              .withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _ProfileStatsRow(mock: mock),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            Text(
                              mock.bioTitle,
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium?.copyWith(
                                color: StarpathColors.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              mock.bioBody,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: StarpathColors.onSurfaceVariant
                                    .withValues(alpha: 0.92),
                                height: 1.45,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ProfilePillButton(
                                label: '编辑资料',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(mock.editProfileHint)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ProfilePillButton(
                                label: '分享主页',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(mock.shareProfileHint)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 92,
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0;
                                i < mock.highlights.length;
                                i++) ...[
                              if (i > 0) const SizedBox(width: 18),
                              _SpotlightChip(
                                icon: mock.highlights[i].icon,
                                label: mock.highlights[i].label,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ContentTabBar(
                        selectedIndex: _contentTab,
                        onChanged: (i) => setState(() => _contentTab = i),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (_contentTab == 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProfileGridTile(
                        cell: mock.gridCells[index],
                      ),
                      childCount: mock.gridCells.length,
                    ),
                  ),
                )
              else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      _contentTab == 1
                          ? mock.emptyReelsMessage
                          : mock.emptyTaggedMessage,
                      style: textTheme.bodyMedium?.copyWith(
                        color: StarpathColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 个人页氛围底：`images/bg.webp` 顶部区域 + 下缘渐变融入底色，整图 **30%** 不透明度。
///
/// **替换该文件后若画面不变**：热重载/热重启都不会重新打进包里的资源，请 **完全停止应用** 后再执行一次
/// `flutter run`（必要时在项目 `app/` 下运行 `flutter clean` 再运行）。
class _ProfileAmbientBackground extends StatelessWidget {
  const _ProfileAmbientBackground();

  /// 与 [kAssetPath] 同步，供调试时 [imageCache.evict] 使用。
  static const String kAssetPath = 'images/bg.webp';

  static const double _kBgHeight = 500;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 底色填满全屏
        const ColoredBox(color: StarpathColors.surface),

        // 背景图：固定在顶部 500px，不随内容滚动
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _kBgHeight,
          child: Opacity(
            opacity: 0.2,
            child: Image.asset(
              kAssetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),

        // 黑色渐变遮罩：从透明（顶）→ surface 底色（底），覆盖图片区域
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _kBgHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  StarpathColors.surface,
                ],
                stops: [0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String emoji;

  const _ProfileAvatar({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            StarpathColors.accentViolet,
            StarpathColors.accentViolet.withValues(alpha: 0.55),
            const Color(0xFFFF8AD0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: StarpathColors.accentViolet.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: StarpathColors.surfaceContainerHigh,
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 40)),
        ),
      ),
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  final ProfileMockSnapshot mock;

  const _ProfileStatsRow({required this.mock});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    Widget cell(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: style.titleLarge?.copyWith(
                  color: StarpathColors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: style.labelSmall?.copyWith(
                  color:
                      StarpathColors.onSurfaceVariant.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          cell('${mock.postsCount}', '帖子'),
          cell(mock.followersFormatted, '粉丝'),
          cell('${mock.followingCount}', '关注'),
        ],
      ),
    );
  }
}

class _ProfilePillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ProfilePillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StarpathColors.surfaceContainerHigh.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: StarpathColors.outlineVariant.withValues(alpha: 0.7),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: StarpathColors.accentViolet,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SpotlightChip({required this.icon, required this.label});

  /// 仅作用在图标 glyph 上（ShaderMask），不铺满圆环内部。
  static const List<Color> _iconGradientColors = [
    Color(0xFFFF7A3D),
    Color(0xFFFF9F66),
    Color(0xFFFF6B9D),
    Color(0xFFE879F9),
    Color(0xFFC084FC),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: StarpathColors.accentViolet.withValues(alpha: 0.55),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _iconGradientColors,
            ).createShader(bounds),
            child: Icon(
              icon,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: StarpathColors.onSurface.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _ContentTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ContentTabBar({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <(IconData, String)>[
      (Icons.grid_on_rounded, '作品'),
      (Icons.play_circle_outline_rounded, '短片'),
      (Icons.person_pin_outlined, '标记'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = selectedIndex == i;
          final icon = tabs[i].$1;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: selected
                          ? StarpathColors.onSurface
                          : StarpathColors.onSurfaceVariant
                              .withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      height: 3,
                      width: selected ? 36 : 0,
                      decoration: BoxDecoration(
                        color: StarpathColors.accentViolet,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 九宫格：假图（Picsum seed）+ 加载/失败时回退渐变。
class _ProfileGridTile extends StatelessWidget {
  final ProfileMockGridCell cell;

  const _ProfileGridTile({required this.cell});

  static final List<List<Color>> _fallbackHues = [
    const [Color(0xFF1E1B4B), Color(0xFF4D2E8B), Color(0xFFE879F9)],
    const [Color(0xFF0F172A), Color(0xFF6366F1), Color(0xFFF472B6)],
    const [Color(0xFF312E81), Color(0xFF7C3AED), Color(0xFF22D3EE)],
    const [Color(0xFF1A1035), Color(0xFF9B72FF), Color(0xFFFF6B9D)],
  ];

  List<Color> get _fallbackColors =>
      _fallbackHues[cell.title.hashCode.abs() % _fallbackHues.length];

  @override
  Widget build(BuildContext context) {
    final g = _fallbackColors;

    Widget gradientShell({required Widget child}) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g,
            ),
          ),
          child: child,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(cell.title),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: CachedNetworkImage(
          imageUrl: cell.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          fadeInDuration: const Duration(milliseconds: 220),
          placeholder: (c, u) => gradientShell(
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
          errorWidget: (c, u, e) => gradientShell(
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
