import 'dart:math';

import 'package:starpath/features/discovery/domain/card_model.dart';

/// 与后端无关的瀑布流占位数据（id 形如 `mock_0`），供空 feed / 接口失败时使用。

List<ContentCardModel> discoveryMockFeedItems() {
  final rng = Random(42);

  const titles = [
    'AI 绘制的星空旅行日记',
    '用 GPT 写了一首诗，它哭了',
    '深夜咖啡馆的赛博朋克氛围',
    '我让 AI 设计了我的房间',
    '数字艺术：光与影的碰撞',
    '用 AI 还原古代壁画的色彩',
    '城市霓虹 · 未来感街拍',
    '一个人的极简生活美学',
    '海边黄昏，治愈系风景',
    '星际旅人的最后一封信',
    'AI 助手帮我规划了环球旅行',
    '赛博朋克风格的城市夜景',
    '春日樱花·慢生活记录',
    '我用 AI 创作了一首 Lo-Fi 曲',
    '未来实验室的一天',
    '极光下的孤独与宁静',
    '量子纠缠：视觉艺术新探索',
    '山间云海·治愈心灵之旅',
    '用 AI 复刻莫奈的睡莲',
    '霓虹城市 · 像素艺术集',
  ];

  const users = [
    ('u001', '星际旅人', null),
    ('u002', '代码诗人', null),
    ('u003', '夜猫设计师', null),
    ('u004', '像素画家', null),
    ('u005', '晨光摄影师', null),
    ('u006', 'AI 探索者', null),
    ('u007', '极光追逐者', null),
    ('u008', '数字游民', null),
  ];

  const gradients = [
    ('#6C63FF', '#00D2FF'),
    ('#FF6B6B', '#FFE66D'),
    ('#A18CD1', '#FBC2EB'),
    ('#43E97B', '#38F9D7'),
    ('#FA709A', '#FEE140'),
    ('#30CFD0', '#330867'),
    ('#667EEA', '#764BA2'),
    ('#F093FB', '#F5576C'),
  ];

  const emojis = ['✨', '🎨', '🌌', '🤖', '🎵', '🌸', '🔮', '💫'];

  return List.generate(20, (i) {
    final u = users[i % users.length];
    final g = gradients[i % gradients.length];
    final seed = 100 + i * 7 + rng.nextInt(5);

    return ContentCardModel(
      id: 'mock_$i',
      userId: u.$1,
      agentId: 'agent_${i % 5}',
      type: CardType.textImage,
      title: titles[i],
      content: titles[i],
      imageUrls: ['https://picsum.photos/seed/$seed/400/300'],
      likeCount: 100 + rng.nextInt(9900),
      commentCount: 5 + rng.nextInt(200),
      createdAt: DateTime.now().subtract(Duration(hours: i * 3)),
      user: UserBrief(id: u.$1, nickname: u.$2, avatarUrl: u.$3),
      agent: AgentCardBrief(
        id: 'agent_${i % 5}',
        name: 'AI 助手 ${i % 5 + 1}',
        emoji: emojis[i % emojis.length],
        gradientStart: g.$1,
        gradientEnd: g.$2,
      ),
      isLiked: i % 4 == 0,
    );
  });
}

/// 根据 `mock_12` 等形式解析并返回对应卡片；解析失败返回 null。
ContentCardModel? mockCardById(String id) {
  final m = RegExp(r'^mock_(\d+)$').firstMatch(id);
  if (m == null) return null;
  final index = int.tryParse(m.group(1)!);
  if (index == null) return null;
  final items = discoveryMockFeedItems();
  if (index < 0 || index >= items.length) return null;
  return items[index];
}

bool isMockCardId(String id) => id.startsWith('mock_');
