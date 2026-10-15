import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../diagnostics/diagnostics.dart';
import 'app_theme_preference.dart';

part 'app_theme_controller.g.dart';

/// 앱 시작 전에 읽은 값을 main 이 덮어쓴다 — 첫 프레임부터 고른 모드로 그린다
@Riverpod(keepAlive: true)
AppThemePreference appThemeInitial(Ref ref) => AppThemePreference.system;

@Riverpod(keepAlive: true)
AppThemeStore appThemeStore(Ref ref) => const AppThemeStore();

/// 화면 모드 (이슈 #272). 고르면 바로 적용하고 저장한다
@Riverpod(keepAlive: true)
class AppThemeController extends _$AppThemeController {
  @override
  AppThemePreference build() => ref.watch(appThemeInitialProvider);

  Future<void> select(AppThemePreference next) async {
    final previous = state;
    if (previous == next) return;
    state = next;
    Diagnostics.log(
      'settings',
      'theme mode changed from=${previous.storageValue} to=${next.storageValue}',
    );
    try {
      await ref.read(appThemeStoreProvider).write(next);
    } on Object catch (error) {
      // 저장 실패는 다음 실행에서 이전 값으로 돌아가는 것으로 끝난다
      Diagnostics.log('settings', 'theme mode save failed error=$error');
    }
  }
}
