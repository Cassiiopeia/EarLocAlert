import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 프로가 열린 출처 (#294)
enum ProEntitlementSource {
  /// 무료
  none('none'),

  /// Play 일회성 상품 `pro_unlock` 구매 (프로모션 코드로 받은 것 포함)
  purchase('purchase');

  const ProEntitlementSource(this.storageValue);

  final String storageValue;

  bool get isPro => this != none;

  /// 저장값 > 출처. 모르는 값은 무료 (예전 기존 사용자 혜택 `legacy_user` 도 무료 — 결정 072)
  static ProEntitlementSource fromStorage(String? value) => values.firstWhere(
    (source) => source.storageValue == value,
    orElse: () => none,
  );
}

/// 디버그 빌드 강제 출처: `--dart-define=PRO_DEBUG_SOURCE=purchase|none`
/// 릴리스 빌드·미지정이면 null. 지정되면 Play 조회로 덮어쓰지 않음 (에뮬레이터 확인용)
ProEntitlementSource? debugProSourceOverride() {
  const value = String.fromEnvironment('PRO_DEBUG_SOURCE');
  if (!kDebugMode || value.isEmpty) return null;
  return ProEntitlementSource.fromStorage(value);
}

/// 프로 상태 저장소: 출처 (SharedPreferences)
class ProEntitlementStore {
  const ProEntitlementStore();

  // prefs: 프로 출처 (none / purchase)
  static const String _sourceKey = 'pro_entitlement_source';

  Future<ProEntitlementSource> read() async {
    final prefs = await SharedPreferences.getInstance();
    return ProEntitlementSource.fromStorage(prefs.getString(_sourceKey));
  }

  Future<void> write(ProEntitlementSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceKey, source.storageValue);
  }
}
