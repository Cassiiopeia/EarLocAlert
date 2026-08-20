import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/theme/app_theme.dart';
import '../features/ads/presentation/ads_providers.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import 'background/background_alert_notifier.dart';
import 'geofence_providers.dart';
import 'router.dart';

/// 앱 루트 (docs/02-ARCHITECTURE.md)
class EarLocAlertApp extends ConsumerStatefulWidget {
  const EarLocAlertApp({super.key});

  @override
  ConsumerState<EarLocAlertApp> createState() => _EarLocAlertAppState();
}

class _EarLocAlertAppState extends ConsumerState<EarLocAlertApp>
    with WidgetsBindingObserver {
  // 라우터는 앱 수명 동안 하나만 존재해야 한다 —
  // build 마다 새로 만들면 화면 전환 이력이 초기화된다.
  late final _router = createRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 프레임 뒤에 시작한다 — 부트스트랩이 첫 화면을 늦추면 안 된다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  /// 앱이 떠 있는 동안 대기 알림을 확인하는 타이머 (이슈 #74).
  ///
  /// 지오펜스 이벤트는 앱이 포그라운드일 때도 **백그라운드 isolate** 로
  /// 온다. 그 isolate 는 PendingAlert 를 저장하고 죽는데, 앱이 이미 떠
  /// 있으면 `resumed` 생명주기가 오지 않아 아무도 그것을 꺼내지 않는다 —
  /// 지도를 보며 도착한 사용자가 알림을 통째로 놓치는 경로다.
  Timer? _pendingAlertPoll;

  /// 도착 판정은 몇 초 단위로 다투는 일이 아니다. 화면이 떠 있는 동안만
  /// 도는 타이머라 이 간격이면 체감 지연이 없다.
  static const _pollInterval = Duration(seconds: 3);

  @override
  void dispose() {
    _pendingAlertPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 백그라운드 감시 시동 (이슈 #63).
  ///
  /// 실패해도 앱은 뜬다 — 권한 미허용 상태의 첫 실행에서도 온보딩으로
  /// 진행할 수 있어야 한다. 동기화는 장소 목록이 바뀔 때마다 재시도된다.
  Future<void> _bootstrap() async {
    // 로깅을 가장 먼저 켠다 (이슈 #95) — 아래 단계들이 실패하는 것 자체가
    // 추적 대상이다. 백그라운드 엔진과 같은 파일에 쌓이므로 한 화면에서
    // 시간순으로 읽힌다.
    await Diagnostics.init();
    Diagnostics.log('app', '앱 시작');

    try {
      // 알림 탭으로 앱이 열리는 경로에 필요하다. 권한 요청은 온보딩이
      // 담당하므로 여기서는 요청하지 않는다.
      await ref
          .read(notificationsPluginProvider)
          .initialize(
            const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
          );
      Diagnostics.log('app', '알림 플러그인 초기화 완료');
    } on Object catch (error) {
      // 초기화 실패는 알림 탭 라우팅만 잃는다 — 감시는 계속 시도한다
      Diagnostics.log('app', '알림 플러그인 초기화 실패 $error');
    }
    try {
      await ref.read(geofenceRegistrationSyncProvider).start();
      Diagnostics.log('app', '지오펜스 동기화 시동 완료');
    } on Object catch (error) {
      // 권한 미허용 등 — 다음 장소 변경 때 재시도된다
      Diagnostics.log('app', '지오펜스 동기화 시동 실패 $error');
    }
    // 지난 세션이 남긴 알림을 먼저 치운다 (이슈 #84).
    //
    // 백그라운드 알림은 스와이프로 지워지지 않게 걸려 있어, 아무도 지우지
    // 않으면 영영 남는다. 앱이 새로 뜨는 시점의 알림은 정의상 지난 것이고,
    // 지금 살아 있는 알림이라면 바로 아래 승격이 화면으로 이어준다.
    await _cancelBackgroundNotification();

    await _resumePendingAlert();
    // 첫 실행에는 resumed 생명주기 콜백이 오지 않는다 — 여기서 건다
    _startPendingAlertPoll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 언제 앞으로 나오고 언제 내려갔는지가 "그때 왜 안 울렸나"의
    // 기준선이다 (이슈 #106)
    Diagnostics.log('app', '생명주기 ${state.name}');

    // 백그라운드 알림 뒤 앱을 열면(탭이든 직접이든) 풀 세션으로 잇는다
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumePendingAlert());
      _startPendingAlertPoll();
    } else {
      _stopPendingAlertPoll();
    }
  }

  void _startPendingAlertPoll() {
    // 화면이 이미 정리됐으면 타이머를 만들지 않는다 — 남으면 dispose 가
    // 지나간 뒤에 도는 타이머가 된다
    if (!mounted || _pendingAlertPoll != null) return;
    _pendingAlertPoll = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_resumePendingAlert()),
    );
  }

  void _stopPendingAlertPoll() {
    _pendingAlertPoll?.cancel();
    _pendingAlertPoll = null;
  }

  Future<void> _resumePendingAlert() async {
    try {
      final (:request, :hadPending) = await ref
          .read(pendingAlertLauncherProvider)
          .takeRequest();

      // 네이티브가 돌리던 반복 진동을 먼저 끊는다 (이슈 #74).
      // **fire() 보다 반드시 먼저다** — 뒤집히면 네이티브 취소가 Dart 진동을
      // 같이 끄거나, 둘이 겹쳐 패턴이 어긋난다.
      //
      // **승격하지 못하는 경우에도 끊는다** (이슈 #83). 만료·손상이라
      // 화면을 띄우지 못해도 네이티브는 그 알림으로 계속 울리고 있다.
      // 예전에는 여기서 그냥 return 해버려, 진동은 10분 내내 이어지는데
      // 앱을 열어도 끌 화면이 없었다 — 강제종료 말고는 방법이 없었다.
      if (hadPending) {
        Diagnostics.log(
          'app',
          '대기 알림 발견 승격=${request != null} '
              'place=${request?.placeName ?? "만료·손상"}',
        );
        await ref.read(alertWatchServiceProvider).stopNativeAlert();
        // 백그라운드 알림은 스와이프로 지워지지 않게 걸어두었다 (이슈 #84).
        // 지우는 책임이 여기 있다 — 안 지우면 영영 남는 알림이 된다.
        await _cancelBackgroundNotification();
      }
      if (request == null) return;

      Diagnostics.log('app', '알림 세션 승격 place=${request.placeName}');
      await ref.read(activeAlertProvider.notifier).fire(request);
      // 해제 시점에 광고가 준비되어 있게 미리 불러둔다
      unawaited(_preloadAd());
      _router.go(AppRoutes.alert);
    } on Object catch (error) {
      // 알림 승격 실패가 앱 시작을 막으면 안 된다
      Diagnostics.log('app', '알림 승격 실패 $error');
    }
  }

  /// 백그라운드가 띄운 알림을 지운다 (이슈 #84).
  ///
  /// 실패해도 흐름을 막지 않는다 — 알림이 남는 것보다 해제가 늦어지는
  /// 쪽이 훨씬 나쁘다 (docs/02-ARCHITECTURE.md 규칙 4와 같은 이유).
  Future<void> _cancelBackgroundNotification() async {
    try {
      await ref
          .read(notificationsPluginProvider)
          .cancel(BackgroundAlertNotifier.notificationId);
    } on Object {
      // 알림이 남는 것은 불편이지 고장이 아니다
    }
  }

  Future<void> _preloadAd() async {
    try {
      final coordinator = await ref.read(alertAdCoordinatorProvider.future);
      await coordinator.onAlertFired();
    } on Object {
      // 광고는 부가 기능이다 (docs/02-ARCHITECTURE.md 규칙 4)
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EarLocAlert',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
