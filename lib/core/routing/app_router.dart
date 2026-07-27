import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/splash/presentation/splash_page.dart';

/// Named, declarative navigation for the app shell and feature entry points.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, state) => const SplashPage()),
    GoRoute(path: '/onboarding', builder: (_, state) => const OnboardingPage()),
    GoRoute(path: '/home', builder: (_, state) => const HomePage()),
  ],
  errorBuilder: (_, state) =>
      Scaffold(body: Center(child: Text('Route not found: ${state.uri}'))),
);
