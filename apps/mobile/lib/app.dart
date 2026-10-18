import 'package:flutter/material.dart';

import 'data/asset_terminology_repository.dart';
import 'dev/dev_flags.dart';
import 'dev/dev_host.dart';
import 'domain/terminology_resolver.dart';
import 'presentation/play_host.dart';
import 'presentation/theme.dart';

class SoulwalkerApp extends StatelessWidget {
  const SoulwalkerApp({
    super.key,
    this.repository = const AssetTerminologyRepository(),
  });

  final AssetTerminologyRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soulwalker',
      debugShowCheckedModeBanner: kSoulwalkerDev,
      theme: buildSoulwalkerTheme(),
      home: FutureBuilder<TerminologyResolver>(
        future: repository.load(),
        builder: (
          BuildContext context,
          AsyncSnapshot<TerminologyResolver> snapshot,
        ) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Failed to load terminology')),
            );
          }
          final TerminologyResolver? terms = snapshot.data;
          if (terms == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (kSoulwalkerDev) {
            return DevHost(terms: terms);
          }
          return PlayHost(terms: terms);
        },
      ),
    );
  }
}
