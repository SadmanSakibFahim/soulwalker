import 'package:flutter/services.dart';

import '../domain/activity_sync.dart';

class ChannelHealthSource implements HealthSource {
  const ChannelHealthSource({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('soulwalker/health');

  final MethodChannel _channel;

  @override
  Future<bool> available() async {
    try {
      final Object? raw = await _channel.invokeMethod<Object?>('available');
      return raw == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestAccess() async {
    try {
      final Object? raw = await _channel.invokeMethod<Object?>('requestAccess');
      return raw == true;
    } on MissingPluginException {
      throw const HealthException(
        'This build has no Apple Health channel. Use a physical iPhone.',
      );
    } on PlatformException catch (error) {
      throw HealthException(error.message ?? 'Apple Health did not open.');
    }
  }

  @override
  Future<List<HealthDay>> readDays(List<DateTime> dates) async {
    try {
      final Object? raw = await _channel.invokeMethod<Object?>(
        'readDays',
        <String, List<String>>{
          'dates': <String>[for (final DateTime date in dates) formatDay(date)],
        },
      );
      if (raw is! Map) {
        throw const HealthException('Apple Health did not return any days.');
      }
      final Map<Object?, Object?> payload = Map<Object?, Object?>.from(raw);
      final Object? rows = payload['days'];
      if (rows is! List) {
        throw const HealthException('Apple Health did not return any days.');
      }
      final List<HealthDay> days = <HealthDay>[];
      for (final Object? row in rows) {
        if (row is! Map) {
          continue;
        }
        final Map<Object?, Object?> fields = Map<Object?, Object?>.from(row);
        final DateTime? date = parseDay(fields['date']);
        if (date == null) {
          continue;
        }
        days.add(
          HealthDay(
            date: date,
            distanceMeters: _asInt(fields['distanceMeters']),
            stepCount: _asInt(fields['stepCount']),
          ),
        );
      }
      return days;
    } on MissingPluginException {
      throw const HealthException(
        'This build has no Apple Health channel. Use a physical iPhone.',
      );
    } on PlatformException catch (error) {
      throw HealthException(error.message ?? 'Apple Health read failed.');
    }
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return null;
}
