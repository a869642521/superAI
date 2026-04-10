import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: Stack(
        children: [
          // Nebula glows
          Positioned(
            top: -60,
            left: -40,
            child: _NebulaOrb(280, StarpathColors.primary, 0.14),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: _NebulaOrb(200, StarpathColors.secondary, 0.10),
          ),

          CustomScrollView(
            slivers: [
              _buildHeader(context),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _CurrencyCard(context: context),
                    const SizedBox(height: 14),
                    _StatsRow(),
                    const SizedBox(height: 24),
                    _SectionLabel('工具'),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      context,
                      icon: Icons.auto_awesome_rounded,
                      title: '我的AI伙伴',
                      subtitle: '管理你的AI伙伴',
                      iconGradient: StarpathColors.primaryGradient,
                      onTap: () => context.go('/create'),
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      context,
                      icon: Icons.grid_view_rounded,
                      title: '我的内容',
                      subtitle: '查看已发布的内容',
                      iconGradient: StarpathColors.brandGradient,
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      context,
                      icon: Icons.account_balance_wallet_rounded,
                      title: '我的钱包',
                      subtitle: '查看灵感币收支',
                      iconGradient: StarpathColors.currencyGradient,
                      onTap: () => context.push('/wallet'),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('账户'),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_rounded,
                      title: '设置',
                      subtitle: '账号与隐私设置',
                      iconGradient: const LinearGradient(
                        colors: [
                          StarpathColors.surfaceContainerHighest,
                          StarpathColors.surfaceBright,
                        ],
                      ),
                      onTap: () {},
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: StarpathColors.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient header background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    StarpathColors.primaryContainer,
                    StarpathColors.surfaceContainer,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Frosted overlay for depth
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar container
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: StarpathColors.primaryGradient,
                          border: Border.all(
                            color: StarpathColors.primary.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: StarpathColors.primary.withValues(alpha: 0.30),
                              blurRadius: 24,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('😊', style: TextStyle(fontSize: 36)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '新用户',
                        style: const TextStyle(
                          color: StarpathColors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Starpath 探索者',
                        style: TextStyle(
                          color:
                              StarpathColors.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient iconGradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainer.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: StarpathColors.outlineVariant, width: 1),
            ),
            child: Row(
              children: [
                // Icon container with gradient
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: iconGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: StarpathColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: StarpathColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: StarpathColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final BuildContext context;
  const _CurrencyCard({required this.context});

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: () => context.push('/wallet'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StarpathColors.tertiary.withValues(alpha: 0.12),
                  StarpathColors.tertiary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: StarpathColors.tertiary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Gold icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: StarpathColors.currencyGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: StarpathColors.tertiary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '灵感币',
                        style: TextStyle(
                          fontSize: 13,
                          color: StarpathColors.tertiary
                              .withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '50',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.64,
                          color: StarpathColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                _CheckInButton(context: context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckInButton extends StatelessWidget {
  final BuildContext context;
  const _CheckInButton({required this.context});

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('签到成功！+5 灵感币'),
            backgroundColor: StarpathColors.surfaceContainerHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: StarpathColors.currencyGradient,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: StarpathColors.tertiary.withValues(alpha: 0.30),
              blurRadius: 16,
              spreadRadius: -3,
            ),
          ],
        ),
        child: const Text(
          '签到',
          style: TextStyle(
            color: StarpathColors.onTertiary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _statTile('我的内容', '0', Icons.grid_view_rounded),
        const SizedBox(width: 10),
        _statTile('AI伙伴', '0', Icons.auto_awesome_rounded),
        const SizedBox(width: 10),
        _statTile('获赞', '0', Icons.favorite_rounded),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainer.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: StarpathColors.outlineVariant, width: 1),
            ),
            child: Column(
              children: [
                Icon(icon, color: StarpathColors.primary, size: 22),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: StarpathColors.onSurface,
                    letterSpacing: -0.44,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: StarpathColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NebulaOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _NebulaOrb(this.size, this.color, this.opacity);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ]),
        ),
      );
}
