import 'dart:async';

import 'package:flutter/material.dart';

import '../data/health_source.dart';
import '../data/motion_source.dart';
import '../data/walk_store.dart';
import '../domain/activity_sync.dart';
import '../domain/encounter_loop.dart';
import '../domain/progress.dart';
import '../domain/terminology_resolver.dart';
import 'app_shell.dart';
import 'health_controller.dart';
import 'walk_controller.dart';

/// Checkpoint shell with a real pocket walk. Used when the dev panel is off.
class PlayHost extends StatefulWidget {
  const PlayHost({required this.terms, super.key});

  final TerminologyResolver terms;

  @override
  State<PlayHost> createState() => _PlayHostState();
}

class _PlayHostState extends State<PlayHost> with WidgetsBindingObserver {
  WalkProgress _progress = const WalkProgress();
  late final WalkController _walk = WalkController(
    motion: const ChannelMotionSource(),
    store: PrefsWalkStore(),
    onLocalDelta: (int meters) {
      _progress = recordDistance(_progress, meters);
    },
    onServerDelta: (int meters) async => false,
  );
  late final HealthController _health = HealthController(
    health: const ChannelHealthSource(),
    progressDate: () => _progress.progressDate,
    onDays: (List<DayActivity> days) async {
      _progress = applyActivityDays(_progress, days);
    },
  );
  late final Listenable _ticks = Listenable.merge(<Listenable>[_walk, _health]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_walk.restore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_walk.sync());
      unawaited(_health.sync());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walk.dispose();
    _health.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ticks,
      builder: (BuildContext context, Widget? _) {
        return AppShell(
          terms: widget.terms,
          progress: _progress,
          walking: _walk.walking,
          walkNote: _walk.note,
          healthNote: _health.note,
          onSyncHealth: () => unawaited(_health.sync()),
          onStartWalk: () => unawaited(_walk.start()),
          onSyncWalk: () => unawaited(_walk.sync()),
          onEndWalk: () => unawaited(_walk.end()),
        );
      },
    );
  }
}
