import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/large_button.dart';

class RoleChoiceScreen extends StatelessWidget {
  const RoleChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to ${l10n.appTitle}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              LargeButton(
                text: l10n.roleSenior,
                onPressed: () => context.go('/onboarding/senior'),
              ),
              const SizedBox(height: 24),
              LargeButton(
                text: l10n.roleFamily,
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () => context.go('/family'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}