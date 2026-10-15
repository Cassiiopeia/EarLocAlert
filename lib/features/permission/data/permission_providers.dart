import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/full_screen_intent_gate.dart';
import '../domain/permission_gate.dart';
import '../domain/permission_service.dart';
import '../domain/reliability_prompt_store.dart';
import 'full_screen_intent_channel.dart';
import 'permission_handler_service.dart';
import 'prefs_reliability_prompt_store.dart';

part 'permission_providers.g.dart';

/// 전체화면 알림 권한은 `permission_handler` 밖이라 네이티브 채널로 읽는다
/// (이슈 #74). iOS·구버전 Android 에서는 채널이 없어 항상 허용으로 떨어진다.
@Riverpod(keepAlive: true)
FullScreenIntentGate fullScreenIntentGate(Ref ref) =>
    const FullScreenIntentChannel();

@Riverpod(keepAlive: true)
ReliabilityPromptStore reliabilityPromptStore(Ref ref) =>
    const PrefsReliabilityPromptStore();

@Riverpod(keepAlive: true)
PermissionService permissionService(Ref ref) => PermissionHandlerService(
  fullScreenIntent: ref.watch(fullScreenIntentGateProvider),
);

@Riverpod(keepAlive: true)
PermissionGate permissionGate(Ref ref) => const PermissionGate();
