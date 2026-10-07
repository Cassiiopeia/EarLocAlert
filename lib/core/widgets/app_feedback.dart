import 'package:flutter/material.dart';

import '../text/keep_all.dart';

/// 화면 하단에 문구만 띄우는 스낵바 (되돌리기 같은 액션이 있으면 직접 만든다)
///
/// **앞의 토스트를 걷고 바로 띄운다** (이슈 #229). `ScaffoldMessenger` 는 기본이
/// 줄 세우기라, 등록을 연달아 누르면 새 문구가 앞 문구의 4초가 끝날 때까지
/// 화면에 나오지 않는다 — 방금 누른 것에 대한 답이 늦게 오면 반응이 없는
/// 것으로 읽힌다. 지금 누른 동작의 결과가 지금 보여야 한다.
extension AppToast on BuildContext {
  void showToast(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(keepAllText(message))));
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
