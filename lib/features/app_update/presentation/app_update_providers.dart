import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/play_app_updater.dart';
import '../domain/app_updater.dart';

part 'app_update_providers.g.dart';

/// 앱 내 업데이트 (이슈 #170) — 확인 간격을 앱 수명 동안 기억해야 하므로 유지한다
@Riverpod(keepAlive: true)
AppUpdateGate appUpdateGate(Ref ref) => AppUpdateGate(const PlayAppUpdater());
