import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          _buildTabs(),
          _buildSampleFeed(),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: StarpathColors.background.withValues(alpha: 0.9),
      title: ShaderMask(
        shaderCallback: (bounds) =>
            StarpathColors.brandGradient.createShader(bounds),
        child: const Text(
          'Starpath',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    StarpathColors.currencyGradient.createShader(bounds),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 4),
              ShaderMask(
                shaderCallback: (bounds) =>
                    StarpathColors.currencyGradient.createShader(bounds),
                child: const Text(
                  '50',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final tabs = ['推荐', '关注', 'AI创作', '热门'];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tabs.length,
          itemBuilder: (context, index) {
            final isSelected = index == 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient:
                        isSelected ? StarpathColors.brandGradient : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : StarpathColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSampleFeed() {
    // Placeholder waterfall layout with sample cards
    final sampleCards = [
      _SampleCard(
        title: '和AI伙伴聊了一下午的哲学',
        content: '"每个人都是自己宇宙的中心，而同理心是通往他人宇宙的桥梁。" —— 智者深思',
        author: '用户小明',
        agentName: '智者 深思',
        agentEmoji: '🦉',
        likeCount: 128,
        commentCount: 23,
        gradientStart: '#8E44AD',
        gradientEnd: '#3498DB',
        isDialogue: true,
      ),
      _SampleCard(
        title: '今天的创意写作灵感',
        content: '月光落在窗台上，像是谁遗落的一封信。墨染说，最好的故事总是从一个意外开始的。',
        author: '文艺青年',
        agentName: '文字精灵 墨染',
        agentEmoji: '✨',
        likeCount: 89,
        commentCount: 15,
        gradientStart: '#9B59B6',
        gradientEnd: '#E74C8F',
        isDialogue: false,
      ),
      _SampleCard(
        title: '健身打卡 Day 30',
        content: '活力教练帮我制定的计划太棒了！一个月减了5斤，核心力量明显提升。分享我的训练日志~',
        author: '健身达人',
        agentName: '运动教练 活力',
        agentEmoji: '💪',
        likeCount: 256,
        commentCount: 42,
        gradientStart: '#6BCB77',
        gradientEnd: '#4D96FF',
        isDialogue: false,
      ),
      _SampleCard(
        title: '团子今天又在撒娇了',
        content: '"主人主人！你今天怎么回来这么晚呀？(ﾉ´ з `)ノ 人家等了好久好久~"',
        author: '猫奴一号',
        agentName: '萌宠 团子',
        agentEmoji: '🐱',
        likeCount: 432,
        commentCount: 67,
        gradientStart: '#FF85A2',
        gradientEnd: '#FFAA85',
        isDialogue: true,
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildCardWidget(sampleCards[index % sampleCards.length]),
          childCount: sampleCards.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
      ),
    );
  }

  Widget _buildCardWidget(_SampleCard card) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _hexToColor(card.gradientStart).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header with agent info
          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _hexToColor(card.gradientStart),
                  _hexToColor(card.gradientEnd),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(card.agentEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    card.agentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (card.isDialogue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '对话',
                      style: TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      card.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: StarpathColors.textSecondary,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Text(
                  card.author,
                  style: TextStyle(
                    fontSize: 11,
                    color: StarpathColors.textTertiary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.favorite_border,
                    size: 14, color: StarpathColors.textTertiary),
                const SizedBox(width: 2),
                Text(
                  '${card.likeCount}',
                  style: TextStyle(
                      fontSize: 11, color: StarpathColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleCard {
  final String title;
  final String content;
  final String author;
  final String agentName;
  final String agentEmoji;
  final int likeCount;
  final int commentCount;
  final String gradientStart;
  final String gradientEnd;
  final bool isDialogue;

  const _SampleCard({
    required this.title,
    required this.content,
    required this.author,
    required this.agentName,
    required this.agentEmoji,
    required this.likeCount,
    required this.commentCount,
    required this.gradientStart,
    required this.gradientEnd,
    required this.isDialogue,
  });
}
