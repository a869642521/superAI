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
    );

    if (kIsWeb) {
      const outerBg = Color(0xFFFAFAFA); // App 外：浅白底
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Starpath',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: outerBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFCC97FF),
            brightness: Brightness.light,
          ),
        ),
        home: Scaffold(
          backgroundColor: outerBg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AspectRatio(
                aspectRatio: 9 / 19.5,
                child: Container(
                constraints: const BoxConstraints(maxHeight: 844),
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
                      Expanded(child: app),
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

    return app;
  }
}

/// Web 预览：顶部模拟手机状态栏（时间、信号、电量）
class _WebSimulatedStatusBar extends StatelessWidget {
  const _WebSimulatedStatusBar();

  @override
  Widget build(BuildContext context) {
    final iconColor = StarpathColors.onSurfaceVariant;
    return Material(
      color: StarpathColors.surface,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text(
                '9:41',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Icon(Icons.signal_cellular_alt_rounded,
                  size: 16, color: iconColor),
              const SizedBox(width: 5),
              Icon(Icons.wifi_rounded, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Icon(Icons.battery_full_rounded, size: 20, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}
