import '../core/diagnostics/diagnostics.dart';
import '../features/alert/domain/alert_controller.dart';
import 'background/alert_watch_service.dart';

/// 대기 알림을 풀 세션으로 잇는 한 번의 시도 (이슈 #63 · #74 · #83 · #130)
///
/// 앱 루트가 **세 곳에서** 부른다 — 부트스트랩, `resumed` 생명주기, 앱이
/// 떠 있는 동안의 3초 폴링. 원래 위젯 상태 안에 있던 로직을 꺼낸 것은
/// 두 경합을 테스트로 지키기 위해서다 (이슈 #142 QA).
///
/// 1. **겹쳐 들어오면 한 번만 돈다.** 네이티브가 화면을 앞으로 올리면
///    `resumed` 와 폴링이 거의 동시에 들어와, 같은 대기 알림을 둘 다
///    꺼내 세션이 두 번 시작됐다 (복원 두 줄이 58ms 차이).
/// 2. **고아로 판정하기 직전에 대기 알림을 다시 본다.** 폴링이 "없음"을
///    읽은 뒤 네이티브 확인을 기다리는 사이에 새 알림이 도착하면, 방금
///    울리기 시작한 알림을 "재시작 뒤 남은 고아"로 오인해 꺼버렸다.
class PendingAlertResumer {
  PendingAlertResumer({
    required Future<({AlertRequest? request, bool hadPending})> Function()
    takeRequest,
    required Future<bool> Function() hasPending,
    required AlertWatchService watch,
    required Future<void> Function() cancelNotification,
    required Future<void> Function(AlertRequest request) promote,
  }) : _takeRequest = takeRequest,
       _hasPending = hasPending,
       _watch = watch,
       _cancelNotification = cancelNotification,
       _promote = promote;

  final Future<({AlertRequest? request, bool hadPending})> Function()
  _takeRequest;
  final Future<bool> Function() _hasPending;
  final AlertWatchService _watch;
  final Future<void> Function() _cancelNotification;
  final Future<void> Function(AlertRequest request) _promote;

  /// 지금 돌고 있는 시도. 겹쳐 부르면 이것을 같이 기다린다
  Future<void>? _running;

  /// 한 번 시도한다. 이미 돌고 있으면 그 결과를 같이 기다린다.
  Future<void> resume({required String trigger}) {
    final running = _running;
    if (running != null) {
      Diagnostics.log('app', '대기 알림 확인 겹침 — 진행 중인 것을 기다린다 (호출=$trigger)');
      return running;
    }
    final attempt = _resumeOnce().whenComplete(() => _running = null);
    _running = attempt;
    return attempt;
  }

  Future<void> _resumeOnce({bool retried = false}) async {
    try {
      final (:request, :hadPending) = await _takeRequest();

      // 네이티브가 돌리던 반복 진동을 먼저 끊는다 (이슈 #74).
      // **promote 보다 반드시 먼저다** — 뒤집히면 네이티브 취소가 Dart
      // 진동을 같이 끄거나, 둘이 겹쳐 패턴이 어긋난다.
      //
      // **승격하지 못하는 경우에도 끊는다** (이슈 #83). 만료·손상이라
      // 화면을 띄우지 못해도 네이티브는 그 알림으로 계속 울리고 있다.
      if (hadPending) {
        Diagnostics.log(
          'app',
          '대기 알림 발견 승격=${request != null} '
              'place=${request?.placeName ?? "만료·손상"}',
        );
        await _watch.stopNativeAlert();
        // 백그라운드 알림은 스와이프로 지워지지 않게 걸어두었다 (이슈 #84)
        await _cancelNotification();
      }
      if (request == null) {
        // 앱이 죽었다 살아난 경우 (이슈 #130) — 첫 승격 때 소비했으므로
        // hadPending 이 false 인데 감시 서비스는 계속 울리고 있을 수 있다
        if (!hadPending && await _stopOrphanedAlert() && !retried) {
          // 방금 도착한 알림이다 — 다음 폴링(최대 3초)을 기다리지 않고
          // 바로 다시 꺼낸다. 한 번만 — 무한히 돌지 않게 막는다
          await _resumeOnce(retried: true);
        }
        return;
      }

      Diagnostics.log('app', '알림 세션 승격 place=${request.placeName}');
      await _promote(request);
    } on Object catch (error) {
      // 알림 승격 실패가 앱 시작을 막으면 안 된다
      Diagnostics.log('app', '알림 승격 실패 $error');
    }
  }

  /// 세션 없이 혼자 울고 있는 알림을 정리한다 (이슈 #130).
  ///
  /// **확인에 실패하면 아무것도 하지 않는다** — 울리지 않는데 정리하는
  /// 것은 무해하지만, 반대로 틀리면 멀쩡한 알림을 꺼버린다.
  ///
  /// 정리하지 않고 넘긴 이유가 **방금 도착한 대기 알림**이면 true 다.
  Future<bool> _stopOrphanedAlert() async {
    if (!await _watch.isAlerting()) return false;

    // **울리는 것을 확인한 뒤에 대기 알림을 다시 본다.** 네이티브는 저장한
    // 다음에 울리므로, 지금 울리는 알림의 짝이 있다면 여기서 보인다.
    // 있으면 고아가 아니라 방금 도착한 알림이다
    if (await _hasPending()) {
      Diagnostics.log('app', '울리는 알림의 대기 값이 방금 도착했다 — 정리하지 않고 승격한다');
      return true;
    }

    Diagnostics.log('app', '세션 없이 울리는 알림 발견 — 정리한다 (앱이 재시작된 것으로 보인다)');
    await _watch.stopNativeAlert();
    await _cancelNotification();
    return false;
  }
}
