import 'package:flutter/services.dart';

import '../domain/walk_credit.dart';

class ChannelMotionSource implements MotionSource {
  const ChannelMotionSource({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('soulwalker/motion');

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
  Future<MotionReading> read({required DateTime start}) async {
    try {
      final Object? raw = await _channel.invokeMethod<Object?>(
        'read',
        <String, int>{'startMs': start.millisecondsSinceEpoch},
      );
      if (raw is! Map) {
        throw const MotionException('The phone did not return a distance.');
      }
      final Map<Object?, Object?> payload = Map<Object?, Object?>.from(raw);
      final Object? distance = payload['distanceMeters'];
      final Object? steps = payload['stepCount'];
      return MotionReading(
        distanceMeters: distance is int ? distance : null,
        stepCount: steps is int ? steps : null,
      );
    } on MissingPluginException {
      throw const MotionException(
        'This device has no motion counter. Use a physical phone.',
      );
    } on PlatformException catch (error) {
      throw MotionException(error.message ?? 'Motion read failed.');
    }
  }
}
