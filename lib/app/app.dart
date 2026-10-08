import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/build_info.dart';
import '../core/config/dev_flag.dart';
import '../core/diagnostics/diagnostics.dart';
import '../core/domain/alert_direction.dart';
import '../core/l10n/app_language_controller.dart';
import '../core/l10n/l10n.dart';
import '../core/l10n/locale_resolver.dart';
import '../features/ads/domain/ad_unit_ids.dart';
import '../core/theme/app_theme.dart';
import '../features/ads/domain/ad_consent.dart';
import '../features/ads/presentation/ads_providers.dart';
import '../features/alert/data/alert_notifier_impl.dart';
import '../features/alert/domain/alert_controller.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
import '../features/app_update/domain/app_updater.dart';
import '../features/app_update/presentation/app_update_providers.dart';
import '../core/platform/notification_actions.dart';
import '../features/permission/presentation/ios_notification_settings_provider.dart';
import 'arrival_alarm_providers.dart';
import 'background/background_alert_notifier.dart';
import 'background/notification_action_handler.dart';
import 'background/pending_alert.dart';
import 'background/pending_alert_store.dart';
import 'background_alert_ringer.dart';
import 'geofence_providers.dart';
import 'notification_dismiss_action.dart';
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

  /// 앱 내 업데이트 안내(이슈 #170)를 화면 위치와 무관하게 띄우는 데 쓴다
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // iOS 적응형 감시는 첫 프레임을 기다리지 않는다 (이슈 #231) — 위치 사유로
    // 백그라운드에서 다시 뜨면 프레임이 오지 않아 아래 부트스트랩이 돌지 않는다
    if (Platform.isIOS) unawaited(_attachIosWatch());
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

  /// 화면이 떠 있을 때 결정된 iOS 감시 알림 (이슈 #231)
  StreamSubscription<void>? _iosAlerts;

  /// 화면 없이 결정된 iOS 감시 알림과, 그 세션의 끝 (이슈 #233)
  StreamSubscription<PendingAlert>? _iosBackgroundAlerts;
  StreamSubscription<Object?>? _sessionEnds;

  /// 화면 없이 결정된 알림을 바로 울린다 (이슈 #233, 결정 055).
  ///
  /// 승격([_resumer])과 같은 세션 경로를 탄다 — 대기 알림을 꺼내 쓰므로 앱을 열 때
  /// 승격이 같은 알림으로 두 번째 세션을 만들지 않는다.
  late final _backgroundRinger = BackgroundAlertRinger(
    takeRequest: () async =>
        (await ref.read(pendingAlertLauncherProvider).takeRequest()).request,
    startSession: (request) async {
      final session = await ref
          .read(activeAlertProvider.notifier)
          .fire(request);
      if (session == null) return false;
      unawaited(_preloadAd());
      // 화면이 없어도 경로를 먼저 바꿔 둔다 — 앱을 열면 이 세션의 알림 화면이다
      _router.go(AppRoutes.alert);
      // 잠금 화면 전체를 덮는 무음 알람 (이슈 #235, iOS 26+) — 기다리지 않는다.
      // 못 띄워도 알림·진동은 이미 나가고 있다
      unawaited(_presentArrivalAlarm(request));
      return true;
    },
    audioDecision: () => ref.read(activeAlertProvider.notifier).audioDecision(),
    remind: (alert, sequence) => BackgroundAlertNotifier(
      plugin: ref.read(notificationsPluginProvider),
      store: PendingAlertStore(),
    ).remind(alert, sequence: sequence),
    clearNotifications: _cancelBackgroundNotification,
    isRinging: () => ref.read(alertControllerProvider).current != null,
  );

  /// 알림의 "알림 끄기" 버튼 (이슈 #237). 알림 화면의 해제와 같은 세션 해제를 쓰고
  /// 광고는 붙이지 않는다 (CLAUDE.md 규칙 1·3)
  late final _notificationDismiss = NotificationDismissAction(
    isRinging: () => ref.read(alertControllerProvider).current != null,
    dismissSession: () => ref.read(activeAlertProvider.notifier).dismiss(),
    stopReminders: _backgroundRinger.onSessionEnded,
    stopAlarms: () =>
        ref.read(arrivalAlarmPlatformProvider).stopAll('notification_action'),
    clearPending: () async {
      await ref.read(pendingAlertLauncherProvider).takeRequest();
    },
    clearNotifications: () async {
      await _cancelBackgroundNotification();
      try {
        await ref
            .read(notificationsPluginProvider)
            .cancel(AlertNotifierImpl.notificationId);
      } on Object {
        // 알림이 남는 것은 불편이지 고장이 아니다
      }
    },
  );

  /// 헤드리스 엔진이 넘겨준 버튼 눌림을 받는다 (이슈 #237)
  late final _notificationActions = NotificationActionReceiver(
    onDismiss: (place) => _notificationDismiss.run(place: place),
  );

  /// 앱 엔진으로 바로 온 알림 응답 (이슈 #237).
  ///
  /// "알림 끄기" 는 앱을 띄우지 않는 버튼이라 보통 헤드리스 엔진으로 가지만, 같은
  /// 응답이 이쪽으로 와도 같은 처리를 한다. 알림 본문 탭은 여기서 다루지 않는다 —
  /// 앱이 전면으로 오면 `resumed` 의 승격이 알림 화면으로 잇는다.
  void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId != NotificationActions.dismiss) return;
    unawaited(_notificationDismiss.run(place: response.payload ?? 'unknown'));
  }

  /// 적응형 감시의 측정 처리기와 영역 이벤트 수신기를 단다 (이슈 #231).
  ///
  /// 로깅을 여기서 먼저 켠다 — 백그라운드 재실행에서는 부트스트랩이 돌지 않아
  /// 그쪽 초기화를 기다리면 판정 기록이 전부 버려진다.
  Future<void> _attachIosWatch() async {
    await Diagnostics.init();
    try {
      final watch = ref.read(iosAdaptiveWatchProvider);
      _iosAlerts = watch.foregroundAlerts.listen(
        (_) => unawaited(_resumePendingAlert('ios_watch')),
      );
      _iosBackgroundAlerts = watch.backgroundAlerts.listen(
        (alert) => unawaited(_backgroundRinger.ring(alert)),
      );
      // 잠금 화면 알람의 "사용자가 껐다" 신호를 받기 시작한다 (이슈 #235)
      final alarm = ref.read(arrivalAlarmCoordinatorProvider);
      // 어디서 해제하든 반복 알림과 잠금 화면 알람이 같이 멈춰야 한다 — 끈 뒤에
      // 떨거나 알람이 남으면 안 된다
      // 알림 버튼 눌림을 받기 시작한다 (이슈 #237) — 화면 없이 울리는 동안 눌리므로
      // 첫 프레임을 기다리지 않는다
      _notificationActions.attach();
      _sessionEnds = ref.read(alertControllerProvider).sessionChanges.listen((
        session,
      ) {
        if (session != null) return;
        unawaited(_backgroundRinger.onSessionEnded());
        unawaited(alarm.onSessionEnded());
      });
      await watch.attach();
    } on Object catch (error) {
      // 적응형 감시를 못 붙여도 영역 감시는 돈다
      Diagnostics.log('app', 'ios watch attach failed $error');
    }
  }

  @override
  void dispose() {
    unawaited(_iosAlerts?.cancel());
    unawaited(_iosBackgroundAlerts?.cancel());
    unawaited(_sessionEnds?.cancel());
    _notificationActions.detach();
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
      'app start ${BuildInfo.label} devBuild=${DevFlag.isDevBuild} '
          'ads=${AdUnitIds.usingTestIds ? "test" : "live"}',
    );

    try {
      // 알림 탭으로 앱이 열리는 경로에 필요하다. 권한 요청은 온보딩이
      // 담당하므로 여기서는 요청하지 않는다.
      //
      // 백그라운드 경로와 같은 설정을 쓴다 — 알림 버튼 카테고리가 여기 들어 있다 (이슈 #237)
      await ref
          .read(notificationsPluginProvider)
          .initialize(
            await loadNotificationInitSettings(),
            onDidReceiveNotificationResponse: _onNotificationResponse,
            onDidReceiveBackgroundNotificationResponse:
                onBackgroundNotificationResponse,
          );
      Diagnostics.log('app', 'notification plugin initialized');
      await _deleteLegacyAlertChannel();
    } on Object catch (error) {
      // 초기화 실패는 알림 탭 라우팅만 잃는다 — 감시는 계속 시도한다
      Diagnostics.log('app', 'notification plugin init failed $error');
    }
    try {
      await ref.read(geofenceRegistrationSyncProvider).start();
      Diagnostics.log('app', 'geofence sync started');
    } on Object catch (error) {
      // 권한 미허용 등 — 다음 장소 변경 때 재시도된다
      Diagnostics.log('app', 'geofence sync start failed $error');
    }
    // 지난 세션이 남긴 알림을 먼저 치운다 (이슈 #84).
    //
    // 백그라운드 알림은 스와이프로 지워지지 않게 걸려 있어, 아무도 지우지
    // 않으면 영영 남는다. 앱이 새로 뜨는 시점의 알림은 정의상 지난 것이고,
    // 지금 살아 있는 알림이라면 바로 아래 승격이 화면으로 이어준다.
    await _cancelBackgroundNotification();
    // 화면 없이 시작한 세션의 반복 알림도 여기서 멈춘다 (이슈 #233) — 첫 실행에는
    // resumed 가 오지 않는다
    await _backgroundRinger.onForeground();
    // 알림 화면이 뜨므로 잠금 화면 알람과 겹치지 않게 끈다 (이슈 #235)
    if (Platform.isIOS) {
      await ref.read(arrivalAlarmCoordinatorProvider).onForeground();
    }

    await _resumePendingAlert('start');
    // 광고 동의 (이슈 #166) — 알림이 울리는 중이 아닐 때만, 기다리지 않고 받는다
    unawaited(_gatherAdConsent());
    unawaited(_checkAppUpdate());
    // 첫 실행에는 resumed 생명주기 콜백이 오지 않는다 — 여기서 건다
    _startPendingAlertPoll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 언제 앞으로 나오고 언제 내려갔는지가 "그때 왜 안 울렸나"의
    // 기준선이다 (이슈 #106)
    Diagnostics.log('app', 'lifecycle ${state.name}');

    // 백그라운드 알림 뒤 앱을 열면(탭이든 직접이든) 풀 세션으로 잇는다
    if (state == AppLifecycleState.resumed) {
      // 화면 없이 울리던 세션이면 알림 화면이 반복 알림을 대신한다 (이슈 #233)
      unawaited(_backgroundRinger.onForeground());
      // 앱 화면과 잠금 화면 알람이 함께 뜨지 않게 한다 (이슈 #235)
      if (Platform.isIOS) {
        unawaited(ref.read(arrivalAlarmCoordinatorProvider).onForeground());
        // 설정 앱에서 알림·잠금 화면·알람을 바꾸고 왔을 수 있다 — 홈 경고를 다시
        // 계산한다 (이슈 #237)
        ref
          ..invalidate(iosNotificationSettingsProvider)
          ..invalidate(arrivalAlarmStatusProvider);
      }
      unawaited(_resumePendingAlert('resumed'));
      unawaited(_checkAppUpdate());
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
      (_) => unawaited(_resumePendingAlert('poll')),
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
      Diagnostics.log(
        'app',
        'legacy notification channel delete failed $error',
      );
    }
  }

  /// 백그라운드가 띄운 알림을 지운다 (이슈 #84).
  ///
  /// 반복 알림이 번갈아 쓰는 id 까지 지운다 (이슈 #233).
  ///
  /// 실패해도 흐름을 막지 않는다 — 알림이 남는 것보다 해제가 늦어지는
  /// 쪽이 훨씬 나쁘다 (docs/02-ARCHITECTURE.md 규칙 4와 같은 이유).
  Future<void> _cancelBackgroundNotification() async {
    for (final id in BackgroundAlertNotifier.notificationIds) {
      try {
        await ref.read(notificationsPluginProvider).cancel(id);
      } on Object {
        // 알림이 남는 것은 불편이지 고장이 아니다
      }
    }
  }

  /// 유럽 경제 지역과 영국 사용자의 광고 동의를 받는다 (이슈 #166).
  ///
  /// **알림 화면 위에 동의 화면을 겹치지 않는다** — 울리는 중이면 건너뛰고 다음
  /// 실행 때 받는다. 실패해도 흐름을 막지 않는다 (docs/02-ARCHITECTURE.md 규칙 4).
  Future<void> _gatherAdConsent() async {
    try {
      await AdConsentGate(ref.read(adConsentProvider)).gatherWhenIdle(
        alertActive: () => ref.read(activeAlertProvider) != null,
      );
    } on Object catch (error) {
      Diagnostics.log('ads', 'consent gathering failed $error');
    }
  }

  /// 앱 내 업데이트 (이슈 #170) — 알림이 울리는 중이 아닐 때만, 기다리지 않고 받는다.
  ///
  /// Play 밖에서 설치한 빌드는 확인이 실패하는데 정상이다. 실패해도 흐름을 막지
  /// 않는다 (docs/02-ARCHITECTURE.md 규칙 4).
  Future<void> _checkAppUpdate() async {
    try {
      final gate = ref.read(appUpdateGateProvider);
      final outcome = await gate.checkWhenIdle(
        alertActive: () => ref.read(activeAlertProvider) != null,
      );
      if (outcome != AppUpdateOutcome.downloaded || !mounted) return;
      // 화면 문자열 접근은 MaterialApp 위라 컨텍스트가 없다 — 알림과 같은 경로로 찾는다
      final locale = resolveAppLocale(
        ref.read(appLanguageControllerProvider),
        WidgetsBinding.instance.platformDispatcher.locales,
      );
      final strings = AppStrings.forLocale(locale);
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(strings.appUpdateReady),
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: strings.appUpdateRestart,
            onPressed: () => unawaited(gate.install()),
          ),
        ),
      );
    } on Object catch (error) {
      Diagnostics.log('update', 'check flow failed $error');
    }
  }

  /// 화면 없이 시작한 세션에 잠금 화면 알람을 붙인다 (이슈 #235).
  ///
  /// 문구는 앱 언어로 만들어 넘긴다 — 네이티브는 받은 문자열을 그대로 보여준다.
  /// 화면 문맥이 없으므로 [AppStrings] 로 찾는다 (CLAUDE.md 규칙 6).
  Future<void> _presentArrivalAlarm(AlertRequest request) async {
    try {
      final strings = AppStrings.forLocale(
        resolveAppLocale(
          ref.read(appLanguageControllerProvider),
          WidgetsBinding.instance.platformDispatcher.locales,
        ),
      );
      final event = request.direction == AlertDirection.enter
          ? strings.alertScreenArrived
          : strings.alertScreenLeft;
      await ref
          .read(arrivalAlarmCoordinatorProvider)
          .present(
            placeName: request.placeName,
            title: '${request.placeName} · $event',
            stopLabel: strings.alertScreenDismiss,
          );
    } on Object catch (error) {
      Diagnostics.log('alarm', 'present flow failed error=$error');
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
    // 사용자가 고른 언어가 기기 언어보다 우선한다. `system` 이면 기기 언어를
    // 따르고, 지원하지 않는 언어이면 영어다 (이슈 #163)
    final language = ref.watch(appLanguageControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      locale: language.locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (deviceLocales, supported) =>
          resolveAppLocale(language, deviceLocales ?? const []),
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      scaffoldMessengerKey: _messengerKey,
      // 네이티브 스플래시가 걷히는 순간을 잇는다 (이슈 #150).
      // `builder` 에 두는 것은 라우터보다 위에 깔려야 화면 전환과
      // 무관하게 한 장으로 걷히기 때문이다.
      builder: (context, child) =>
          SplashOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
