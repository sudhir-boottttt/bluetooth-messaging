import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../identity/domain/identity_repository.dart';

/// Resolves local onboarding state before showing a user-facing screen.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _continue();
  }

  Future<void> _continue() async {
    final hasIdentity = await getIt<IdentityRepository>().exists();
    if (!mounted) return;
    context.go(hasIdentity ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 72),
          SizedBox(height: 16),
          Text('MeshChat'),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}
