import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/providers.dart';

part 'reliability_prompt_provider.g.dart';

/// 알림 신뢰성 권한을 이미 권했는가 (이슈 #74)
///
/// 온보딩이 이 값을 봐서 같은 화면을 반복해서 보이지 않는다.
@riverpod
class ReliabilityPrompt extends _$ReliabilityPrompt {
  @override
  Future<bool> build() => ref.watch(reliabilityPromptStoreProvider).wasSeen();

  /// 권했다는 사실을 남긴다. 허용됐든 건너뛰었든 한 번이면 충분하다.
  Future<void> markSeen() async {
    await ref.read(reliabilityPromptStoreProvider).markSeen();
    state = const AsyncData(true);
  }

  /// 다시 권할 수 있게 되돌린다 — 사용자가 홈에서 직접 찾아온 경우.
  Future<void> reset() async {
    await ref.read(reliabilityPromptStoreProvider).reset();
    state = const AsyncData(false);
  }
}
