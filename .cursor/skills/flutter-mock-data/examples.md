# Mock 数据使用示例

---

## 示例 1：为聊天列表页添加 mock 数据

**场景**：`chat_list_page.dart` 在后端未就绪时显示空白。

**步骤 1**：新建 `features/chat/data/chat_mock_data.dart`

```dart
import '../domain/chat_model.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

const _gradients = [
  ('7C3AED', 'EC4899'), ('0EA5E9', '06B6D4'), ('F59E0B', 'EF4444'),
  ('10B981', '3B82F6'), ('EC4899', 'F59E0B'), ('6366F1', '8B5CF6'),
];

const _agents = [
  ('哲学探索者', '🏛️', '好的，我们继续上次的话题'),
  ('代码伙伴', '💻', '代码已经帮你优化好了，请查看'),
  ('故事编织者', '✍️', '这个故事开头不错！继续写吧'),
  ('健身顾问', '💪', '今天的训练计划：3组深蹲+跑步30分钟'),
  ('艺术灵感', '🎨', '试试用冷暖对比色，会更有张力'),
  ('科学向导', '🔬', '量子纠缠其实并不违反相对论'),
];

List<ConversationModel> buildMockConversations() {
  return List.generate(_agents.length, (i) {
    final g = _gradients[i % _gradients.length];
    final a = _agents[i];
    return ConversationModel(
      id: 'mock_conv_$i',
      userId: 'current_user',
      agentId: 'mock_agent_$i',
      title: a.$1,
      lastMessageAt: DateTime.now().subtract(Duration(hours: i * 4 + 1)),
      agent: AgentBrief(
        id: 'mock_agent_$i',
        name: a.$1,
        emoji: a.$2,
        gradientStart: g.$1,
        gradientEnd: g.$2,
      ),
      lastMessage: MessageModel(
        role: 'assistant',
        content: a.$3,
        createdAt: DateTime.now().subtract(Duration(hours: i * 4 + 1)),
      ),
    );
  });
}
```

**步骤 2**：在 `chat_providers.dart` 的 Notifier 中接入降级：

```dart
Future<void> loadConversations() async {
  state = const AsyncValue.loading();
  try {
    final list = await ref.read(chatRepositoryProvider).getConversations();
    state = AsyncValue.data(list.isEmpty ? buildMockConversations() : list);
  } catch (e, st) {
    // 开发环境降级展示，不抛错
    state = AsyncValue.data(buildMockConversations());
  }
}
```

---

## 示例 2：为个人页好友/粉丝列表补充假数据

**场景**：profile 页面需要展示关注/粉丝列表，接口暂未实现。

```dart
// features/profile/data/profile_mock_data.dart

import '../../discovery/domain/card_model.dart';

const kMockFollowers = [
  UserBrief(id: 'f1', nickname: '星辰漫步者',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=xingchen'),
  UserBrief(id: 'f2', nickname: 'Nova 探索者',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=nova'),
  UserBrief(id: 'f3', nickname: '暗影骑士',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=anying'),
  UserBrief(id: 'f4', nickname: '晨曦编织者',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=chenxi'),
  UserBrief(id: 'f5', nickname: 'Echo 回响',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=echo'),
];
```

---

## 示例 3：为卡片详情页补充多图画廊

**场景**：接口只返回 1 张图，但 UI 需要轮播画廊。

```dart
// 在 card_detail_page.dart 中
final images = galleryUrlsForCard(card); // 来自 discovery_demo_content.dart
// galleryUrlsForCard 会自动补齐到 3~5 张
```

---

## 示例 4：调试模式下标注 Mock 数据来源

```dart
// 仅在 kDebugMode 下显示来源标签
if (kDebugMode && item.id.startsWith('mock_'))
  Positioned(
    top: 4, right: 4,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('MOCK', style: TextStyle(color: Colors.white, fontSize: 10)),
    ),
  ),
```

---

## 示例 5：Agent Studio 模板分类假数据

```dart
// 已有文件：agent_template_categories.dart
// 可扩展模板分类：

const kExtraTemplateCategories = {
  'health_coach': '健康顾问',
  'travel_guide': '旅行向导',
  'finance_advisor': '理财顾问',
};
```

---

## 常见问题

**Q：为什么不直接用 `Random()` 而要用 `Random(42)`？**

固定种子确保每次 hot reload 后数据不变，避免列表因数据重新随机而闪烁。

**Q：图片加载慢怎么办？**

`CachedNetworkImage` 已自带缓存。首次加载后再次打开会走本地缓存，速度很快。
如需占位图，使用 `placeholder: (context, url) => const Shimmer(...)` 即可。

**Q：如何只在开发环境启用 mock？**

```dart
import 'package:flutter/foundation.dart';

final list = kDebugMode
    ? buildMockConversations()
    : await _repo.getConversations();
```

**Q：mock 数据和真实数据混合时如何区分？**

通过 ID 前缀判断：`id.startsWith('mock_')` 或 `id.startsWith('fake-')`。
