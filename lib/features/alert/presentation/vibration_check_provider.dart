import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../data/vibration_check_store_provider.dart';
import '../domain/vibration_check.dart';

part 'vibration_check_provider.g.dart';

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

  /// 사용자의 답을 저장한다. 저장이 실패해도 화면 상태는 바뀐 답을 따른다
  Future<void> answer({required bool felt}) async {
    // 첫 읽기가 끝나기 전에 답을 넣으면 뒤늦게 끝난 읽기(null)가 답을 덮을 수 있다 (온보딩 직후 홈 경고)
    try {
      await future;
    } on Object {
      // 읽기 실패는 build 가 이미 기록 — 답 저장은 계속
    }
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
