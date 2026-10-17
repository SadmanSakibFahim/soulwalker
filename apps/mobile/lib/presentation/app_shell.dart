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
    super.key,
  });

  final TerminologyResolver terms;
  final WalkProgress progress;
  final List<DeathMarkerView> markers;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final TerminologyResolver terms = widget.terms;
    final List<Widget> pages = <Widget>[
      CheckpointScreen(terms: terms, progress: widget.progress),
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
