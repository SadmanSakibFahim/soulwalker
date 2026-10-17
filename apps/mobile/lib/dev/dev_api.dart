/// PLAYTEST ONLY. Talks to `/v1/dev` when the API is up. Failures are non-fatal.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<WalkProgress?> grantDistance(int meters) async {
    return _postProgress('/v1/dev/grant-distance', <String, int>{'meters': meters});
  }

  Future<WalkProgress?> setStreak(int days) async {
    return _postProgress('/v1/dev/set-streak', <String, int>{'days': days});
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
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return WalkProgress(
        totalDistanceM: decoded['total_distance_m'] as int? ?? 0,
        streakDays: decoded['current_encounter_streak_days'] as int? ?? 0,
      );
    } on Exception {
      return null;
    }
  }
}
