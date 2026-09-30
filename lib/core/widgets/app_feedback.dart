import 'package:flutter/material.dart';

import '../text/keep_all.dart';

/// 화면 하단에 문구만 띄우는 스낵바 (되돌리기 같은 액션이 있으면 직접 만든다)
extension AppToast on BuildContext {
  void showToast(String message) {
    ScaffoldMessenger.of(
      this,
    ).showSnackBar(SnackBar(content: Text(keepAllText(message))));
  }
}

/// 취소/확인 두 개짜리 확인 창. **확인이면 `true`, 그 밖(취소·바깥 탭)은 `false`.**
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
  TextStyle? bodyStyle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(dialogContext.keepAllText(body), style: bodyStyle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
