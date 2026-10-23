import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../features/alert/domain/ios_vibration_check_state.dart';
import '../../features/alert/presentation/vibration_check_provider.dart';
import '../../features/permission/data/ios_notification_settings_provider.dart';
import '../../features/permission/domain/ios_notification_settings.dart';
import '../../features/permission/presentation/permission_controller.dart';
import 'vibration_test_notification_channel.dart';

part 'ios_vibration_check_controller.g.dart';

/// iOS 진동 점검 흐름: 설정 자동 확인 > 시험 알림 > 결과 > 단계 안내 (이슈 #301)
///
/// alert(답 저장)·permission(알림 설정 읽기·설정 열기)을 함께 써서 app 계층에 둔다.
/// 시트가 닫히면 함께 사라진다 — 타이머·생명주기 구독도 그때 정리.
@riverpod
class IosVibrationCheckController extends _$IosVibrationCheckController {
  static const _channel = VibrationTestNotificationChannel();

  /// 알림 시각 뒤 화면 잠금 여부를 판정할 여유 (OS 전달 지연 흡수)
  static const _fireGraceMilliseconds = 1500;

  Timer? _dueCheckTimer;
  AppLifecycleListener? _lifecycleListener;
  DateTime? _notificationDueAt;
  bool _wasAppHiddenSinceScheduled = false;
  bool _isDisposed = false;

  @override
  IosVibrationCheckState build() {
    _lifecycleListener = AppLifecycleListener(
      onHide: _onAppHidden,
      onResume: _onAppResumed,
    );
    ref.onDispose(() {
      _isDisposed = true;
      _dueCheckTimer?.cancel();
      _lifecycleListener?.dispose();
      // 시트를 닫으면 예약·표시 중인 시험 알림을 거둔다 — 닫은 뒤 떨면 놀란다 (없으면 무시)
      if (_notificationDueAt != null) unawaited(_channel.cancel());
      Diagnostics.log('vibration', 'check closed');
    });
    Diagnostics.log('vibration', 'check opened');
    // 첫 프레임 뒤 읽기 — build 안에서 state 를 바꾸지 않는다
    Future.microtask(_refreshBlockers);
    return IosVibrationCheckState.initial;
  }

  /// 설정 > 알림 > 이 앱 (꺼진 항목 켜러 가기). 돌아오면 [_onAppResumed] 가 다시 읽는다
  Future<void> openNotificationSettings() async {
    final opened = await _channel.openNotificationSettings();
    Diagnostics.log(
      'vibration',
      'open notification settings opened=$opened blockers=${_blockerNames()}',
    );
  }

  /// 설정 > 이 앱 (햅틱·손쉬운 사용·집중 모드는 바로 가는 공개 경로가 없다)
  Future<void> openAppSettings() async {
    Diagnostics.log('vibration', 'open app settings step=${state.step.name}');
    await ref.read(permissionControllerProvider.notifier).openSettings();
  }

  /// 시험 알림 예약 > 잠금 대기. 문구는 화면이 현재 언어로 넘긴다
  Future<void> sendTestNotification({
    required String title,
    required String body,
  }) async {
    final isScheduled = await _channel.schedule(
      title: title,
      body: body,
      delaySeconds: testNotificationDelaySeconds,
    );
    if (_isDisposed) return;
    Diagnostics.log(
      'vibration',
      'test notification sent scheduled=$isScheduled attempt=${state.attempt + 1}',
    );
    if (!isScheduled) {
      state = state.copyWith(
        step: IosVibrationCheckStep.readiness,
        isScheduleFailed: true,
      );
      return;
    }

    _notificationDueAt = DateTime.now().add(
      const Duration(seconds: testNotificationDelaySeconds),
    );
    _wasAppHiddenSinceScheduled = false;
    _dueCheckTimer?.cancel();
    _dueCheckTimer = Timer(
      const Duration(
        seconds: testNotificationDelaySeconds,
        milliseconds: _fireGraceMilliseconds,
      ),
      _onNotificationDue,
    );
    state = state.copyWith(
      step: IosVibrationCheckStep.waitingForLock,
      isScheduleFailed: false,
      attempt: state.attempt + 1,
    );
  }

  /// 대기 취소 > 처음 화면
  Future<void> cancelWaiting() async {
    _dueCheckTimer?.cancel();
    await _channel.cancel();
    Diagnostics.log('vibration', 'test notification cancelled by user');
    _goTo(IosVibrationCheckStep.readiness);
  }

  /// 느꼈어요 > 답 저장(홈 경고 해제) > 끝
  Future<void> answerFelt() async {
    await ref.read(vibrationCheckProvider.notifier).answer(felt: true);
    _goTo(IosVibrationCheckStep.succeeded);
  }

  /// 못 느꼈어요 > 답 저장(홈 경고 유지) > 안내 1/3
  Future<void> answerNotFelt() async {
    await ref.read(vibrationCheckProvider.notifier).answer(felt: false);
    _goTo(IosVibrationCheckStep.guideHaptics);
  }

