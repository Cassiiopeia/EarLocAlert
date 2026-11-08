import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/entitlement/feature_access_controller.dart';
import '../features/places/data/cloud_sync_providers.dart';
import '../features/places/data/place_repository_provider.dart';
import '../features/places/domain/cloud_sync_service.dart';

part 'cloud_sync_coordinator.g.dart';

/// 구글 드라이브 동기화 시점 (#330): 장소 변화 > 3초 몰아서, 앱 시작, 전면 복귀
///
/// 흐름·판정은 [CloudSyncService]. 여기는 언제 부를지와 화면 상태 갱신만
class CloudSyncCoordinator {
  CloudSyncCoordinator(this._ref, this.service);

  final Ref _ref;
  final CloudSyncService service;

  // 연속 편집을 한 번 동기화로 묶는 대기 시간 (자동 백업과 같은 값, 각자 둠)
  static const _debounceDuration = Duration(seconds: 3);

  StreamSubscription<Object?>? _placesSubscription;
  Timer? _debounce;

  void start() {
    if (_placesSubscription != null) return;
    _placesSubscription = _ref
        .read(placeRepositoryProvider)
        .watchAll()
        .listen(
          (_) => _schedule(),
          onError: (Object error) =>
              Diagnostics.log('cloudsync', 'places watch failed error=$error'),
        );
  }

  /// 앱이 앞으로 옴 > 다른 기기 변경 반영
  void onResumed() => unawaited(runNow(reason: 'resumed'));

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(
      _debounceDuration,
      () => unawaited(runNow(reason: 'places_changed')),
    );
  }

  Future<CloudSyncOutcome> runNow({required String reason}) async {
    final outcome = await service.sync(reason: reason);
    if (outcome == CloudSyncOutcome.synced) {
      _ref.invalidate(cloudSyncStatusProvider);
    }
    return outcome;
  }

  Future<CloudSyncConnectResult> connect() async {
    final connectResult = await service.connect();
    _ref.invalidate(cloudSyncStatusProvider);
    return connectResult;
  }

  Future<CloudSyncOutcome> confirmImport() async {
    final outcome = await service.confirmImport();
    _ref.invalidate(cloudSyncStatusProvider);
    return outcome;
  }

  Future<void> disconnect({required bool deleteRemote}) async {
    await service.disconnect(deleteRemote: deleteRemote);
    _ref.invalidate(cloudSyncStatusProvider);
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_placesSubscription?.cancel());
  }
}

@Riverpod(keepAlive: true)
CloudSyncCoordinator cloudSyncCoordinator(Ref ref) {
  final service = CloudSyncService(
    account: ref.watch(cloudSyncAccountProvider),
    remote: ref.watch(cloudSyncRemoteProvider),
    store: ref.watch(cloudSyncStateStoreProvider),
    repository: ref.watch(placeRepositoryProvider),
    // 매번 현재 등급을 읽음 (구매·환불이 바로 반영되게)
    isPro: () => ref.read(featureAccessControllerProvider).canUseCloudSync,
    nowUtc: () => DateTime.now().toUtc(),
    maximumPlaces: () => ref.read(featureAccessControllerProvider).placeLimit,
    deviceLabel: Platform.isIOS ? 'iPhone' : 'Android',
  );
  final coordinator = CloudSyncCoordinator(ref, service);
  ref.onDispose(coordinator.dispose);
  return coordinator;
}
