import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/walk_credit.dart';

class PrefsWalkStore implements WalkStore {
  static const String _startedKey = 'soulwalker_walk_started_ms';
  static const String _appliedKey = 'soulwalker_walk_applied_m';
  static const String _serverKey = 'soulwalker_walk_server_m';
  static const String _baselineKey = 'soulwalker_walk_step_baseline';
  static const String _originKey = 'soulwalker_walk_step_origin_m';

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<WalkCheckpoint?> load() async {
    final SharedPreferences? prefs = await _prefs();
    if (prefs == null) {
      return null;
    }
    final int? started = prefs.getInt(_startedKey);
    if (started == null) {
      return null;
    }
    return WalkCheckpoint(
      startedAt: DateTime.fromMillisecondsSinceEpoch(started),
      appliedMeters: prefs.getInt(_appliedKey) ?? 0,
      serverAppliedMeters: prefs.getInt(_serverKey) ?? 0,
      stepBaseline: prefs.getInt(_baselineKey),
      stepOriginMeters: prefs.getInt(_originKey) ?? 0,
    );
  }

  @override
  Future<void> save(WalkCheckpoint checkpoint) async {
    final SharedPreferences? prefs = await _prefs();
    if (prefs == null) {
      return;
    }
    await prefs.setInt(_startedKey, checkpoint.startedAt.millisecondsSinceEpoch);
    await prefs.setInt(_appliedKey, checkpoint.appliedMeters);
    await prefs.setInt(_serverKey, checkpoint.serverAppliedMeters);
    await prefs.setInt(_originKey, checkpoint.stepOriginMeters);
    final int? baseline = checkpoint.stepBaseline;
    if (baseline == null) {
      await prefs.remove(_baselineKey);
    } else {
      await prefs.setInt(_baselineKey, baseline);
    }
  }

  @override
  Future<void> clear() async {
    final SharedPreferences? prefs = await _prefs();
    if (prefs == null) {
      return;
    }
    await prefs.remove(_startedKey);
    await prefs.remove(_appliedKey);
    await prefs.remove(_serverKey);
    await prefs.remove(_baselineKey);
    await prefs.remove(_originKey);
  }
}

class MemoryWalkStore implements WalkStore {
  WalkCheckpoint? checkpoint;

  @override
  Future<void> clear() async {
    checkpoint = null;
  }

  @override
  Future<WalkCheckpoint?> load() async => checkpoint;

  @override
  Future<void> save(WalkCheckpoint checkpoint) async {
    this.checkpoint = checkpoint;
  }
}