  /// 알림이 안 왔어요 > 읽을 수 있는 설정부터 다시 확인. 다 켜져 있으면 집중 모드 안내
  Future<void> answerNoNotification() async {
    Diagnostics.log('vibration', 'test answered no_notification');
    final blockers = await _readBlockers();
    if (_isDisposed) return;
    state = state.copyWith(blockers: blockers, hasReadSettings: true);
    _goTo(
      blockers.isEmpty
          ? IosVibrationCheckStep.guideFocusMode
          : IosVibrationCheckStep.readiness,
    );
  }

  /// 안내 다음 단계 (햅틱 > 손쉬운 사용 > 집중 모드)
  void goToNextGuideStep() {
    _goTo(switch (state.step) {
      IosVibrationCheckStep.guideHaptics =>
        IosVibrationCheckStep.guideAccessibilityVibration,
      IosVibrationCheckStep.guideAccessibilityVibration =>
        IosVibrationCheckStep.guideFocusMode,
      _ => IosVibrationCheckStep.readiness,
    });
  }

  /// 다시 시험 > 처음 화면 (설정을 다시 읽고 버튼을 누르게 한다)
  Future<void> restart() async {
    _goTo(IosVibrationCheckStep.readiness);
    await _refreshBlockers();
  }

  /// 안내를 다 해도 안 됨
  void giveUp() => _goTo(IosVibrationCheckStep.stillNotVibrating);

  void _goTo(IosVibrationCheckStep next) {
    if (_isDisposed || state.step == next) return;
    Diagnostics.log(
      'vibration',
      'check step ${state.step.name} -> ${next.name}',
    );
    state = state.copyWith(step: next);
  }

  /// 알림 시각이 지났는데 한 번도 앱을 벗어나지 않음 > 시험 무효
  void _onNotificationDue() {
    if (_isDisposed || state.step != IosVibrationCheckStep.waitingForLock) {
      return;
    }
    if (_wasAppHiddenSinceScheduled) return;
    unawaited(_channel.cancel());
    Diagnostics.log('vibration', 'test invalid reason=screen_not_locked');
    _goTo(IosVibrationCheckStep.screenNotLocked);
  }

  void _onAppHidden() {
    if (state.step == IosVibrationCheckStep.waitingForLock) {
      _wasAppHiddenSinceScheduled = true;
      Diagnostics.log('vibration', 'test app hidden while waiting');
    }
  }

  /// 앱 복귀: 대기 중이면 결과 묻기(너무 일찍 오면 무효), 처음 화면이면 설정 다시 읽기
  void _onAppResumed() {
    switch (state.step) {
      case IosVibrationCheckStep.waitingForLock:
        if (!_wasAppHiddenSinceScheduled) return;
        final dueAt = _notificationDueAt;
        final isBeforeDue = dueAt != null && DateTime.now().isBefore(dueAt);
        if (isBeforeDue) {
          // 알림 전에 돌아옴 > 앱이 켜진 채 알림이 와 실제 도착과 달라진다
          _dueCheckTimer?.cancel();
          unawaited(_channel.cancel());
          Diagnostics.log('vibration', 'test invalid reason=returned_early');
          _goTo(IosVibrationCheckStep.screenNotLocked);
        } else {
          _dueCheckTimer?.cancel();
          _goTo(IosVibrationCheckStep.askingResult);
        }
      case IosVibrationCheckStep.readiness:
        unawaited(_refreshBlockers());
      default:
        break;
    }
  }

  Future<void> _refreshBlockers() async {
    final blockers = await _readBlockers();
    if (_isDisposed) return;
    state = state.copyWith(blockers: blockers, hasReadSettings: true);
  }

  /// 알림 설정 다시 읽기 > 진동을 막는 항목만 고름 (모르는 값은 막힌 것으로 보지 않음)
  Future<Set<VibrationCheckBlocker>> _readBlockers() async {
    // 설정 앱에서 방금 바꿨을 수 있다 — 홈 경고도 같은 값을 다시 읽게 함께 무효화
    ref.invalidate(iosNotificationSettingsProvider);
    final IosNotificationSettings? settings;
    try {
      settings = await ref.read(iosNotificationSettingsProvider.future);
    } on Object catch (error) {
      Diagnostics.log('vibration', 'check settings read failed error=$error');
      return const {};
    }
    if (settings == null) return const {};
    final blockers = {
      if (settings.isBlocked) VibrationCheckBlocker.notificationsNotAllowed,
      if (settings.lockScreen == IosNotificationSetting.disabled)
        VibrationCheckBlocker.lockScreenHidden,
      if (settings.sound == IosNotificationSetting.disabled)
        VibrationCheckBlocker.notificationSoundOff,
    };
    Diagnostics.log(
      'vibration',
      'check settings read auth=${settings.authorization.name} '
          'lock_screen=${settings.lockScreen.name} sound=${settings.sound.name} '
          'blockers=[${blockers.map((blocker) => blocker.name).join(",")}]',
    );
    return blockers;
  }

  String _blockerNames() =>
      '[${state.blockers.map((blocker) => blocker.name).join(",")}]';
}
