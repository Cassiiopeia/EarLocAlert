import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/ads/presentation/ads_providers.dart';
import '../features/alert/presentation/alert_controller_provider.dart';
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 백그라운드 감시 시동 (이슈 #63).
  ///
  /// 실패해도 앱은 뜬다 — 권한 미허용 상태의 첫 실행에서도 온보딩으로
  /// 진행할 수 있어야 한다. 동기화는 장소 목록이 바뀔 때마다 재시도된다.
  Future<void> _bootstrap() async {
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
    } on Object {
      // 초기화 실패는 알림 탭 라우팅만 잃는다 — 감시는 계속 시도한다
    }
    try {
      await ref.read(geofenceRegistrationSyncProvider).start();
    } on Object {
      // 권한 미허용 등 — 다음 장소 변경 때 재시도된다
    }
    await _resumePendingAlert();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 알림 뒤 앱을 열면(탭이든 직접이든) 풀 세션으로 잇는다
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumePendingAlert());
    }
  }

  Future<void> _resumePendingAlert() async {
    try {
      final request = await ref
          .read(pendingAlertLauncherProvider)
          .takeRequest();
      if (request == null) return;

      await ref.read(activeAlertProvider.notifier).fire(request);
      // 해제 시점에 광고가 준비되어 있게 미리 불러둔다
      unawaited(_preloadAd());
      _router.go(AppRoutes.alert);
    } on Object {
      // 알림 승격 실패가 앱 시작을 막으면 안 된다
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
