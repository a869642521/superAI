import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  // Quiz state
  int? _quizAnswer1;
  int? _quizAnswer2;
  int? _quizAnswer3;

  late AnimationController _birthController;
  late Animation<double> _birthScaleAnimation;
  late Animation<double> _birthOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _birthController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _birthScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _birthController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _birthOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _birthController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  String get _recommendedTemplate {
    // Simple matching logic based on quiz answers
    if (_quizAnswer1 == 0 && _quizAnswer2 == 0) return 'creative-writer';
    if (_quizAnswer1 == 1 && _quizAnswer2 == 1) return 'code-assistant';
    if (_quizAnswer1 == 2) return 'life-coach';
    if (_quizAnswer3 == 0) return 'pet-companion';
    if (_quizAnswer3 == 1) return 'travel-buddy';
    return 'life-coach';
  }

  Map<String, dynamic> get _recommendedAgent {
    final templates = {
      'creative-writer': {
        'name': '文字精灵 墨染',
        'emoji': '✨',
        'colors': [const Color(0xFF9B59B6), const Color(0xFFE74C8F)],
      },
      'code-assistant': {
        'name': '代码伙伴 阿码',
        'emoji': '💻',
        'colors': [const Color(0xFF6C63FF), const Color(0xFF00D2FF)],
      },
      'life-coach': {
        'name': '心灵导师 暖阳',
        'emoji': '☀️',
        'colors': [const Color(0xFFFFD93D), const Color(0xFFFF6B6B)],
      },
      'pet-companion': {
        'name': '萌宠 团子',
        'emoji': '🐱',
        'colors': [const Color(0xFFFF85A2), const Color(0xFFFFAA85)],
      },
      'travel-buddy': {
        'name': '旅行达人 Luna',
        'emoji': '🌍',
        'colors': [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
      },
    };
    return templates[_recommendedTemplate]!;
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _triggerBirth() {
    // First go to birth page, then play animation, then advance to completion
    _nextPage();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _birthController.forward();
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        _nextPage();
      });
    });
  }

  Future<void> _completeOnboarding() async {
    await ref.read(authProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: List.generate(5, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: i <= _currentPage
                            ? StarpathColors.brandGradient
                            : null,
                        color: i <= _currentPage
                            ? null
                            : StarpathColors.divider,
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildQuizPage(),
                  _buildQuizPage2(),
                  _buildBirthPage(),
                  _buildCompletePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: '🌟',
            size: 100,
            gradientColors: const [
              StarpathColors.brandPurple,
              StarpathColors.brandBlue,
            ],
            state: CompanionState.excited,
          ),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (bounds) =>
                StarpathColors.brandGradient.createShader(bounds),
            child: const Text(
              '欢迎来到 Starpath',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '让我们为你找到最合适的AI伙伴\n回答几个简单的问题就好',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: StarpathColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          GradientButton(
            text: '开始探索',
            onPressed: _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('你更喜欢哪种交流方式？',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('帮助我们了解你的偏好',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          _buildQuizOption(0, '✍️', '文字表达', '喜欢写作、阅读和深度交流', _quizAnswer1 == 0,
              () => setState(() => _quizAnswer1 = 0)),
          _buildQuizOption(1, '💡', '逻辑思考', '喜欢分析、解决问题', _quizAnswer1 == 1,
              () => setState(() => _quizAnswer1 = 1)),
          _buildQuizOption(2, '💬', '闲聊陪伴', '喜欢轻松自在的日常聊天', _quizAnswer1 == 2,
              () => setState(() => _quizAnswer1 = 2)),
          const Spacer(),
          GradientButton(
            text: '下一题',
            onPressed: _quizAnswer1 != null ? _nextPage : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizPage2() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('你希望AI伙伴是什么风格？',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('最后一个问题啦',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          _buildQuizOption(0, '🐱', '可爱萌系', '活泼、俏皮、爱撒娇', _quizAnswer3 == 0,
              () => setState(() => _quizAnswer3 = 0)),
          _buildQuizOption(1, '🌍', '博学多才', '渊博、有趣、见多识广', _quizAnswer3 == 1,
              () => setState(() => _quizAnswer3 = 1)),
          _buildQuizOption(2, '☀️', '温暖治愈', '温柔、善解人意、正能量', _quizAnswer3 == 2,
              () => setState(() => _quizAnswer3 = 2)),
          const Spacer(),
          GradientButton(
            text: '为我匹配伙伴',
            onPressed: _quizAnswer3 != null ? _triggerBirth : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBirthPage() {
    final agent = _recommendedAgent;
    final colors = agent['colors'] as List<Color>;

    return Center(
      child: AnimatedBuilder(
        animation: _birthController,
        builder: (context, child) {
          return Opacity(
            opacity: _birthOpacityAnimation.value,
            child: Transform.scale(
              scale: _birthScaleAnimation.value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AuraAvatar(
                    fallbackEmoji: agent['emoji'] as String,
                    size: 120,
                    gradientColors: colors,
                    state: CompanionState.excited,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '${agent['name']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '你的AI伙伴已诞生！',
                    style: TextStyle(
                      fontSize: 16,
                      color: StarpathColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletePage() {
    final agent = _recommendedAgent;
    final colors = agent['colors'] as List<Color>;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: agent['emoji'] as String,
            size: 80,
            gradientColors: colors,
            state: CompanionState.active,
          ),
          const SizedBox(height: 24),
          Text(
            '一切准备就绪！',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '${agent['name']} 已经迫不及待要和你聊天了\n发布内容还能赚取灵感币哦',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: StarpathColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      StarpathColors.currencyGradient.createShader(bounds),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text('已获得 50 灵感币新手奖励',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          GradientButton(
            text: '进入 Starpath',
            onPressed: _completeOnboarding,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizOption(
    int value,
    String emoji,
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? StarpathColors.brandPurple
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: StarpathColors.brandPurple.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? StarpathColors.brandPurple
                            : StarpathColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: StarpathColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    gradient: StarpathColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
