import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/core/router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';

/// Web 下调试用：在运行参数中加
/// `--dart-define=FLUTTER_WEB_SEMANTICS_DEBUG=true`
/// 可在画面上叠语义框（仍无法在 Chrome Elements 里拆到每个 widget，需用 DevTools Inspector）。
const bool _kWebSemanticsDebug = bool.fromEnvironment(
  'FLUTTER_WEB_SEMANTICS_DEBUG',
  defaultValue: false,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: StarpathApp()));
}

class StarpathApp extends ConsumerStatefulWidget {
  const StarpathApp({super.key});

  @override
  ConsumerState<StarpathApp> createState() => _StarpathAppState();
}

class _StarpathAppState extends ConsumerState<StarpathApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final router = createRouter(ref);

    final app = MaterialApp.router(
      title: 'Starpath',
      debugShowCheckedModeBanner: false,
      theme: StarpathTheme.darkTheme,
      routerConfig: router,
      showSemanticsDebugger: kDebugMode && kIsWeb && _kWebSemanticsDebug,
      // Web 预览：把整个 app 嵌入手机框内，用 builder 避免二层 MaterialApp 路由冲突
      builder: kIsWeb
          ? (context, child) => _WebPhoneFrame(child: child ?? const SizedBox())
          : null,
    );

    return app;
  }
}

// ── Web phone frame (single-MaterialApp approach) ─────────────────────────────

/// 将整个 app 渲染在仿手机边框里，通过 MaterialApp.builder 注入，
/// 避免嵌套两层 MaterialApp 导致路由冲突。
class _WebPhoneFrame extends StatelessWidget {
  final Widget child;
  const _WebPhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    const outerBg = Color(0xFFFAFAFA);
    return Container(
      color: outerBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AspectRatio(
            aspectRatio: 9 / 19.5,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 844),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCC97FF).withValues(alpha: 0.12),
                      blurRadius: 32,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _WebSimulatedStatusBar(),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web 预览：顶部模拟手机状态栏（时间、信号、电量）
class _WebSimulatedStatusBar extends StatelessWidget {
  const _WebSimulatedStatusBar();

  @override
  Widget build(BuildContext context) {
    const iconColor = StarpathColors.onSurfaceVariant;
    return ColoredBox(
      color: StarpathColors.surface,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Text(
                '9:41',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              const Icon(Icons.signal_cellular_alt_rounded,
                  size: 16, color: iconColor),
              const SizedBox(width: 5),
              const Icon(Icons.wifi_rounded, size: 16, color: iconColor),
              const SizedBox(width: 5),
              const Icon(Icons.battery_full_rounded, size: 20, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}
