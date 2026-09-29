import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../diagnostics/diagnostics.dart';
import 'app_language.dart';
import 'app_language_store.dart';

part 'app_language_controller.g.dart';

/// 앱을 띄울 때 읽어 둔 언어 설정 (이슈 #163)
///
/// `main()` 이 `runApp` 전에 저장소에서 읽어 이 provider 를 덮어쓴다.
/// **비동기로 읽으면 첫 프레임이 기기 언어로 그려졌다가 바뀌는 깜빡임이 생긴다.**
@Riverpod(keepAlive: true)
AppLanguage appLanguageInitial(Ref ref) => AppLanguage.system;

@Riverpod(keepAlive: true)
AppLanguageStore appLanguageStore(Ref ref) => const AppLanguageStore();

/// 현재 앱 언어 설정. 설정 화면이 바꾸고 `MaterialApp` 이 읽는다.
@Riverpod(keepAlive: true)
class AppLanguageController extends _$AppLanguageController {
  @override
  AppLanguage build() => ref.watch(appLanguageInitialProvider);

  /// 언어를 바꾼다. **즉시 적용**되고 저장된다 — 앱을 다시 켜지 않아도 된다.
  Future<void> select(AppLanguage next) async {
    final previous = state;
    if (previous == next) return;
    state = next;
    Diagnostics.log(
      'l10n',
      'app language changed from=${previous.storageValue} to=${next.storageValue}',
    );
    try {
      await ref.read(appLanguageStoreProvider).write(next);
    } on Object catch (error) {
      // 저장이 실패해도 이번 실행에서는 바뀐 언어로 보인다. 다음 실행에서
      // 되돌아갈 뿐이다 — 기록은 남긴다
      Diagnostics.log('l10n', 'app language save failed $error');
    }
  }
}
