import 'package:flutter/material.dart';

import '../domain/progress.dart';
import '../domain/term_key.dart';
import '../domain/terminology_resolver.dart';
import 'screens/v1_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.terms,
    this.progress = const WalkProgress(),
    this.markers = const <DeathMarkerView>[],
    this.walking = false,
    this.walkNote = '',
    this.healthNote = '',
    this.onSyncHealth,
    this.onStartWalk,
    this.onSyncWalk,
    this.onEndWalk,
    super.key,
  });

  final TerminologyResolver terms;
  final WalkProgress progress;
  final List<DeathMarkerView> markers;
  final bool walking;
  final String walkNote;
  final String healthNote;
  final VoidCallback? onSyncHealth;
  final VoidCallback? onStartWalk;
  final VoidCallback? onSyncWalk;
  final VoidCallback? onEndWalk;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final TerminologyResolver terms = widget.terms;
    final List<Widget> pages = <Widget>[
      CheckpointScreen(
        terms: terms,
        progress: widget.progress,
        walking: widget.walking,
        walkNote: widget.walkNote,
        healthNote: widget.healthNote,
        onSyncHealth: widget.onSyncHealth,
        onStartWalk: widget.onStartWalk,
        onSyncWalk: widget.onSyncWalk,
        onEndWalk: widget.onEndWalk,
      ),
      StandingsScreen(terms: terms, progress: widget.progress),
      SummonsScreen(terms: terms),
      DeathMarkerScreen(terms: terms, markers: widget.markers),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() => _index = value);
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.self_improvement_outlined),
            label: terms.resolve(TermKey.checkpointName),
          ),
          NavigationDestination(
            icon: const Icon(Icons.nightlight_outlined),
            label: terms.resolve(TermKey.standingsName),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            label: terms.resolve(TermKey.summonsName),
          ),
          NavigationDestination(
            icon: const Icon(Icons.place_outlined),
            label: terms.resolve(TermKey.deathMarkerName),
          ),
        ],
      ),
    );
  }
}
