import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../data/prefs_vibration_check_store.dart';
import '../domain/vibration_check.dart';
import '../domain/vibration_intensity.dart';
import 'alert_controller_provider.dart';

part 'vibration_check_provider.g.dart';

@Riverpod(keepAlive: true)
VibrationCheckStore vibrationCheckStore(Ref ref) => PrefsVibrationCheckStore();

/// 진동 시험 (이슈 #237)
///
/// 마지막 답을 들고 있다 — 홈 경고와 설정 화면이 이 값을 본다. "아니요"였다면
/// 다음 시험에서 "예"라고 답할 때까지 경고가 남는다.
@Riverpod(keepAlive: true)
class VibrationCheck extends _$VibrationCheck {
  @override
  Future<VibrationCheckResult?> build() async {
    try {
      return await ref.watch(vibrationCheckStoreProvider).last();
    } on Object catch (error) {
      // 못 읽으면 "시험 안 함"으로 본다 — 모르는 상태로 경고를 띄우지 않는다
      Diagnostics.log('vibration', 'test answer read failed error=$error');
      return null;
    }
  }

  /// 도착 알림과 같은 진동을 한 번 울린다.
  ///
  /// 알림 세션이 쓰는 [vibrationServiceProvider] 를 그대로 쓴다 — 다른 경로로 떨면
  /// "시험은 됐는데 알림은 안 떤다"가 생긴다. 세기도 저장된 값을 따른다.
  Future<void> fire({required String trigger}) async {
    final vibration = ref.read(vibrationServiceProvider);
    var intensity = VibrationIntensity.normal;
    try {
      intensity = await ref.read(vibrationIntensityStoreProvider).intensity();
    } on Object {
      // 세기를 못 읽으면 기본 세기로 떤다 — 시험 자체를 포기하지 않는다
    }
    Diagnostics.log(
      'vibration',
      'test fired trigger=$trigger intensity=${intensity.name}',
    );
    try {
      // 한 번만 느끼면 된다 — 반복 주기를 길게 주고 곧바로 멈춘다 (세기 시트와 같은 방식)
      await vibration.startRepeating(
        interval: const Duration(days: 1),
        intensity: intensity,
      );
      await Future<void>.delayed(
        Duration(milliseconds: intensity.pulseMs + 120),
      );
      await vibration.stop();
    } on Object catch (error) {
      // 못 떨었다는 사실 자체가 단서다 — 답은 그대로 받는다
      Diagnostics.log('vibration', 'test fire failed error=$error');
    }
  }

  /// 사용자의 답을 저장한다. 저장이 실패해도 화면 상태는 바뀐 답을 따른다
  Future<void> answer({required bool felt}) async {
    final result = VibrationCheckResult(
      felt: felt,
      answeredAt: DateTime.now().toUtc(),
    );
    Diagnostics.log('vibration', 'test answered felt=$felt');
    state = AsyncData(result);
    try {
      await ref.read(vibrationCheckStoreProvider).save(result);
    } on Object catch (error) {
      Diagnostics.log('vibration', 'test answer save failed error=$error');
    }
  }
}
