import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/terminology_resolver.dart';

class AssetTerminologyRepository {
  const AssetTerminologyRepository({
    this.assetPath =
        'assets/worlds/endless_paralysis/terminology.json',
  });

  final String assetPath;

  Future<TerminologyResolver> load() async {
    final String raw = await rootBundle.loadString(assetPath);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('terminology asset must be a JSON object');
    }
    final Map<String, String> table = <String, String>{
      for (final MapEntry<String, dynamic> entry in decoded.entries)
        entry.key: entry.value.toString(),
    };
    return TerminologyResolver(table);
  }
}
