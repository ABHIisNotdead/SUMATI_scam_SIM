import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScamShieldAppBar extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: hideExit 
          ? null 
          : IconButton(
              icon: const Icon(Icons.close, semanticLabel: 'Exit Practice'),
              onPressed: () => context.go('/home'),
            ),
      actions: [
        if (actions != null) ...actions!,
        IconButton(
          icon: const Icon(Icons.help_outline, semanticLabel: 'Help'),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'This is a safe practice space. No real money, data, or accounts are used.',
                  style: TextStyle(fontSize: 18),
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
