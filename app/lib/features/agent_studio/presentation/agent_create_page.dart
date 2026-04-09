import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

class _TemplateData {
  final String id;
  final String name;
  final String emoji;
  final List<String> personality;
  final String bio;
  final String category;
  final Color gradientStart;
  final Color gradientEnd;

  const _TemplateData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.personality,
    required this.bio,
    required this.category,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

const _templates = [
  _TemplateData(id: 'travel-buddy', name: '旅行达人 Luna', emoji: '🌍', personality: ['热情', '博学', '幽默'], bio: '环游世界的旅行顾问', category: '生活', gradientStart: Color(0xFF00B4D8), gradientEnd: Color(0xFF0077B6)),
  _TemplateData(id: 'code-assistant', name: '代码伙伴 阿码', emoji: '💻', personality: ['理性', '耐心', '严谨'], bio: '全栈编程助手', category: '工作', gradientStart: Color(0xFF6C63FF), gradientEnd: Color(0xFF00D2FF)),
  _TemplateData(id: 'creative-writer', name: '文字精灵 墨染', emoji: '✨', personality: ['感性', '浪漫', '细腻'], bio: '创意写作伙伴', category: '创作', gradientStart: Color(0xFF9B59B6), gradientEnd: Color(0xFFE74C8F)),
  _TemplateData(id: 'life-coach', name: '心灵导师 暖阳', emoji: '☀️', personality: ['温柔', '善解人意', '正能量'], bio: '温暖的倾听者', category: '生活', gradientStart: Color(0xFFFFD93D), gradientEnd: Color(0xFFFF6B6B)),
  _TemplateData(id: 'fitness-coach', name: '运动教练 活力', emoji: '💪', personality: ['活力', '鼓励', '专业'], bio: '私人健身教练', category: '健康', gradientStart: Color(0xFF6BCB77), gradientEnd: Color(0xFF4D96FF)),
  _TemplateData(id: 'study-partner', name: '学习搭子 知识', emoji: '📚', personality: ['博学', '耐心', '幽默'], bio: '学习路上的好伙伴', category: '学习', gradientStart: Color(0xFF48C9B0), gradientEnd: Color(0xFF1ABC9C)),
  _TemplateData(id: 'pet-companion', name: '萌宠 团子', emoji: '🐱', personality: ['可爱', '调皮', '粘人'], bio: '爱撒娇的虚拟宠物', category: '陪伴', gradientStart: Color(0xFFFF85A2), gradientEnd: Color(0xFFFFAA85)),
  _TemplateData(id: 'philosopher', name: '智者 深思', emoji: '🦉', personality: ['深邃', '睿智', '冷静'], bio: '陪你思考人生', category: '思考', gradientStart: Color(0xFF8E44AD), gradientEnd: Color(0xFF3498DB)),
  _TemplateData(id: 'music-friend', name: '音乐灵魂 律动', emoji: '🎵', personality: ['文艺', '感性', '热情'], bio: '懂音乐也懂你的知音', category: '创作', gradientStart: Color(0xFFE91E63), gradientEnd: Color(0xFF9C27B0)),
  _TemplateData(id: 'foodie', name: '美食家 食味', emoji: '🍜', personality: ['热情', '幽默', '讲究'], bio: '带你品味世界美食', category: '生活', gradientStart: Color(0xFFF39C12), gradientEnd: Color(0xFFE74C3C)),
  _TemplateData(id: 'game-buddy', name: '游戏搭子 像素', emoji: '🎮', personality: ['热血', '幽默', '竞技'], bio: '一起开黑的游戏好基友', category: '娱乐', gradientStart: Color(0xFF00BCD4), gradientEnd: Color(0xFF4CAF50)),
  _TemplateData(id: 'daily-butler', name: '生活管家 小秘', emoji: '📋', personality: ['细心', '高效', '贴心'], bio: '事无巨细的生活管家', category: '效率', gradientStart: Color(0xFFFF6B6B), gradientEnd: Color(0xFFFF8E53)),
];

const _allPersonalityTags = [
  '幽默', '理性', '温柔', '毒舌', '热情', '冷静',
  '感性', '博学', '可爱', '严谨', '活力', '浪漫',
  '深邃', '鼓励', '耐心', '调皮', '睿智', '正能量',
];

class AgentCreatePage extends ConsumerStatefulWidget {
  const AgentCreatePage({super.key});

