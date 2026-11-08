import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/ad_unit_ids.dart';
import '../../core/config/app_build_flavor.dart';
import '../../core/config/build_info.dart';
import '../../core/config/dev_flag.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/domain/alert_direction.dart';
import '../../core/entitlement/feature_access_controller.dart';
import '../../features/ads/data/ads_providers.dart';
import '../../features/permission/presentation/reliability_prompt_provider.dart';
import '../../features/places/data/place_repository_provider.dart';
import '../../features/places/domain/cloud_sync_service.dart';
import '../app_state_reporter.dart';
import '../background/pending_alert.dart';
import '../cloud_sync_coordinator.dart';
import '../geofence_providers.dart';
import '../review_prompt_coordinator.dart';

part 'dev_tools_actions.g.dart';

/// 시험 알림 결과: 대기 알림 저장됨 / 등록 장소 없음
enum DevTestAlertResult { queued, noPlace }

/// 개발자 도구 동작 모음 (#359): 시험 알림, 광고, 후기, 온보딩, 감시, 동기화, 상태 보고
/// 여러 기능을 건드리므로 app 계층에 둠 (CLAUDE.md 규칙 4). 개발 빌드가 아니면 화면 자체가 없음
class DevToolsActions {
  DevToolsActions(this._ref);

  final Ref _ref;

  /// 첫 장소로 대기 알림 저장 > 앱의 대기 알림 폴링(3초)이 실제 승격 경로로 울림
  Future<DevTestAlertResult> queueTestAlert(AlertDirection direction) async {
    final places = await _ref.read(placeRepositoryProvider).findAll();
    if (places.isEmpty) {
      Diagnostics.log('devtools', 'test alert skipped reason=no_place');
      return DevTestAlertResult.noPlace;
    }
    final place = places.first;
    await _ref
        .read(pendingAlertStoreProvider)
        .save(
          PendingAlert(
            placeId: place.id,
            placeName: place.name,
            direction: direction,
            soundEnabled: place.soundEnabled,
            occurredAt: DateTime.now().toUtc(),
            sound: place.sound,
            vibrationPattern: place.vibrationPattern,
            latitude: place.latitude,
            longitude: place.longitude,
            radiusMeters: place.radiusMeters,
          ),
        );
    Diagnostics.log(
      'devtools',
      'test alert queued place=${place.name} direction=${direction.name} '
          'sound=${place.soundEnabled}',
    );
    return DevTestAlertResult.queued;
  }

  /// 전면광고 불러오기 > 바로 보기. 빈도 제한·등급과 무관 (테스트 광고 단위)
  Future<bool> showInterstitialNow() async {
    final service = _ref.read(interstitialAdServiceProvider);
    await service.preload();
    final isShown = await service.showIfReady();
    Diagnostics.log('devtools', 'interstitial shown=$isShown');
    return isShown;
  }

  Future<void> resetAdHistory() async {
    final store = await _ref.read(adFrequencyStoreProvider.future);
    await store.resetShownHistory();
    Diagnostics.log('devtools', 'ad history reset');
  }

  Future<void> resetReviewRecords() =>
      _ref.read(reviewPromptCoordinatorProvider).resetForDevTools();

  Future<bool> requestReviewNow() =>
      _ref.read(reviewPromptCoordinatorProvider).requestNowForDevTools();

  /// 신뢰성 권한 안내 기록 삭제 — 호출 뒤 온보딩으로 보내면 처음처럼 다시 권함
  Future<void> resetOnboardingPrompt() async {
    await _ref.read(reliabilityPromptProvider.notifier).reset();
    Diagnostics.log('devtools', 'onboarding prompt reset');
  }

  Future<void> resyncGeofences() async {
    await _ref.read(geofenceRegistrationSyncProvider).refresh();
    Diagnostics.log('devtools', 'geofence resync requested');
  }

  Future<CloudSyncOutcome> syncCloudNow() =>
      _ref.read(cloudSyncCoordinatorProvider).runNow(reason: 'dev_tools');

  /// 개발자 도구 머리 정보 + 앱 상태 보고서 전체 (복사용)
  Future<String> collectStateReport() async {
    final report = await _ref.read(appStateReporterProvider).collect();
    return '${buildStatusLines().join('\n')}\n\n$report';
  }

  /// 빌드 상태 줄: 빌드 종류, 버전, DEV_FLAG, 광고 단위, 프로 표시·저장 출처
  List<String> buildStatusLines() {
    final access = _ref.read(featureAccessControllerProvider.notifier);
    return [
      'flavor=${AppBuildFlavor.label}',
      'build=${BuildInfo.label}',
      'dev_flag=${DevFlag.isDevBuild}',
      'ads=${AdUnitIds.usingTestIds ? "test" : "live"}',
      'pro_shown=${_ref.read(featureAccessControllerProvider).source.storageValue}',
      'pro_stored=${access.storedSource.storageValue}',
      'pro_override=${access.devOverrideSource?.storageValue ?? "off"}',
    ];
  }
}

@riverpod
DevToolsActions devToolsActions(Ref ref) => DevToolsActions(ref);
