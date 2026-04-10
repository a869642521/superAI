import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';

// ─── 用户聊天 Mock 数据 ───────────────────────────────────────────────────────

class _MockUserConversation {
  final String id;
  final String name;
  final String avatar; // emoji
  final String gradStart;
  final String gradEnd;
  final String lastMessage;
  final String timeLabel;
  final bool isUnread;
  final bool isOnline;

  const _MockUserConversation({
    required this.id,
    required this.name,
    required this.avatar,
    required this.gradStart,
    required this.gradEnd,
    required this.lastMessage,
    required this.timeLabel,
    this.isUnread = false,
    this.isOnline = false,
  });
}

const _mockUsers = <_MockUserConversation>[
  _MockUserConversation(
    id: 'u1', name: '林晓雨', avatar: '🌸',
    gradStart: '#FF85A2', gradEnd: '#FFAA85',
    lastMessage: '你昨天分享的那篇文章真的太好了！',
    timeLabel: '2分钟前', isUnread: true, isOnline: true,
  ),
  _MockUserConversation(
    id: 'u2', name: '张明宇', avatar: '🎵',
    gradStart: '#6C63FF', gradEnd: '#00D2FF',
    lastMessage: '好的，明天见！记得带那本书',
    timeLabel: '15分钟前', isUnread: true, isOnline: true,
  ),
  _MockUserConversation(
    id: 'u3', name: '陈思远', avatar: '🌿',
    gradStart: '#6BCB77', gradEnd: '#4D96FF',
    lastMessage: '哈哈哈这个梗也太有趣了',
    timeLabel: '1小时前',
  ),
  _MockUserConversation(
    id: 'u4', name: '王慧欣', avatar: '✨',
    gradStart: '#9B59B6', gradEnd: '#E74C8F',
    lastMessage: '我刚看完这部电影，太感动了',
    timeLabel: '3小时前',
  ),
  _MockUserConversation(
    id: 'u5', name: '刘子航', avatar: '🚀',
    gradStart: '#00B4D8', gradEnd: '#0077B6',
    lastMessage: '发给你了，看看这个方案怎么样',
    timeLabel: '昨天',
  ),
  _MockUserConversation(
    id: 'u6', name: '赵雅婷', avatar: '🌙',
    gradStart: '#FFD93D', gradEnd: '#FF6B6B',
    lastMessage: '今晚的星空好美，你看到了吗？',
    timeLabel: '昨天',
  ),
  _MockUserConversation(
    id: 'u7', name: '周文博', avatar: '📖',
    gradStart: '#48C9B0', gradEnd: '#1ABC9C',
    lastMessage: '这本书推荐给你，绝对值得一读',
    timeLabel: '2天前',
  ),
  _MockUserConversation(
    id: 'u8', name: '吴晓彤', avatar: '🎨',
    gradStart: '#FF6B6B', gradEnd: '#FF8E53',
    lastMessage: '[图片] 我画的你觉得怎么样？',
    timeLabel: '3天前',
  ),
  _MockUserConversation(
    id: 'u9', name: '徐嘉怡', avatar: '☕',
    gradStart: '#8E44AD', gradEnd: '#3498DB',
    lastMessage: '周末要不要一起去那家新开的咖啡店',
    timeLabel: '上周',
  ),
  _MockUserConversation(
    id: 'u10', name: '孙浩然', avatar: '🎮',
    gradStart: '#E91E63', gradEnd: '#9C27B0',
    lastMessage: '今晚组队吗？快来',
    timeLabel: '上周',
  ),
];

// ─── 页面主体 ────────────────────────────────────────────────────────────────

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: top + 16)),
          SliverToBoxAdapter(child: _buildHeader(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildNotificationRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: _buildSectionHeader(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _UserTile(user: _mockUsers[i]),
              ),
              childCount: _mockUsers.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _IconBtn(icon: Icons.search_rounded, onTap: () {}),
          const Spacer(),
          Text(
            '对话',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: StarpathColors.onSurface,
                ),
          ),
          const Spacer(),
          _IconBtn(icon: Icons.edit_outlined, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildNotificationRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _NotificationShortcut(
            icon: Icons.alternate_email_rounded,
            label: '提及',
            count: 3,
          ),
          SizedBox(width: 12),
          _NotificationShortcut(
            icon: Icons.favorite_rounded,
            label: '点赞',
            count: 12,
          ),
          SizedBox(width: 12),
          _NotificationShortcut(
            icon: Icons.person_add_rounded,
            label: '新粉丝',
            count: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Messages',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Mark all as read',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: StarpathColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 图标按钮 ────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: StarpathColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: StarpathColors.onSurfaceVariant, size: 20),
      ),
    );
  }
}

// ─── 通知快捷入口 ─────────────────────────────────────────────────────────────

class _NotificationShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _NotificationShortcut({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: StarpathColors.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: StarpathColors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StarpathColors.primary.withValues(alpha: 0.15),
                  ),
                  child: Icon(icon, color: StarpathColors.primary, size: 22),
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: StarpathColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: StarpathColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: StarpathColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 用户对话卡片 ─────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final _MockUserConversation user;

  const _UserTile({required this.user});

  Color _hex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 用户聊天详情（暂未实现，弹出提示）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('与 ${user.name} 的对话'),
            backgroundColor: StarpathColors.surfaceContainerHigh,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user.isUnread)
                Container(width: 3, color: StarpathColors.primary),
              Expanded(
                child: Container(
                  color: StarpathColors.surfaceContainer,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      _UserAvatar(
                        avatar: user.avatar,
                        gradStart: _hex(user.gradStart),
                        gradEnd: _hex(user.gradEnd),
                        isOnline: user.isOnline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: user.isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: StarpathColors.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  user.timeLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: StarpathColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: user.isUnread
                                    ? StarpathColors.onSurfaceVariant
                                    : StarpathColors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (user.isUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 10),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: StarpathColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String avatar;
  final Color gradStart;
  final Color gradEnd;
  final bool isOnline;

  const _UserAvatar({
    required this.avatar,
    required this.gradStart,
    required this.gradEnd,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [gradStart, gradEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(avatar, style: const TextStyle(fontSize: 24)),
          ),
        ),
        if (isOnline)
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3DD68C),
                border: Border.all(
                  color: StarpathColors.surfaceContainer,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── AI 伙伴聊天启动按钮（供创作模块复用）──────────────────────────────────────

/// Starts a new AI conversation and navigates to the chat detail page.
class StartChatButton extends ConsumerWidget {
  final String agentId;
  final String label;

  const StartChatButton(
      {super.key, required this.agentId, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final repo = ref.read(chatRepositoryProvider);
        final conv = await repo.createConversation(agentId);
        if (context.mounted) {
          ref.invalidate(conversationsProvider);
          context.push('/chat/${conv.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: StarpathColors.primaryGradient,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: StarpathColors.primary.withValues(alpha: 0.30),
              blurRadius: 16,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: StarpathColors.onPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
