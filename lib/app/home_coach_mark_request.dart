import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'home_coach_mark_request.g.dart';

/// 홈 코치마크 요청 번호: 0 요청 없음, 1 이상 보여 달라는 요청 (첫 실행 · 설정에서 다시 보기)
///
/// 본 여부는 SharedPreferences 에 저장한다. 홈 화면은 번호가 커질 때마다 한 번 보여 준다.
@Riverpod(keepAlive: true)
class HomeCoachMarkRequest extends _$HomeCoachMarkRequest {
  // 홈 코치마크를 이미 봤는가 (1:봄)
  static const _keyHasSeen = 'home_coach_mark.has_seen';

  @override
  Future<int> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_keyHasSeen) ?? false) ? 0 : 1;
  }

  /// 끝까지 봤거나 건너뜀 > 다시 자동으로 띄우지 않는다
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeen, true);
  }

  /// 설정의 "사용법 다시 보기"
  void replay() => state = AsyncData((state.valueOrNull ?? 0) + 1);
}
