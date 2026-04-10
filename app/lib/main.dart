import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/core/router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';

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
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
                  child: app,
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
