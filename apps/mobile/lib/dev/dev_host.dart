/// PLAYTEST ONLY. Amber overlay + FAB. Remove `lib/dev/` to delete this UI.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/terminology_resolver.dart';
import '../presentation/app_shell.dart';
import '../presentation/theme.dart';
import 'dev_flags.dart';
import 'dev_session.dart';

class DevHost extends StatefulWidget {
  const DevHost({required this.terms, super.key});

  final TerminologyResolver terms;

  @override
  State<DevHost> createState() => _DevHostState();
}

class _DevHostState extends State<DevHost> {
  late final DevSession _session = DevSession();
  bool _panelOpen = true;

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
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
                child: _DevPanel(session: _session),
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
  const _DevPanel({required this.session});

  final DevSession session;

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
                    onTap: () => unawaited(session.connect()),
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
                    label: '+1 streak day',
                    onTap: () => unawaited(session.addStreakDay()),
                  ),
                  _HackButton(
                    label: 'Pull lore',
                    onTap: () => unawaited(session.pullLore()),
                  ),
                  _HackButton(label: 'Drop death marker', onTap: session.dropDeathMarker),
                  _HackButton(label: 'Reset local', onTap: session.reset),
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
