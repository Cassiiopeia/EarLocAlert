import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 프로가 열린 출처 (#294)
enum ProEntitlementSource {
  /// 무료
  none('none'),

  /// Play 일회성 상품 `pro_unlock` 구매
  purchase('purchase'),

  /// 업데이트 전부터 쓰던 기기에 준 혜택
  legacyUser('legacy_user');

  const ProEntitlementSource(this.storageValue);

  final String storageValue;

  bool get isPro => this != none;

  /// 저장값 > 출처. 모르는 값은 무료
  static ProEntitlementSource fromStorage(String? value) => values.firstWhere(
    (source) => source.storageValue == value,
    orElse: () => none,
  );
}

/// 디버그 빌드 강제 출처: `--dart-define=PRO_DEBUG_SOURCE=purchase|legacy_user|none`
/// 릴리스 빌드·미지정이면 null. 지정되면 Play 조회로 덮어쓰지 않음 (에뮬레이터 확인용)
ProEntitlementSource? debugProSourceOverride() {
  const value = String.fromEnvironment('PRO_DEBUG_SOURCE');
  if (!kDebugMode || value.isEmpty) return null;
  return ProEntitlementSource.fromStorage(value);
}

/// 프로 상태 저장소: 출처, 기존 사용자 판정 완료 여부 (SharedPreferences)
class ProEntitlementStore {
  const ProEntitlementStore();

  // prefs: 프로 출처 (none / purchase / legacy_user)
  static const String _sourceKey = 'pro_entitlement_source';

  // prefs: 기존 사용자 판정을 이미 했는지 (true 면 다시 판정하지 않음)
  static const String _legacyCheckDoneKey = 'pro_legacy_check_done';

  Future<ProEntitlementSource> read() async {
    final prefs = await SharedPreferences.getInstance();
    return ProEntitlementSource.fromStorage(prefs.getString(_sourceKey));
  }

  Future<void> write(ProEntitlementSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceKey, source.storageValue);
  }

  Future<bool> isLegacyCheckDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_legacyCheckDoneKey) ?? false;
  }

  Future<void> markLegacyCheckDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legacyCheckDoneKey, true);
  }
}
