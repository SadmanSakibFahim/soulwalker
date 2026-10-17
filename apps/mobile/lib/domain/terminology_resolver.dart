import 'term_key.dart';

/// Resolves world-agnostic keys to fictional strings. Engine code must never
/// interpolate mythos literals.
class TerminologyResolver {
  TerminologyResolver(Map<String, String> table)
      : _table = Map<String, String>.unmodifiable(table);

  final Map<String, String> _table;

  String resolve(TermKey key) {
    final String? value = _table[key.storageKey];
    if (value == null || value.trim().isEmpty) {
      throw MissingTermException(key);
    }
    return value;
  }

  Map<String, String> get asMap => _table;
}
