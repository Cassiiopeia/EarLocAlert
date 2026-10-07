import 'geofence_target.dart';
import 'position_sample.dart';
import 'proximity_radius.dart';

/// iOS 적응형 감시의 정확도 단계 (이슈 #231)
///
/// **멀리 있을수록 싸게 본다.** 항상 GPS 를 켜면 내비게이션 앱처럼 배터리를
/// 먹고, 영역 감시(region monitoring)만 쓰면 이벤트가 늦거나 오지 않는다
/// (실기기에서 300m 장소의 콜백이 한 번도 오지 않았다). 그래서 가장 가까운
/// 장소의 근접 원까지 남은 거리로 단계를 고른다.
///
/// 네이티브가 단계별 설정(정확도·distanceFilter)을 적용하고, **고르는 것은
/// 여기 한 곳이다** — 규칙이 Swift 와 Dart 에 나뉘면 반드시 어긋난다.
enum WatchTier {
  /// 근접 원에서 멀다 — km 급 정확도, 500m 마다 갱신
  far,

  /// 근접 원에 다가가는 중 — 100m 급 정확도, 100m 마다 갱신
  mid,

  /// 근접 원 안 — 10m 급 정확도, 10m 마다 갱신. 이 단계의 측정이 판정에 들어간다
  precise,
}

/// 가장 가까운 활성 장소의 근접 원 경계까지 남은 거리 (미터).
///
/// 음수면 이미 근접 원 안이다. 활성 장소가 없으면 null.
/// 근접 원은 Android 정밀 감시와 같은 규칙([proximityRadiusMeters])을 쓴다 —
/// 플랫폼마다 "가깝다"의 기준이 다르면 같은 장소가 다르게 울린다.
double? nearestRingGapMeters(
  PositionSample fix,
  Iterable<GeofenceTarget> targets,
) {
  double? nearest;
  for (final target in targets) {
    if (!target.enabled) continue;
    final gap =
        fix.distanceToMeters(target.latitude, target.longitude) -
        proximityRadiusMeters(target.radiusMeters);
    if (nearest == null || gap < nearest) nearest = gap;
  }
  return nearest;
}

/// 단계 선택 정책 (이슈 #231)
///
/// 상태를 가진다 — 히스테리시스와 정밀 단계 체류 시간을 기억해야 하기
/// 때문이다. 시계는 측정의 시각을 쓴다 — 테스트가 시간을 조작할 수 있다.
///
/// 규칙:
/// 1. **정확도만큼 가깝게 본다.** km 급 측정은 1km 틀릴 수 있으므로 남은
///    거리에서 정확도를 뺀 값으로 판단한다 — 늦게 올리는 것보다 일찍
///    올리는 쪽이 싸다.
/// 2. **내릴 때는 여유를 둔다** (히스테리시스). 경계에서 측정이 흔들릴 때
///    단계가 오락가락하면 설정 변경만으로 전력을 먹는다.
/// 3. **정밀 단계는 30분이 상한이다** — Android 정밀 감시와 같은 값
///    (결정 024). 근접 원 안에 머무는 사람(집 근처 장소)에게 GPS 를 계속
///    켜 두지 않는다. 상한에 걸리면 근접 원을 벗어났다 다시 들어올 때까지
///    중간 단계로 둔다 — 중간 단계 측정도 판정에는 들어간다.
class WatchTierPolicy {
  WatchTierPolicy({
    this.midEnterMeters = 3000,
    this.hysteresisMeters = 300,
    this.preciseExitMeters = 150,
    this.preciseCap = const Duration(minutes: 30),
    WatchTier initial = WatchTier.mid,
  }) : _tier = initial;

  /// 근접 원까지 이보다 가까우면 중간 단계
  final double midEnterMeters;

  /// 중간 → 먼 단계로 내릴 때 더 멀어져야 하는 거리
  final double hysteresisMeters;

  /// 정밀 → 중간으로 내릴 때 근접 원 밖으로 벗어나야 하는 거리
  final double preciseExitMeters;

  /// 정밀 단계 체류 상한
  final Duration preciseCap;

  WatchTier _tier;
  DateTime? _preciseSince;

  /// 상한에 걸려 정밀을 쉬는 중인가. 근접 원을 벗어나면 풀린다
  bool _capped = false;

  WatchTier get tier => _tier;

  /// 정밀 상한에 걸려 쉬는 중인가 — 로그 사유로 쓴다
  bool get preciseCapped => _capped;

  /// 측정 하나로 다음 단계를 정한다. [gapMeters] 는 [nearestRingGapMeters].
  WatchTier next({
    required double? gapMeters,
    required double accuracyMeters,
    required DateTime at,
  }) {
    // 감시할 장소가 없다 — 가장 싸게 둔다 (호출부가 대개 감시를 끈다)
    if (gapMeters == null) {
      _capped = false;
      return _set(WatchTier.far, at);
    }

    // 규칙 1 — 정확도만큼 가깝게 본다. 음수 정확도는 "모름"이라 0 으로 본다
    final gap = gapMeters - (accuracyMeters > 0 ? accuracyMeters : 0);

    // 근접 원을 확실히 벗어나면 상한을 푼다 — 다음 진입은 다시 정밀로 본다
    if (gap > preciseExitMeters) _capped = false;

    final WatchTier wanted;
    if (gap <= 0) {
      wanted = WatchTier.precise;
    } else if (_tier == WatchTier.precise && gap <= preciseExitMeters) {
      // 규칙 2 — 근접 원 경계에서 흔들리는 동안은 정밀을 유지한다
      wanted = WatchTier.precise;
    } else if (gap <= midEnterMeters) {
      wanted = WatchTier.mid;
    } else if (_tier != WatchTier.far &&
        gap <= midEnterMeters + hysteresisMeters) {
      wanted = WatchTier.mid;
    } else {
      wanted = WatchTier.far;
    }

    // 규칙 3 — 정밀 상한
    if (wanted == WatchTier.precise) {
      if (_capped) return _set(WatchTier.mid, at);
      // 정밀로 시작한 경우(복원) 첫 측정부터 잰다
      if (_tier == WatchTier.precise) _preciseSince ??= at;
      final since = _preciseSince;
      if (_tier == WatchTier.precise &&
          since != null &&
          at.difference(since) >= preciseCap) {
        _capped = true;
        return _set(WatchTier.mid, at);
      }
    }
    return _set(wanted, at);
  }

  WatchTier _set(WatchTier tier, DateTime at) {
    if (tier == WatchTier.precise && _tier != WatchTier.precise) {
      _preciseSince = at;
    } else if (tier != WatchTier.precise) {
      _preciseSince = null;
    }
    _tier = tier;
    return tier;
  }
}
