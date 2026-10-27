import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/entitlement/feature_access_controller.dart';
import '../features/places/data/auto_backup_providers.dart';
import '../features/places/data/place_repository_provider.dart';
import '../features/places/domain/auto_backup.dart';
import 'app_version_provider.dart';

part 'auto_backup_coordinator.g.dart';

/// 장소 자동 백업 (#314): 장소 변화 > 3초 몰아서 > 프로 확인 > 폴더에 쓰기
///
/// 앱이 켜진 동안만 (장소는 앱 화면에서만 바뀜). 시작 직후 첫 목록도 한 번 확인 (내용이 같으면 쓰지 않음)
class AutoBackupCoordinator {
  AutoBackupCoordinator(this._ref);

  final Ref _ref;

  // 연속 편집을 한 번 쓰기로 묶는 대기 시간
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
              Diagnostics.log('backup', 'places watch failed error=$error'),
        );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(
      _debounceDuration,
      () => unawaited(runNow(reason: 'places_changed')),
    );
  }

  /// 지금 쓰기 ([force] true = 내용이 같아도 씀, 설정의 "지금 백업")
  Future<AutoBackupOutcome?> runNow({
    required String reason,
    bool force = false,
  }) async {
    if (!_ref.read(featureAccessControllerProvider).canUsePlaceBackup) {
      Diagnostics.log(
        'backup',
        'auto backup skipped reason=$reason result=not_pro',
      );
      return null;
    }
    try {
      final places = await _ref.read(placeRepositoryProvider).findAll();
      final appVersion = await _ref.read(appVersionProvider.future);
      final outcome = await _ref
          .read(autoBackupServiceProvider)
          .backup(
            places,
            nowUtc: DateTime.now().toUtc(),
            appVersion: appVersion,
            reason: reason,
            force: force,
          );
      if (outcome == AutoBackupOutcome.written) {
        _ref.invalidate(autoBackupStatusProvider);
      }
      return outcome;
    } on Object catch (error) {
      Diagnostics.log(
        'backup',
        'auto backup error reason=$reason error=$error',
      );
      return AutoBackupOutcome.failed;
    }
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_placesSubscription?.cancel());
  }
}

@Riverpod(keepAlive: true)
AutoBackupCoordinator autoBackupCoordinator(Ref ref) {
  final coordinator = AutoBackupCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
}
