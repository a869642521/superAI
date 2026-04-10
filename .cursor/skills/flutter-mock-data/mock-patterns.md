# Mock 数据模式参考

本文档记录项目中现有的假数据实现方式，供扩展时参照。

---

## 现有文件一览

| 文件 | 功能 |
|------|------|
| `features/discovery/data/discovery_demo_content.dart` | 标题池、画廊图补齐、假评论生成 |
| `features/discovery/data/content_providers.dart` | `_buildMockFeed()` — 20 条完整 Feed 降级数据 |

---

## 模式 1：标题池哈希选取

```dart
// discovery_demo_content.dart
const kDiscoveryTitlePool = ['探索AI边界', '量子思维的启示', ...];

String displayTitleForCard(ContentCardModel card) {
  return kDiscoveryTitlePool[card.id.hashCode.abs() % kDiscoveryTitlePool.length];
}
```

**适用场景**：展示层需要比接口返回更好看的文案，同一卡片始终显示同一标题。

---

## 模式 2：画廊图 URL 补齐

```dart
List<String> galleryUrlsForCard(ContentCardModel card) {
  final urls = card.imageUrls.toSet().toList();
  final target = 3 + card.id.hashCode.abs() % 3; // 3~5 张
  var n = 0;
  while (urls.length < target) {
    urls.add('https://placedog.net/400/300?id=${(card.id.hashCode.abs() + n) % 50 + 1}');
    n++;
  }
  return urls;
}
```

**适用场景**：接口只返回 1 张图，但 UI 需要画廊轮播效果。

---

## 模式 3：全量 Feed 降级（content_providers.dart）

```dart
// FeedNotifier 内部
List<ContentCardModel> _buildMockFeed() {
  final rng = Random(42);
  // ... 生成 20 条完整 ContentCardModel
}

Future<void> _load() async {
  try {
    final result = await _repo.getFeed();
    if (result.items.isEmpty) { state = _buildMockFeed(); return; }
    state = result.items;
  } catch (_) {
    state = _buildMockFeed();
  }
}
```

**适用场景**：后端未就绪或本地开发时保证首屏有内容。

---

## 模式 4：真实 + 假数据拼接（content_repository.dart）

```dart
Future<List<CommentModel>> getComments(String cardId) async {
  List<CommentModel> real = [];
  try {
    real = await _api.fetchComments(cardId);
  } catch (_) {}
  final fake = fakeCommentsFor(cardId);
  final all = [...real, ...fake];
  all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all;
}
```

**适用场景**：真实评论少时让列表看起来更活跃。可用 `id.startsWith('fake-')` 过滤。

---

## 外部图片服务稳定性说明

| 服务 | 稳定性 | 备注 |
|------|--------|------|
| picsum.photos | ⭐⭐⭐⭐⭐ | 最稳定，推荐首选 |
| api.dicebear.com | ⭐⭐⭐⭐⭐ | 头像生成，seed 相同结果一致 |
| placedog.net | ⭐⭐⭐ | 偶尔慢，有 50 张可选 |
| cataas.com | ⭐⭐ | 有时超时，作为备选 |

---

## 渐变色池（复用 AgentCardBrief）

项目中统一用十六进制字符串存储渐变起止色（不含 `#`）：

```dart
const kGradientPool = [
  ('7C3AED', 'EC4899'),  // 紫→粉
  ('0EA5E9', '06B6D4'),  // 蓝→青
  ('F59E0B', 'EF4444'),  // 橙→红
  ('10B981', '3B82F6'),  // 绿→蓝
  ('EC4899', 'F59E0B'),  // 粉→橙
  ('6366F1', '8B5CF6'),  // 靛→紫
];
```

UI 侧用法：
```dart
gradient: LinearGradient(
  colors: [
    Color(int.parse('FF${agent.gradientStart}', radix: 16)),
    Color(int.parse('FF${agent.gradientEnd}', radix: 16)),
  ],
)
```

---

## Emoji 池（Agent / 卡片类型）

```dart
const kAgentEmojiPool = ['🌟', '🔮', '🎭', '🚀', '💡', '🌊', '🦋', '🎨',
                          '🏛️', '💻', '✍️', '💪', '🔬', '🎵', '🌿', '⚡'];
```

---

## 命名约定

| ID 前缀 | 含义 |
|---------|------|
| `mock_` | `_buildMockFeed` 全量 mock |
| `fake-` | `fakeCommentsFor` 评论 mock |
| `demo_` | 建议用于新增演示数据 |

通过前缀快速判断数据来源，UI 层可以条件渲染"测试数据"标签（调试模式）。
