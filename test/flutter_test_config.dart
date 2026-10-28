import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled fonts so layout tests measure real text, not the
/// default test font where every glyph is a full square.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const families = {
    'DM Sans': ['DMSans-Regular.ttf', 'DMSans-SemiBold.ttf'],
    'Space Grotesk': ['SpaceGrotesk-SemiBold.ttf'],
    'Space Mono': ['SpaceMono-Regular.ttf', 'SpaceMono-Bold.ttf'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  await testMain();
}
