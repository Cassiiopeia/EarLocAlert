import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/vibration_check.dart';
import 'prefs_vibration_check_store.dart';

part 'vibration_check_store_provider.g.dart';

@Riverpod(keepAlive: true)
VibrationCheckStore vibrationCheckStore(Ref ref) => PrefsVibrationCheckStore();
