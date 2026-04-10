---
name: flutter-mock-data
description: 为 starpath Flutter 应用生成各类假数据（Mock/Demo Data），包括卡片列表、评论、聊天消息、Agent、用户/好友、钱包交易等。当用户需要添加 mock 数据、填充测试内容、补充演示数据、或需要无后端环境下运行时使用。
---

# Flutter Mock Data — starpath 假数据技能

## 项目约定

- **假数据集中存放位置**：各 feature 的 `data/` 目录下，以 `_demo_content.dart` 或 `_mock_data.dart` 命名。
- **现有文件**：`features/discovery/data/discovery_demo_content.dart`（评论、画廊图、标题池）。
- **降级策略**：Provider 层请求失败/空列表 → 返回 mock 数据；不在 UI 层直接写假数据。
- **图片全部走网络 URL**，通过 `CachedNetworkImage` 加载，不使用本地 assets。
- **随机种子固定**（`Random(42)`）保证每次渲染一致，避免列表跳动。

## 图片 URL 速查

| 用途 | URL 模板 | 说明 |
|------|----------|------|
| 卡片封面/内容图 | `https://picsum.photos/seed/{seed}/400/300` | seed 用 id 或序号 |
| 狗狗图（宠物类） | `https://placedog.net/400/300?id={n}` | n=1~50 |
| 猫咪图 | `https://cataas.com/cat?width=400&height=300&r={seed}` | 随机猫图 |
| 用户/好友头像 | `https://api.dicebear.com/7.x/avataaars/png?seed={name}` | 卡通风格 |
| 真实感头像 | `https://api.dicebear.com/7.x/personas/png?seed={name}` | 写实风格 |
| 方形 Agent 封面 | `https://picsum.photos/seed/agent_{id}/200/200` | 正方形 |

## 各模块 Mock 数据生成

### 1. 卡片 Feed（ContentCardModel）

```dart
// 放在 features/discovery/data/discovery_demo_content.dart

List<ContentCardModel> buildMockFeed({int count = 20}) {
  final rng = Random(42);
  const gradients = [
    ('7C3AED', 'EC4899'), ('0EA5E9', '06B6D4'),
    ('F59E0B', 'EF4444'), ('10B981', '3B82F6'),
  ];
  const emojis = ['🌟', '🔮', '🎭', '🚀', '💡', '🌊', '🦋', '🎨'];
  const nicknames = ['星辰', '幻影', '晨曦', '暗影', 'Nova', 'Echo', 'Aria'];

  return List.generate(count, (i) {
    final g = gradients[i % gradients.length];
    return ContentCardModel(
      id: 'mock_$i',
      userId: 'user_$i',
      agentId: 'agent_$i',
      type: CardType.textImage,
      title: kDiscoveryTitlePool[i % kDiscoveryTitlePool.length],
      content: '这是第 $i 条测试内容，用于演示卡片样式。',
      imageUrls: ['https://picsum.photos/seed/card_$i/400/300'],
      likeCount: rng.nextInt(500),
      commentCount: rng.nextInt(50),
      createdAt: DateTime.now().subtract(Duration(hours: i * 3)),
      user: UserBrief(
        id: 'user_$i',
        nickname: nicknames[i % nicknames.length],
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=user_$i',
      ),
      agent: AgentCardBrief(
        id: 'agent_$i',
        name: 'Agent ${emojis[i % emojis.length]}',
        emoji: emojis[i % emojis.length],
        gradientStart: g.$1,
        gradientEnd: g.$2,
      ),
      isLiked: rng.nextBool(),
    );
  });
}
```

### 2. 评论（CommentModel）

```dart
// 现有函数在 discovery_demo_content.dart，扩展示例：

List<CommentModel> fakeCommentsFor(String cardId, {int count = 6}) {
  const names = ['小明', '阿强', '晓雪', '老王', 'Luna', 'Max', 'Zara'];
  const texts = [
    '这个太厉害了！', '学到了很多，感谢分享', '有点意思，继续关注',
    '支持一下🔥', '这就是我想要的！', '已收藏，慢慢研究',
    '感觉可以做得更好？', '大佬出品必属精品',
  ];
  return List.generate(count, (i) => CommentModel(
    id: 'fake-$cardId-$i',
    content: texts[(cardId.hashCode + i) % texts.length],
    createdAt: DateTime.now().subtract(Duration(minutes: 10 + i * 17)),
    user: UserBrief(
      id: 'fake_user_$i',
      nickname: names[(cardId.hashCode + i) % names.length],
      avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=${names[(cardId.hashCode + i) % names.length]}',
    ),
  ));
}
```

### 3. 聊天会话（ConversationModel）

```dart
// 放在 features/chat/data/chat_mock_data.dart

List<ConversationModel> buildMockConversations({int count = 8}) {
  const gradients = [
    ('7C3AED', 'EC4899'), ('0EA5E9', '06B6D4'), ('F59E0B', 'EF4444'),
  ];
  const agentNames = ['哲学家苏格拉底', '代码助手 Pro', '写作灵感缪斯', '健身教练 Max'];
  const emojis = ['🏛️', '💻', '✍️', '💪', '🎨', '🔬', '🎵', '🌿'];
  const lastMessages = [
    '好的，我们继续上次的话题', '代码已经帮你优化好了',
    '这个故事开头不错！', '今天的训练计划已发送',
  ];

  return List.generate(count, (i) {
    final g = gradients[i % gradients.length];
    return ConversationModel(
      id: 'mock_conv_$i',
      userId: 'current_user',
      agentId: 'agent_$i',
      title: agentNames[i % agentNames.length],
      lastMessageAt: DateTime.now().subtract(Duration(hours: i * 5)),
      agent: AgentBrief(
        id: 'agent_$i',
        name: agentNames[i % agentNames.length],
        emoji: emojis[i % emojis.length],
        gradientStart: g.$1,
        gradientEnd: g.$2,
      ),
      lastMessage: MessageModel(
        role: 'assistant',
        content: lastMessages[i % lastMessages.length],
        createdAt: DateTime.now().subtract(Duration(hours: i * 5)),
      ),
    );
  });
}
```

