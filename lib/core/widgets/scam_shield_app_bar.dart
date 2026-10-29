import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/ui_strings.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_theme.dart';

class ScamShieldAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool hideExit;
  final List<Widget>? actions;
  
  const ScamShieldAppBar({
    super.key,
    required this.title,
    this.hideExit = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(preferencesProvider).appLanguage;

    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
      ),
      backgroundColor: AppTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: hideExit 
          ? null 
          : IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 26, semanticLabel: 'Exit Practice'),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/home');
                }
              },
            ),
      actions: [
        if (actions != null) ...actions!,
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, size: 24, semanticLabel: 'Help'),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppTheme.surfaceContainerLowest,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Icon(Icons.verified_user_rounded, color: AppTheme.primaryContainer, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      UiStrings.get(lang, 'safe_practice_help'),
                      style: const TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
