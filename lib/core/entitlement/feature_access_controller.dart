import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_build_flavor.dart';
import '../diagnostics/diagnostics.dart';
import 'feature_access.dart';
import 'pro_entitlement.dart';

part 'feature_access_controller.g.dart';

/// 앱 시작 전에 읽은 값을 main 이 덮어쓴다 — 첫 프레임부터 등급대로 그린다
@Riverpod(keepAlive: true)
ProEntitlementSource proEntitlementInitial(Ref ref) =>
    ProEntitlementSource.none;

@Riverpod(keepAlive: true)
ProEntitlementStore proEntitlementStore(Ref ref) => const ProEntitlementStore();

/// 무료/프로 기능 접근 상태 (#294). 바뀌면 바로 반영하고 저장
/// 화면 상태 = 개발자 도구 강제값 ?? 저장 출처 (#359). 저장·스토어 조회는 항상 저장 출처 기준
@Riverpod(keepAlive: true)
class FeatureAccessController extends _$FeatureAccessController {
  /// 저장 출처 (구매·환불 판정 기준). 강제값이 있어도 그대로 유지
  late ProEntitlementSource _storedSource;

  /// 개발자 도구 강제값 (메모리, 앱을 다시 켜면 꺼짐). null 이면 저장 출처를 따름
  ProEntitlementSource? _devOverrideSource;

  ProEntitlementSource get storedSource => _storedSource;

  ProEntitlementSource? get devOverrideSource => _devOverrideSource;

  @override
  FeatureAccess build() {
    _storedSource = ref.watch(proEntitlementInitialProvider);
    return _accessFor(_storedSource);
  }

  /// 출처 변경 > 저장 > 기록. 같은 값이면 아무것도 하지 않음
  Future<void> setSource(
    ProEntitlementSource next, {
    required String reason,
  }) async {
    final previous = _storedSource;
    if (previous == next) return;
    _storedSource = next;
    state = _accessFor(next);
    Diagnostics.log(
      'pro',
      'entitlement changed from=${previous.storageValue} '
          'to=${next.storageValue} reason=$reason',
    );
    try {
      await ref.read(proEntitlementStoreProvider).write(next);
    } on Object catch (error) {
      // 저장 실패 시 다음 실행에서 이전 값으로 시작 — 시작 시 Play 조회가 다시 맞춘다
      Diagnostics.log('pro', 'entitlement save failed error=$error');
    }
  }

  /// 개발자 도구 강제값 적용 (저장하지 않음). 개발 빌드가 아니면 무시
  void setDevOverrideSource(ProEntitlementSource? source) {
    if (!AppBuildFlavor.canUseDevTools) return;
    _devOverrideSource = source;
    state = _accessFor(_storedSource);
    Diagnostics.log(
      'devtools',
      'pro override set=${source?.storageValue ?? "off"} '
          'stored=${_storedSource.storageValue}',
    );
  }

  FeatureAccess _accessFor(ProEntitlementSource stored) => FeatureAccess(
    // 결제가 있는 플랫폼만 무료 제한을 건다: Android Play (#294), iOS App Store (#298)
    isPaywallEnabled: Platform.isAndroid || Platform.isIOS,
    source: _devOverrideSource ?? stored,
  );
}