### 4. 聊天消息（MessageModel）

```dart
List<MessageModel> buildMockMessages(String conversationId) {
  final pairs = [
    ('你好！有什么我能帮你的？', '你能介绍一下你自己吗？'),
    ('我是你的 AI 助手，专注于帮你探索知识边界。', '太棒了，那我们聊聊哲学吧'),
    ('当然！苏格拉底说：认识你自己。你觉得这句话意味着什么？', '意思是要了解自己的内心和局限？'),
  ];
  final messages = <MessageModel>[];
  for (var i = 0; i < pairs.length; i++) {
    messages.add(MessageModel(
      id: 'msg_${conversationId}_${i * 2}',
      role: 'assistant',
      content: pairs[i].$1,
      createdAt: DateTime.now().subtract(Duration(minutes: (pairs.length - i) * 10 + 5)),
    ));
    messages.add(MessageModel(
      id: 'msg_${conversationId}_${i * 2 + 1}',
      role: 'user',
      content: pairs[i].$2,
      createdAt: DateTime.now().subtract(Duration(minutes: (pairs.length - i) * 10)),
    ));
  }
  return messages;
}
```

### 5. Agent（AgentModel）

```dart
// 放在 features/agent_studio/data/agent_mock_data.dart

List<AgentModel> buildMockAgents({int count = 6}) {
  const data = [
    ('哲学探索者', '🏛️', '7C3AED', 'EC4899', '擅长苏格拉底式追问，帮你深度思考人生问题'),
    ('代码伙伴', '💻', '0EA5E9', '06B6D4', '精通 Flutter/Dart/TypeScript，代码审查与优化'),
    ('故事编织者', '✍️', 'F59E0B', 'EF4444', '协助创作故事、剧本和创意写作'),
    ('健身顾问', '💪', '10B981', '3B82F6', '制定个性化训练计划和营养建议'),
    ('艺术灵感', '🎨', 'EC4899', 'F59E0B', '激发创意，协助视觉艺术构思'),
    ('科学向导', '🔬', '3B82F6', '10B981', '解释复杂科学概念，探索前沿研究'),
  ];

  return List.generate(count.clamp(0, data.length), (i) => AgentModel(
    id: 'mock_agent_$i',
    userId: 'current_user',
    name: data[i].$1,
    emoji: data[i].$2,
    gradientStart: data[i].$3,
    gradientEnd: data[i].$4,
    personality: ['友善', '专业', '耐心'],
    bio: data[i].$5,
    isPublic: true,
    createdAt: DateTime.now().subtract(Duration(days: i * 7)),
  ));
}
```

### 6. 用户/好友（UserBrief）

```dart
const kMockUsers = [
  UserBrief(id: 'u1', nickname: '星辰旅者', avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=xingchen'),
  UserBrief(id: 'u2', nickname: 'Nova探索者', avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=nova'),
  UserBrief(id: 'u3', nickname: '暗影骑士', avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=anying'),
  UserBrief(id: 'u4', nickname: '晨曦编织者', avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=chenxi'),
];
```

### 7. 钱包/积分（CurrencyAccount + Transaction）

```dart
// 放在 features/profile/data/currency_mock_data.dart

CurrencyAccount buildMockCurrencyAccount() => CurrencyAccount(
  id: 'mock_account',
  balance: 1280,
  totalEarned: 3500,
  totalSpent: 2220,
  lastCheckIn: DateTime.now().subtract(const Duration(hours: 20)),
);

List<CurrencyTransaction> buildMockTransactions() {
  const records = [
    (50, 'EARN', '每日签到奖励'),
    (-30, 'SPEND', '与 Agent 对话消耗'),
    (200, 'EARN', '内容获得点赞奖励'),
    (-100, 'SPEND', '解锁高级 Agent'),
    (100, 'EARN', '邀请好友奖励'),
    (-20, 'SPEND', '生成图片消耗'),
  ];
  return List.generate(records.length, (i) => CurrencyTransaction(
    id: 'tx_$i',
    amount: records[i].$1.abs(),
    type: records[i].$2,
    reason: records[i].$3,
    createdAt: DateTime.now().subtract(Duration(days: i)),
  ));
}
```

## 降级策略模板

在 Provider 中使用 mock 数据的标准写法：

```dart
Future<void> _loadData() async {
  try {
    final result = await _repository.fetchData();
    if (result.isEmpty) {
      state = buildMockXxx();  // 空列表降级
      return;
    }
    state = result;
  } catch (e) {
    state = buildMockXxx();    // 异常降级，不向用户抛错
  }
}
```

## 新增 Mock 数据检查清单

- [ ] 函数/常量放在对应 feature 的 `data/xxx_mock_data.dart` 或 `xxx_demo_content.dart`
- [ ] 使用固定随机种子 `Random(42)` 保证一致性
- [ ] 图片 URL 采用上方速查表中的服务
- [ ] ID 前缀标记来源，如 `mock_`、`fake-`，便于区分真实数据
- [ ] 时间字段使用 `DateTime.now().subtract(...)` 保持相对时间
- [ ] Provider 层做降级，UI 层不直接引用 mock 函数

## 更多参考

- 现有实现详见 [mock-patterns.md](mock-patterns.md)
- 完整代码示例见 [examples.md](examples.md)
