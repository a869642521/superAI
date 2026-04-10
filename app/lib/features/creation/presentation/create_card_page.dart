import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';

class CreateCardPage extends ConsumerStatefulWidget {
  const CreateCardPage({super.key});

  @override
  ConsumerState<CreateCardPage> createState() => _CreateCardPageState();
}

class _CreateCardPageState extends ConsumerState<CreateCardPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'TEXT_IMAGE';
  bool _isPublishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标题和内容')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final repo = ref.read(contentRepositoryProvider);
      final card = await repo.createCard(
        type: _selectedType,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );

      // Refresh feed and prepend the new card immediately
      ref.read(feedProvider.notifier).prependCard(card);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      StarpathColors.currencyGradient.createShader(bounds),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text('发布成功！获得 10 灵感币'),
              ],
            ),
            backgroundColor: StarpathColors.success,
          ),
        );
        _titleController.clear();
        _contentController.clear();
        // Navigate back to home feed
        context.go('/discovery');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发布失败：$e'),
            backgroundColor: StarpathColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      appBar: AppBar(title: const Text('创作')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card type selector
            Text('内容类型', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTypeChip('TEXT_IMAGE', '图文', Icons.photo_library),
                const SizedBox(width: 10),
                _buildTypeChip('DIALOGUE', '对话精华', Icons.chat),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            Text('标题', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: '给内容起个标题'),
              maxLength: 50,
            ),
            const SizedBox(height: 16),

            // Content
            Text('内容', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: '分享你和AI伙伴的精彩时刻...',
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              maxLength: 1000,
            ),
            const SizedBox(height: 16),

            // Image upload placeholder
            GestureDetector(
              onTap: () {
                // TODO: implement image picker
              },
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: StarpathColors.divider,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 36, color: StarpathColors.textTertiary),
                      const SizedBox(height: 8),
                      Text(
                        '添加图片（可选）',
                        style: TextStyle(
                          color: StarpathColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Currency reward hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD93D).withValues(alpha: 0.15),
                    const Color(0xFFFF8C00).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        StarpathColors.currencyGradient.createShader(bounds),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '发布内容可获得 10 灵感币',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            GradientButton(
              text: '发布',
              onPressed: _publish,
              isLoading: _isPublishing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? StarpathColors.brandGradient : null,
          color: isSelected ? null : StarpathColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : StarpathColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : StarpathColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? Colors.white : StarpathColors.onSurface,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
