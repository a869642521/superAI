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
    statusBarIconBrightness: Brightness.dark,
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
      theme: StarpathTheme.lightTheme,
      routerConfig: router,
    );

    if (kIsWeb) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Starpath',
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1D26),
          body: Center(
            child: AspectRatio(
              aspectRatio: 9 / 19.5,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 844),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: app,
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
