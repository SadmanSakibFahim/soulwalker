import 'package:flutter/material.dart';

import '../../domain/progress.dart';
import '../../domain/term_key.dart';
import '../../domain/terminology_resolver.dart';

class CheckpointScreen extends StatelessWidget {
  const CheckpointScreen({
    required this.terms,
    this.progress = const WalkProgress(),
    super.key,
  });

  final TerminologyResolver terms;
  final WalkProgress progress;

  @override
  Widget build(BuildContext context) {
    final String name = terms.resolve(TermKey.checkpointName);
    final String km = progress.totalKm.toStringAsFixed(1);
    return _KeyedPlaceholder(
      title: name,
      body:
          'Rest here. Progress is banked. The night does not take what you have already walked.\n\n'
          'Walked $km km · encounter streak ${progress.streakDays}d',
    );
  }
}

class StandingsScreen extends StatelessWidget {
  const StandingsScreen({
    required this.terms,
    this.progress = const WalkProgress(),
    super.key,
  });

  final TerminologyResolver terms;
  final WalkProgress progress;

  @override
  Widget build(BuildContext context) {
    final String km = progress.totalKm.toStringAsFixed(1);
    return _KeyedPlaceholder(
      title: terms.resolve(TermKey.standingsName),
      body: km == '0.0'
          ? 'No standings yet. Distance will appear here when walking is recorded.'
          : 'You have walked $km km. Rankings are not live in this slice.',
    );
  }
}

class SummonsScreen extends StatelessWidget {
  const SummonsScreen({required this.terms, super.key});

  final TerminologyResolver terms;

  @override
  Widget build(BuildContext context) {
    return _KeyedPlaceholder(
      title: terms.resolve(TermKey.summonsName),
      body: 'No nearby partners yet. Matching is not wired in this slice.',
    );
  }
}

class DeathMarkerScreen extends StatelessWidget {
  const DeathMarkerScreen({
    required this.terms,
    this.markers = const <DeathMarkerView>[],
    super.key,
  });

  final TerminologyResolver terms;
  final List<DeathMarkerView> markers;

  @override
  Widget build(BuildContext context) {
    final String name = terms.resolve(TermKey.deathMarkerName);
    if (markers.isEmpty) {
      return _KeyedPlaceholder(
        title: name,
        body:
            'No anonymous markers yet. Failed encounters will appear as a fixed type, never as free text.',
      );
    }
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: textTheme.headlineMedium),
          const SizedBox(height: 16),
          ...markers.map(
            (DeathMarkerView marker) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Died here, attempt #${marker.attemptNumber}',
                style: textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyedPlaceholder extends StatelessWidget {
  const _KeyedPlaceholder({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(body, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
