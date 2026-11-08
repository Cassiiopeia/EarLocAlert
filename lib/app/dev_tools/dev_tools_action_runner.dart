import 'package:flutter/widgets.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/l10n/l10n.dart';
import '../../core/ui/feedback/app_feedback.dart';

/// 동작 실행 > 결과 토스트. 실패는 삼키고 기록 (개발자 도구가 앱을 멈추면 안 됨)
Future<void> runDevToolsAction<T>(
  BuildContext context,
  Future<T> Function() action, {
  String Function(T result)? messageFor,
}) async {
  final l10n = context.l10n;
  try {
    final result = await action();
    if (!context.mounted) return;
    context.showToast(messageFor?.call(result) ?? l10n.devToolsDone);
  } on Object catch (error) {
    Diagnostics.log('devtools', 'action failed error=$error');
    if (context.mounted) context.showToast(l10n.devToolsFailed('$error'));
  }
}
