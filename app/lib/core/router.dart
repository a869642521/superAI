import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/auth/presentation/login_page.dart';
import 'package:starpath/features/onboarding/presentation/onboarding_page.dart';
import 'package:starpath/features/agent_studio/presentation/agent_create_page.dart';
import 'package:starpath/features/chat/presentation/chat_list_page.dart';
import 'package:starpath/features/chat/presentation/chat_detail_page.dart';
import 'package:starpath/features/discovery/presentation/discovery_page.dart';
import 'package:starpath/features/discovery/presentation/card_detail_page.dart';
import 'package:starpath/features/creation/presentation/create_card_page.dart';
import 'package:starpath/features/profile/presentation/profile_page.dart';
import 'package:starpath/features/profile/presentation/wallet_page.dart';
import 'package:starpath/shared/widgets/main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(WidgetRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/discovery',
    redirect: (context, state) {
      final loc = state.uri.path;
      if (loc == '/' || loc.isEmpty) {
        return '/discovery';
      }

      final isLoginRoute = state.matchedLocation == '/login';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      // Web 预览：跳过登录与引导，直接进入主页
      if (kIsWeb) {
        if (isLoginRoute || isOnboardingRoute) {
          return '/discovery';
        }
        return null;
      }

      if (!authState.isLoggedIn) {
        return isLoginRoute ? null : '/login';
      }

      if (!authState.hasCompletedOnboarding) {
        return isOnboardingRoute ? null : '/onboarding';
      }

      if (isLoginRoute || isOnboardingRoute) {
        return '/discovery';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/discovery',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discovery',
                builder: (context, state) => const DiscoveryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const CreateCardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/agents/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AgentCreatePage(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['conversationId']!;
          return ChatDetailPage(conversationId: id);
        },
      ),
      GoRoute(
        path: '/wallet',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WalletPage(),
      ),
      GoRoute(
        path: '/cards/:cardId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            CardDetailPage(cardId: state.pathParameters['cardId']!),
      ),
    ],
  );
}
