import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/build_info.dart';
import '../core/config/dev_flag.dart';
import '../core/diagnostics/diagnostics.dart';
import '../features/ads/domain/ad_unit_ids.dart';
import '../core/theme/app_theme.dart';
import '../features/ads/presentation/ads_providers.dart';
import '../features/alert/data/alert_notifier_impl.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import 'background/background_alert_notifier.dart';
import 'geofence_providers.dart';
import 'pending_alert_resumer.dart';
import 'router.dart';
import 'splash_overlay.dart';

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

    // 빌드 성격을 먼저 확정한다 (이슈 #109) — 광고 종류와 인앱 업데이트
    // 표시 여부가 여기에 달려 있다
    await DevFlag.init();
    // 어느 빌드에서 난 문제인지 로그만으로 알 수 있어야 한다 (이슈 #127)
    await BuildInfo.init();
    Diagnostics.log(
      'app',
      '앱 시작 ${BuildInfo.label} devBuild=${DevFlag.isDevBuild} '
          '광고=${AdUnitIds.usingTestIds ? "테스트" : "실제"}',
    );

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
      await _deleteLegacyAlertChannel();
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

    await _resumePendingAlert('시작');
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
      unawaited(_resumePendingAlert('resumed'));
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
      (_) => unawaited(_resumePendingAlert('폴링')),
    );
  }

  void _stopPendingAlertPoll() {
    _pendingAlertPoll?.cancel();
    _pendingAlertPoll = null;
  }

  /// 대기 알림 승격 (이슈 #63 · #74 · #83 · #130).
  ///
  /// 판단은 [PendingAlertResumer] 가 한다 — 부트스트랩·`resumed`·폴링이
  /// 겹쳐 들어오는 경합을 테스트로 지키려고 꺼냈다 (이슈 #142 QA).
  /// 앱 수명 동안 하나만 둬야 겹침을 막을 수 있다.
  late final _resumer = PendingAlertResumer(
    takeRequest: () => ref.read(pendingAlertLauncherProvider).takeRequest(),
    hasPending: () => ref.read(pendingAlertLauncherProvider).hasPending(),
    watch: ref.read(alertWatchServiceProvider),
    cancelNotification: _cancelBackgroundNotification,
    promote: (request) async {
      await ref.read(activeAlertProvider.notifier).fire(request);
      // 해제 시점에 광고가 준비되어 있게 미리 불러둔다
      unawaited(_preloadAd());
      _router.go(AppRoutes.alert);
    },
  );

  Future<void> _resumePendingAlert(String trigger) =>
      _resumer.resume(trigger: trigger);

  /// 헤드업을 띄우던 옛 세션 채널을 지운다 (이슈 #142 QA).
  ///
  /// 채널 중요도는 만든 뒤 바꿀 수 없어 새 채널로 옮겼다. 지우지 않으면
  /// 기존 설치의 알림 설정에 쓰이지 않는 항목이 남아 사용자를 헷갈리게 한다
  Future<void> _deleteLegacyAlertChannel() async {
    try {
      await ref
          .read(notificationsPluginProvider)
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.deleteNotificationChannel(AlertNotifierImpl.legacyChannelId);
    } on Object catch (error) {
      // 남아도 동작에는 지장이 없다 — 기록만 남긴다
      Diagnostics.log('app', '옛 알림 채널 삭제 실패 $error');
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
      // 네이티브 스플래시가 걷히는 순간을 잇는다 (이슈 #150).
      // `builder` 에 두는 것은 라우터보다 위에 깔려야 화면 전환과
      // 무관하게 한 장으로 걷히기 때문이다.
      builder: (context, child) =>
          SplashOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
