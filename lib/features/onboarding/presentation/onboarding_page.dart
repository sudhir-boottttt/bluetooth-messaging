import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../identity/domain/identity_repository.dart';

/// Creates a local encrypted identity; no account, phone number, or server.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _creating = false;

  Future<void> _createIdentity() async {
    setState(() => _creating = true);
    try {
      await getIt<IdentityRepository>().getOrCreate();
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hub,
                size: 88,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Private messages,\nwithout the internet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'MeshChat creates an encrypted identity that stays on this device.',
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _creating ? null : _createIdentity,
                icon: _creating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key),
                label: const Text('Create secure identity'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
