import 'package:flutter/material.dart';

import '../../domain/activity_sync.dart';
import '../../domain/encounter_loop.dart';
import '../../domain/progress.dart';
import '../../domain/term_key.dart';
import '../../domain/terminology_resolver.dart';

class CheckpointScreen extends StatelessWidget {
  const CheckpointScreen({
    required this.terms,
    this.progress = const WalkProgress(),
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
  final bool walking;
  final String walkNote;
  final String healthNote;
  final VoidCallback? onSyncHealth;
  final VoidCallback? onStartWalk;
  final VoidCallback? onSyncWalk;
  final VoidCallback? onEndWalk;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String name = terms.resolve(TermKey.checkpointName);
    final String encounter = terms.resolve(TermKey.bossEncounterLabel);
    final String walked = progress.totalKm.toStringAsFixed(1);
    final String today = progress.todayKm.toStringAsFixed(1);
    final String quota = (EncounterRules.dailyQualifyM / 1000).toStringAsFixed(1);
    final int length = EncounterRules.encounterLengthDays;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(
            'Rest here. Progress is banked. The night does not take what you have already walked.',
            style: textTheme.bodyLarge,
          ),
          if (progress.progressDate != null) ...<Widget>[
            const SizedBox(height: 16),
            Text('Open day ${formatDay(progress.progressDate!)}', style: textTheme.bodyLarge),
          ],
          if (onSyncHealth != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSyncHealth,
              child: const Text('Sync Apple Health'),
            ),
            if (healthNote.isNotEmpty)
              Text(healthNote, style: textTheme.bodyLarge),
          ],
          if (onStartWalk != null) ...<Widget>[
            const SizedBox(height: 16),
            if (!walking)
              FilledButton(
                onPressed: onStartWalk,
                child: const Text('Start walk'),
              ),
            if (walking) ...<Widget>[
              FilledButton(
                onPressed: onSyncWalk,
                child: const Text('Bank distance'),
              ),
              TextButton(
                onPressed: onEndWalk,
                child: const Text('End walk'),
              ),
            ],
            if (walkNote.isNotEmpty)
              Text(walkNote, style: textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
          Text('Walked $walked km', style: textTheme.bodyLarge),
          Text('Today $today / $quota km', style: textTheme.bodyLarge),
          Text(
            '$encounter · day ${progress.streakDays} of $length · attempt ${progress.attempt}',
            style: textTheme.bodyLarge,
          ),
          Text(
            'Encounters finished ${progress.encountersCompleted}',
            style: textTheme.bodyLarge,
          ),
          for (final int tier in progress.unlockedTiers)
            Text(terms.resolve(_armamentTerm(tier)), style: textTheme.bodyLarge),
          if (progress.events.contains(EncounterEventKind.death)) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'The attempt ended. You return here. Walked distance and armaments stay.',
              style: textTheme.bodyLarge,
            ),
          ],
          if (progress.events.contains(EncounterEventKind.encounterCompleted)) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'The encounter is over. Distance and armaments stay banked.',
              style: textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

TermKey _armamentTerm(int tier) {
  return switch (tier) {
    1 => TermKey.armamentCategoryWeapon,
    2 => TermKey.armamentCategoryArmor,
    _ => throw ArgumentError('Unknown armament tier: $tier'),
  };
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
