import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';
import '../features/review/data/review_prompt_store.dart';

part 'alert_dismiss_count_provider.g.dart';

/// 알림 해제 누적 횟수 (스토어 후기 판정과 같은 기록, #366 홈 안내 문구용). 읽기 실패 > 0
@riverpod
Future<int> alertDismissCount(Ref ref) async {
  try {
    return await const ReviewPromptStore().readDismissCount();
  } on Object catch (error) {
    Diagnostics.log('pro', 'dismiss count read failed error=$error');
    return 0;
  }
}