  @override
  ConsumerState<AgentCreatePage> createState() => _AgentCreatePageState();
}

class _AgentCreatePageState extends ConsumerState<AgentCreatePage> {
  int _currentStep = 0;
  _TemplateData? _selectedTemplate;
  final _nameController = TextEditingController();
  final Set<String> _selectedPersonality = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectTemplate(_TemplateData template) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTemplate = template;
      _nameController.text = template.name;
      _selectedPersonality.clear();
      _selectedPersonality.addAll(template.personality);
    });
  }

  void _togglePersonality(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPersonality.contains(tag)) {
        _selectedPersonality.remove(tag);
      } else if (_selectedPersonality.length < 5) {
        _selectedPersonality.add(tag);
      }
    });
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _createAgent();
    }
  }

  Future<void> _createAgent() async {
    if (_selectedTemplate == null) return;
    setState(() => _isCreating = true);

    try {
      final t = _selectedTemplate!;
      final repo = ref.read(agentRepositoryProvider);
      await repo.createAgent(
        name: _nameController.text,
        emoji: t.emoji,
        personality: _selectedPersonality.toList(),
        bio: t.bio,
        templateId: t.id,
        gradientStart:
            '#${t.gradientStart.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        gradientEnd:
            '#${t.gradientEnd.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text} 已诞生！'),
            backgroundColor: StarpathColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('创建失败，请确认后端服务正在运行'),
            backgroundColor: StarpathColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      appBar: AppBar(
        title: Text(['选择模板', '设定性格', '确认创建'][_currentStep]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: [
          _buildTemplateStep(),
          _buildPersonalityStep(),
          _buildConfirmStep(),
        ][_currentStep],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GradientButton(
            text: _currentStep < 2 ? '下一步' : '创建伙伴',
            onPressed: _canProceed ? _nextStep : null,
            isLoading: _isCreating,
          ),
        ),
      ),
    );
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedTemplate != null;
      case 1:
        return _selectedPersonality.isNotEmpty &&
            _nameController.text.isNotEmpty;
      case 2:
        return !_isCreating;
      default:
        return false;
    }
  }

  Widget _buildTemplateStep() {
    return GridView.builder(
      key: const ValueKey('step-0'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final t = _templates[index];
        final isSelected = _selectedTemplate?.id == t.id;

        return GestureDetector(
          onTap: () => _selectTemplate(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? t.gradientStart : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? t.gradientStart.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AuraAvatar(
                  fallbackEmoji: t.emoji,
                  size: 56,
                  gradientColors: [t.gradientStart, t.gradientEnd],
                  state: isSelected
                      ? CompanionState.excited
                      : CompanionState.active,
                ),
                const SizedBox(height: 12),
                Text(
                  t.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  t.bio,
                  style: TextStyle(
                      fontSize: 12, color: StarpathColors.textTertiary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.gradientStart.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.category,
                    style: TextStyle(
                      fontSize: 11,
                      color: t.gradientStart,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonalityStep() {
    return SingleChildScrollView(
      key: const ValueKey('step-1'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('给伙伴起个名字',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '输入伙伴名称',
              prefixIcon: _selectedTemplate != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_selectedTemplate!.emoji,
                          style: const TextStyle(fontSize: 20)),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
          Text('选择性格标签（最多5个）',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('已选 ${_selectedPersonality.length}/5',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allPersonalityTags.map((tag) {
              final isSelected = _selectedPersonality.contains(tag);
              return GestureDetector(
                onTap: () => _togglePersonality(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient:
                        isSelected ? StarpathColors.brandGradient : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : StarpathColors.divider,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : StarpathColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final t = _selectedTemplate;
    if (t == null) return const SizedBox.shrink();

    return Center(
      key: const ValueKey('step-2'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: t.emoji,
            size: 100,
            gradientColors: [t.gradientStart, t.gradientEnd],
            state: CompanionState.excited,
          ),
          const SizedBox(height: 24),
          Text(_nameController.text,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: _selectedPersonality.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(fontSize: 13)),
                backgroundColor:
                    t.gradientStart.withValues(alpha: 0.1),
                side: BorderSide.none,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(t.bio,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
