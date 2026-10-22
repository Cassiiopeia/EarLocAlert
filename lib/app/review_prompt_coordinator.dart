import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/review/data/review_prompt_store.dart';
import '../features/review/data/store_review_service.dart';
import '../features/review/domain/review_prompt_policy.dart';

part 'review_prompt_coordinator.g.dart';

/// 스토어 후기 창 조율 (#296): 알림 해제 횟수 기록 > 앱이 앞으로 올 때 판정 > 요청
/// 알림 화면·해제 직후(전면광고 자리)에는 요청하지 않음 — 다음에 앱을 열 때만
class ReviewPromptCoordinator {
  ReviewPromptCoordinator({
    ReviewPromptStore store = const ReviewPromptStore(),
    StoreReviewService service = const StoreReviewService(),
    required bool Function() isAlertActive,
    DateTime Function()? now,
  }) : _store = store,
       _service = service,
       _isAlertActive = isAlertActive,
       _now = now ?? (() => DateTime.now().toUtc());

  final ReviewPromptStore _store;
  final StoreReviewService _service;
  final bool Function() _isAlertActive;
  final DateTime Function() _now;

  /// 같은 실행에서 판정은 한 번만 (앞으로 올 때마다 스토어를 부르지 않게)
  bool _hasCheckedThisRun = false;

  /// 알림을 정상적으로 껐을 때
  Future<void> recordAlertDismissed() async {
    try {
      final count = await _store.incrementDismissCount();
      Diagnostics.log('review', 'alert dismiss recorded count=$count');
    } on Object catch (error) {
      Diagnostics.log('review', 'dismiss record failed error=$error');
    }
  }

  /// 앱이 앞으로 왔을 때: 판정 > 조건 맞으면 요청 > 요청 시각 기록
  Future<void> onAppForeground() async {
    if (_hasCheckedThisRun) return;
    if (_isAlertActive()) {
      Diagnostics.log('review', 'check skipped reason=alert_active');
      return;
    }
    _hasCheckedThisRun = true;
    try {
      final now = _now();
      final decision = ReviewPromptPolicy.decide(
        alertDismissCount: await _store.readDismissCount(),
        firstUsedAt: await _store.readOrInitFirstUsedAt(now),
        lastRequestedAt: await _store.readLastRequestedAt(),
        now: now,
      );
      Diagnostics.log('review', 'check decision=${decision.logToken}');
      if (decision != ReviewPromptDecision.request) return;
      if (await _service.request()) await _store.writeLastRequestedAt(now);
    } on Object catch (error) {
      Diagnostics.log('review', 'check failed error=$error');
    }
  }
}

@Riverpod(keepAlive: true)
ReviewPromptCoordinator reviewPromptCoordinator(Ref ref) =>
    ReviewPromptCoordinator(
      isAlertActive: () => ref.read(activeAlertProvider) != null,
    );
