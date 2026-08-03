import 'package:freezed_annotation/freezed_annotation.dart';

part 'ad_frequency_store.freezed.dart';

/// 빈도 판정에 필요한 상태 (docs/07-MONETIZATION.md)
@freezed
abstract class AdFrequencyState with _$AdFrequencyState {
  const factory AdFrequencyState({
    /// 마지막 전면광고 노출 시각 (UTC). 없으면 아직 노출한 적 없다
    DateTime? lastShownAt,

    /// 오늘 노출 횟수
    @Default(0) int shownToday,

    /// 앱을 처음 실행했는가 — 첫인상을 광고로 만들지 않는다
    @Default(true) bool isFirstLaunch,
  }) = _AdFrequencyState;
}

/// 광고 노출 이력 저장소 (docs/03-DOMAIN.md 저장소 경계)
///
/// **앱을 껐다 켜도 유지되어야 한다.** 메모리에만 두면 앱을 재시작할 때마다
/// 카운터가 초기화되어 빈도 제한이 무력화된다 — 곧 정책 위반이다.
abstract interface class AdFrequencyStore {
  Future<AdFrequencyState> read();

  /// 광고를 노출한 사실을 기록한다.
  ///
  /// [now] 를 주입받는 이유는 일자 경계를 테스트하기 위해서다 —
  /// 내부에서 `DateTime.now()` 를 부르면 검증이 불가능해진다.
  Future<void> recordShown(DateTime now);

  /// 최초 실행 표시를 해제한다. 온보딩 완료 시점에 호출한다
  Future<void> markLaunched();
}
