import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../theme/atelier_theme.dart';
import '../widgets/chrome.dart';

class PromptsPage extends StatelessWidget {
  const PromptsPage({super.key, required this.onStudio, required this.onCreate, required this.onUse});

  final VoidCallback onStudio;
  final VoidCallback onCreate;
  final ValueChanged<Prompt> onUse;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  Text("RESTRAINTS", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AtelierColors.cinnabar, letterSpacing: 2)),
                  Text("Prompts", style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 8),
                  Text("Most pictures fail because they try to say everything. Pick one limit and obey it.", style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  for (final prompt in prompts)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AtelierColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prompt.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(prompt.text, style: Theme.of(context).textTheme.bodyMedium),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                NoticeScope.read(context).say("Cutting a sheet for “${prompt.title}”.");
                                onUse(prompt);
                              },
                              child: const Text("Use this sheet", style: TextStyle(color: AtelierColors.cinnabar)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            AtelierDock(
              studio: false,
              onStudio: onStudio,
              onCreate: () {
                NoticeScope.read(context).say("A blank sheet, no prompt.");
                onCreate();
              },
              onPrompts: () => NoticeScope.read(context).say("You are already among the prompts."),
            ),
          ],
        ),
      ),
    );
  }
}
