import 'package:flutter/material.dart';

import 'models/catalog.dart';
import 'screens/create_page.dart';
import 'screens/editor_page.dart';
import 'screens/prompts_page.dart';
import 'screens/studio_page.dart';
import 'theme/atelier_theme.dart';
import 'widgets/chrome.dart';

class VermilionApp extends StatefulWidget {
  const VermilionApp({super.key});

  @override
  State<VermilionApp> createState() => _VermilionAppState();
}

class _VermilionAppState extends State<VermilionApp> {
  final _bus = NoticeBus();

  @override
  void dispose() {
    _bus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NoticeScope(
      bus: _bus,
      child: MaterialApp(
        title: "Vermilion Atelier",
        debugShowCheckedModeBanner: false,
        theme: buildAtelierTheme(),
        builder: (context, child) => ToastOverlay(bus: _bus, child: child ?? const SizedBox.shrink()),
        home: const AtelierShell(),
      ),
    );
  }
}

sealed class Dest {
  const Dest();
}

class StudioDest extends Dest {
  const StudioDest();
}

class PromptsDest extends Dest {
  const PromptsDest();
}

class CreateDest extends Dest {
  const CreateDest({required this.preset, required this.paper, this.promptTitle});

  final String preset;
  final PaperId paper;
  final String? promptTitle;
}

class EditDest extends Dest {
  const EditDest(this.draft);

  final Draft draft;
}

class AtelierShell extends StatefulWidget {
  const AtelierShell({super.key});

  @override
  State<AtelierShell> createState() => _AtelierShellState();
}

class _AtelierShellState extends State<AtelierShell> {
  Dest _dest = const StudioDest();
  int _generation = 0;

  void _go(Dest dest) => setState(() => _dest = dest);

  @override
  Widget build(BuildContext context) {
    final dest = _dest;
    return switch (dest) {
      StudioDest() => StudioPage(
          key: ValueKey("studio-$_generation"),
          onCreate: () => _go(const CreateDest(preset: "scroll", paper: PaperId.xuan)),
          onPrompts: () => _go(const PromptsDest()),
          onOpen: (draft) => _go(EditDest(draft)),
        ),
      PromptsDest() => PromptsPage(
          onStudio: () => _go(const StudioDest()),
          onCreate: () => _go(const CreateDest(preset: "scroll", paper: PaperId.xuan)),
          onUse: (prompt) => _go(CreateDest(preset: prompt.preset, paper: prompt.paper, promptTitle: prompt.title)),
        ),
      CreateDest() => CreatePage(
          presetId: dest.preset,
          paper: dest.paper,
          promptTitle: dest.promptTitle,
          onBack: () => _go(const StudioDest()),
          onBegin: (draft) => _go(EditDest(draft)),
        ),
      EditDest() => EditorPage(
          draft: dest.draft,
          onExit: () => setState(() {
            _generation++;
            _dest = const StudioDest();
          }),
        ),
    };
  }
}
