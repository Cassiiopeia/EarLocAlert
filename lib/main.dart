import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // Riverpod 으로 통일한다 — get_it 을 병행하지 않는다
  // (docs/02-ARCHITECTURE.md)
  runApp(const ProviderScope(child: EarLocAlertApp()));
}
