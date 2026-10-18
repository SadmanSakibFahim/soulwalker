/// PLAYTEST ONLY. Amber overlay + FAB. Remove `lib/dev/` to delete this UI.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/health_source.dart';
import '../data/motion_source.dart';
import '../data/walk_store.dart';
import '../domain/terminology_resolver.dart';
import '../presentation/app_shell.dart';
import '../presentation/health_controller.dart';
import '../presentation/theme.dart';
import '../presentation/walk_controller.dart';
import 'dev_flags.dart';
import 'dev_session.dart';

class DevHost extends StatefulWidget {
  const DevHost({required this.terms, super.key});

  final TerminologyResolver terms;

  @override
  State<DevHost> createState() => _DevHostState();
}

class _DevHostState extends State<DevHost> with WidgetsBindingObserver {
  late final DevSession _session = DevSession();
  late final WalkController _walk = WalkController(
    motion: const ChannelMotionSource(),
    store: PrefsWalkStore(),
    onLocalDelta: _session.noteLocalMeters,
    onServerDelta: _session.noteServerMeters,
  );
  late final HealthController _health = HealthController(
    health: const ChannelHealthSource(),
    progressDate: () => _session.progress.progressDate,
    onDays: _session.syncActivity,
  );
  late final Listenable _ticks = Listenable.merge(<Listenable>[_session, _walk, _health]);
  bool _panelOpen = true;

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
      if (_session.apiConnected) {
        unawaited(_health.sync());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walk.dispose();
    _health.dispose();
    _session.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await _session.connect();
    await _walk.sync();
    await _health.sync();
  }

  Future<void> _reset() async {
    await _walk.discard();
    _session.reset();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ticks,
      builder: (BuildContext context, Widget? _) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 36),
                child: AppShell(
                  terms: widget.terms,
                  progress: _session.progress,
                  markers: _session.markers,
                  walking: _walk.walking,
                  walkNote: _walk.note,
                  healthNote: _health.note,
                  onSyncHealth: () => unawaited(_health.sync()),
                  onStartWalk: () => unawaited(_walk.start()),
                  onSyncWalk: () => unawaited(_walk.sync()),
                  onEndWalk: () => unawaited(_walk.end()),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: SoulwalkerPalette.accent,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'DEV  ·  ${_session.status}',
                      style: const TextStyle(
                        color: SoulwalkerPalette.ground,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_panelOpen)
              Positioned(
                right: 12,
                bottom: 96,
                child: _DevPanel(
                  session: _session,
                  onConnect: _connect,
                  onReset: _reset,
                ),
              ),
            Positioned(
              right: 16,
              bottom: 28,
              child: FloatingActionButton.small(
                backgroundColor: SoulwalkerPalette.accent,
                foregroundColor: SoulwalkerPalette.ground,
                onPressed: () => setState(() => _panelOpen = !_panelOpen),
                child: Icon(_panelOpen ? Icons.close : Icons.science_outlined),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DevPanel extends StatelessWidget {
  const _DevPanel({
    required this.session,
    required this.onConnect,
    required this.onReset,
  });

  final DevSession session;
  final Future<void> Function() onConnect;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: SoulwalkerPalette.mist,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Playtest hacks',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'API $kDevApiBase',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _HackButton(
                    label: 'Connect API',
                    onTap: () => unawaited(onConnect()),
                  ),
                  _HackButton(
                    label: '+1 km',
                    onTap: () => unawaited(session.addMeters(1000)),
                  ),
                  _HackButton(
                    label: '+3 km',
                    onTap: () => unawaited(session.addMeters(3000)),
                  ),
                  _HackButton(
                    label: '+5 km',
                    onTap: () => unawaited(session.addMeters(5000)),
                  ),
                  _HackButton(
                    label: 'Close day',
                    onTap: () => unawaited(session.closeDay()),
                  ),
                  _HackButton(
                    label: 'Pull lore',
                    onTap: () => unawaited(session.pullLore()),
                  ),
                  _HackButton(label: 'Drop death marker', onTap: session.dropDeathMarker),
                  _HackButton(label: 'Reset local', onTap: () => unawaited(onReset())),
                ],
              ),
              if (session.lastLore != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(session.lastLore!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HackButton extends StatelessWidget {
  const _HackButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
