/// PLAYTEST ONLY. In-memory walk / marker / lore state for local poking.
library;

import 'package:flutter/foundation.dart';

import '../domain/progress.dart';
import 'dev_api.dart';
import 'sample_lore.dart';

class DevSession extends ChangeNotifier {
  DevSession({DevApi? api}) : _api = api ?? DevApi();

  final DevApi _api;

  WalkProgress progress = const WalkProgress();
  List<DeathMarkerView> markers = <DeathMarkerView>[];
  String? lastLore;
  String status = 'offline — hacks are local until you connect';
  bool apiConnected = false;
  int _loreIndex = 0;
  int _deathAttempt = 0;

  Future<void> connect() async {
    status = 'connecting…';
    notifyListeners();
    final bool up = await _api.ping();
    if (!up) {
      apiConnected = false;
      status = 'API down — local hacks still work (${_api.baseUrl})';
      notifyListeners();
      return;
    }
    final bool ok = await _api.bootstrap();
    apiConnected = ok;
    status = ok ? 'connected as playtest player' : 'API up but bootstrap failed';
    notifyListeners();
  }

  Future<void> addMeters(int meters) async {
    progress = progress.copyWith(
      totalDistanceM: progress.totalDistanceM + meters,
    );
    notifyListeners();
    final WalkProgress? remote = await _api.grantDistance(meters);
    if (remote != null) {
      progress = remote;
      notifyListeners();
    }
  }

  Future<void> addStreakDay() async {
    progress = progress.copyWith(streakDays: progress.streakDays + 1);
    notifyListeners();
    final WalkProgress? remote = await _api.setStreak(progress.streakDays);
    if (remote != null) {
      progress = remote;
      notifyListeners();
    }
  }

  Future<void> pullLore() async {
    final String? remote = await _api.deliverLore();
    lastLore = remote ?? kDevSampleLore[_loreIndex % kDevSampleLore.length];
    _loreIndex += 1;
    notifyListeners();
  }

  void dropDeathMarker() {
    _deathAttempt += 1;
    markers = <DeathMarkerView>[
      ...markers,
      DeathMarkerView(attemptNumber: _deathAttempt),
    ];
    notifyListeners();
  }

  void reset() {
    progress = const WalkProgress();
    markers = <DeathMarkerView>[];
    lastLore = null;
    _loreIndex = 0;
    _deathAttempt = 0;
    notifyListeners();
  }
}
