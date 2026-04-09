import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/shared/widgets/frosted_card.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: StarpathColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: StarpathColors.brandGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.3),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Text('😊', style: TextStyle(fontSize: 32)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '新用户',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Starpath 探索者',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Currency card
                  GestureDetector(
                    onTap: () => context.push('/wallet'),
                    child: FrostedCard(
                      child: Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                StarpathColors.currencyGradient
                                    .createShader(bounds),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '灵感币',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: StarpathColors.textSecondary,
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    StarpathColors.currencyGradient
                                        .createShader(bounds),
                                child: const Text(
                                  '50',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          _buildCheckInButton(context),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      _buildStatCard('我的内容', '0', Icons.grid_view_outlined),
                      const SizedBox(width: 12),
                      _buildStatCard('AI伙伴', '0', Icons.auto_awesome_outlined),
                      const SizedBox(width: 12),
                      _buildStatCard('获赞', '0', Icons.favorite_outline),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Menu items
                  _buildMenuItem(
                    icon: Icons.auto_awesome,
                    title: '我的AI伙伴',
                    subtitle: '管理你的AI伙伴',
                    onTap: () => context.go('/agents'),
                  ),
                  _buildMenuItem(
                    icon: Icons.grid_view,
                    title: '我的内容',
                    subtitle: '查看已发布的内容',
                    onTap: () {},
                  ),
                  _buildMenuItem(
                    icon: Icons.account_balance_wallet,
                    title: '我的钱包',
                    subtitle: '查看灵感币收支',
                    onTap: () => context.push('/wallet'),
                  ),
                  _buildMenuItem(
                    icon: Icons.settings,
                    title: '设置',
                    subtitle: '账号与隐私设置',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: call check-in API
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('签到成功！+5 灵感币')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: StarpathColors.brandGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '签到',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: FrostedCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: StarpathColors.brandPurple, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: StarpathColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FrostedCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: StarpathColors.brandPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(icon, color: StarpathColors.brandPurple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: StarpathColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: StarpathColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
