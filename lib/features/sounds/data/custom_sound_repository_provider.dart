import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../domain/custom_sound_repository.dart';
import 'drift_custom_sound_repository.dart';

part 'custom_sound_repository_provider.g.dart';

/// 사용자가 올린 알림음 (이슈 #121)
@Riverpod(keepAlive: true)
CustomSoundRepository customSoundRepository(Ref ref) {
  return DriftCustomSoundRepository(ref.watch(appDatabaseProvider));
}
