import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_build_flavor.dart';
import '../../core/l10n/l10n.dart';
import '../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../core/ui/components/floating_circle_button.dart';
import '../../core/ui/foundation/app_color_palette.dart';
import '../../core/ui/foundation/app_spacing.dart';
import '../../features/alert/presentation/alert_controller_provider.dart';
import '../router.dart';
import 'dev_tools_sheet.dart';

/// 개발자 도구 진입점 (#359): 앱 위에 끌어 옮기는 원형 버튼 > 개발자 도구 시트
/// 숨김 조건 3개: 개발 빌드 아님(위젯 자체 없음), 알림 화면·알림 중, 시트 열림
class DevToolsOverlay extends ConsumerStatefulWidget {
  const DevToolsOverlay({required this.router, required this.child, super.key});

  final GoRouter router;
  final Widget child;

  /// 개발 빌드면 감싸고 아니면 그대로 (컴파일 상수라 스토어 빌드에서는 이 위젯 코드가 빠짐)
  static Widget wrap({required GoRouter router, required Widget child}) =>
      AppBuildFlavor.canUseDevTools
      ? DevToolsOverlay(router: router, child: child)
      : child;

  @override
  ConsumerState<DevToolsOverlay> createState() => _DevToolsOverlayState();
}

class _DevToolsOverlayState extends ConsumerState<DevToolsOverlay> {
  // 버튼 기본 위치: 왼쪽 끝, 화면 높이 45% (화면 비율 0~1)
  // 오른쪽 아래는 홈의 장소 추가 버튼·내 위치 버튼 자리라 피함
  static const _defaultPositionRatio = Offset(0, 0.45);

  /// 끌어 옮긴 위치 (화면 비율 0~1)
  Offset _positionRatio = _defaultPositionRatio;
  bool _isSheetOpen = false;
  bool _isOnAlertRoute = false;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    final isOnAlertRoute = path == AppRoutes.alert;
    if (isOnAlertRoute != _isOnAlertRoute) {
      setState(() => _isOnAlertRoute = isOnAlertRoute);
    }
  }

  Future<void> _openSheet() async {
    // 시트는 라우터 Navigator 위에 띄움 (이 위젯은 Navigator 바깥)
    final navigatorContext =
        widget.router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    setState(() => _isSheetOpen = true);
    await showAppBottomSheet<void>(
      navigatorContext,
      builder: (_) => DevToolsSheet(router: widget.router),
    );
    if (mounted) setState(() => _isSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    // 알림 화면에서는 숨김 — 해제 버튼 근처를 가리면 안 됨 (CLAUDE.md 규칙 3 과 같은 이유)
    final isAlertActive = ref.watch(activeAlertProvider) != null;
    final isButtonVisible = !_isSheetOpen && !_isOnAlertRoute && !isAlertActive;
    // Positioned 는 Stack 바로 아래여야 해서 크기는 바깥 LayoutBuilder 에서 읽음
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          widget.child,
          if (isButtonVisible)
            _buildDraggableButton(context, constraints.biggest),
        ],
      ),
    );
  }

  Widget _buildDraggableButton(BuildContext context, Size screenSize) {
    const buttonSize = AppControlSize.floating;
    final padding = MediaQuery.paddingOf(context);
    // 안전 영역 안으로 위치 제한 (좌상단 기준 좌표)
    final minLeft = padding.left + AppSpacing.xs;
    final maxLeft =
        screenSize.width - padding.right - buttonSize - AppSpacing.xs;
    final minTop = padding.top + AppSpacing.xs;
    final maxTop =
        screenSize.height - padding.bottom - buttonSize - AppSpacing.xs;
    final left = (minLeft + (maxLeft - minLeft) * _positionRatio.dx).clamp(
      minLeft,
      maxLeft,
    );
    final top = (minTop + (maxTop - minTop) * _positionRatio.dy).clamp(
      minTop,
      maxTop,
    );
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          _positionRatio = Offset(
            ((left + details.delta.dx - minLeft) / (maxLeft - minLeft)).clamp(
              0,
              1,
            ),
            ((top + details.delta.dy - minTop) / (maxTop - minTop)).clamp(0, 1),
          );
        }),
        child: FloatingCircleButton(
          icon: Icons.build_outlined,
          semanticLabel: context.l10n.devToolsOpen,
          background: context.appColors.warning,
          foreground: context.appColors.onWarning,
          onPressed: () => unawaited(_openSheet()),
        ),
      ),
    );
  }
}
