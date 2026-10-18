/// PLAYTEST ONLY. Talks to `/v1/dev` when the API is up. Failures are non-fatal.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/activity_sync.dart';
import '../domain/progress.dart';
import 'dev_flags.dart';

class DevApi {
  DevApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? kDevApiBase;

  final http.Client _client;
  final String baseUrl;
  String? token;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<bool> ping() async {
    try {
      final http.Response response = await _client
          .get(_uri('/v1/dev/status'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  Future<bool> bootstrap() async {
    try {
      final http.Response response = await _client
          .post(_uri('/v1/dev/bootstrap'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return false;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      token = decoded['access_token'] as String?;
      return token != null;
    } on Exception {
      return false;
    }
  }

  Future<WalkProgress?> fetchProgress() async {
    if (token == null) {
      return null;
    }
    try {
      final http.Response response = await _client
          .get(_uri('/v1/progress'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return null;
      }
      return _parseProgress(jsonDecode(response.body));
    } on Exception {
      return null;
    }
  }

  Future<WalkProgress?> grantDistance(int meters) async {
    return _postProgress('/v1/dev/grant-distance', <String, int>{'meters': meters});
  }

  Future<WalkProgress?> closeDay() async {
    return _postProgress('/v1/dev/close-day', <String, int>{});
  }

  Future<WalkProgress?> syncActivity(List<DayActivity> days) async {
    if (token == null) {
      return null;
    }
    try {
      final http.Response response = await _client
          .post(
            _uri('/v1/progress/activity'),
            headers: _headers,
            body: jsonEncode(<String, List<Map<String, Object>>>{
              'days': <Map<String, Object>>[
                for (final DayActivity day in days)
                  <String, Object>{
                    'date': formatDay(day.date),
                    'distance_m': day.distanceMeters,
                  },
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }
      return _parseProgress(jsonDecode(response.body));
    } on Exception {
      return null;
    }
  }

  Future<String?> deliverLore() async {
    if (token == null) {
      return null;
    }
    try {
      final http.Response response = await _client
          .post(
            _uri('/v1/dev/deliver-lore'),
            headers: _headers,
            body: jsonEncode(<String, String>{'trigger_type': 'daily_ambient'}),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return decoded['text'] as String?;
    } on Exception {
      return null;
    }
  }

  Future<WalkProgress?> _postProgress(String path, Map<String, int> body) async {
    if (token == null) {
      return null;
    }
    try {
      final http.Response response = await _client
          .post(
            _uri(path),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return null;
      }
      return _parseProgress(jsonDecode(response.body));
    } on Exception {
      return null;
    }
  }
}

WalkProgress? _parseProgress(Object? decoded) {
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final List<int> tiers = <int>[];
  final Object? rawTiers = decoded['unlocked_armament_tiers'];
  if (rawTiers is List) {
    for (final Object? tier in rawTiers.cast<Object?>()) {
      if (tier is int) {
        tiers.add(tier);
      }
    }
  }
  final List<EncounterEventKind> events = <EncounterEventKind>[];
  final Object? rawEvents = decoded['events'];
  if (rawEvents is List) {
    for (final Object? event in rawEvents.cast<Object?>()) {
      if (event is String) {
        final EncounterEventKind? kind = EncounterEventKind.parse(event);
        if (kind != null) {
          events.add(kind);
        }
      }
    }
  }
  return WalkProgress(
    totalDistanceM: _asInt(decoded['total_distance_m']),
    todayDistanceM: _asInt(decoded['today_distance_m']),
    progressDate: parseDay(decoded['progress_date']),
    streakDays: _asInt(decoded['current_encounter_streak_days']),
    attempt: _asInt(decoded['encounter_attempt'], fallback: 1),
    encountersCompleted: _asInt(decoded['encounters_completed']),
    unlockedTiers: tiers,
    events: events,
  );
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return fallback;
}
