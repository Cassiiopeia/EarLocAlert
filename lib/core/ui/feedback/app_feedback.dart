import 'package:flutter/material.dart';

import '../../text/keep_all.dart';

/// 화면 하단에 문구만 띄우는 스낵바 (되돌리기 같은 액션이 있으면 직접 만든다)
///
/// **앞의 토스트를 걷고 바로 띄운다** (이슈 #229). `ScaffoldMessenger` 는 기본이
/// 줄 세우기라, 등록을 연달아 누르면 새 문구가 앞 문구의 4초가 끝날 때까지
/// 화면에 나오지 않는다 — 방금 누른 것에 대한 답이 늦게 오면 반응이 없는
/// 것으로 읽힌다. 지금 누른 동작의 결과가 지금 보여야 한다.
extension AppToast on BuildContext {
  void showToast(String message) =>
      showToastOnMessenger(ScaffoldMessenger.of(this), message);
}

/// 비동기 뒤에 쓰는 토스트 — 미리 잡아 둔 [ScaffoldMessengerState] 로 띄운다
void showToastOnMessenger(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(messenger.context.keepAllText(message))),
    );
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

/// [showChoiceDialog] 의 버튼 하나 — [value] 가 null 이면 취소로 읽힌다
class AppDialogChoice<T extends Object> {
  const AppDialogChoice({required this.label, this.value});

  final String label;
  final T? value;
}

/// 버튼 둘 이상인 선택 창. **누른 버튼의 값, 바깥 탭이나 value 가 null 인 버튼이면 null.**
///
/// 취소와 "답하지 않고 닫음"을 구분해야 할 때 쓴다(진동 시험의 예·아니요).
Future<T?> showChoiceDialog<T extends Object>(
  BuildContext context, {
  required String title,
  required String body,
  TextStyle? bodyStyle,
  required List<AppDialogChoice<T>> choices,
}) => showDialog<T>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(title),
    content: Text(dialogContext.keepAllText(body), style: bodyStyle),
    actions: [
      for (final choice in choices)
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(choice.value),
          child: Text(choice.label),
        ),
    ],
  ),
);

/// 버튼이 하나 달린 스낵바 — 되돌리기·다시 시작처럼 바로 이어서 할 동작이 있을 때 (#276)
///
/// 화면을 떠난 뒤에도 띄워야 하는 경우가 많아(삭제 후 목록으로 돌아감 등)
/// context 가 아니라 미리 잡아 둔 [ScaffoldMessengerState] 를 받는다. 앞서 떠 있던
/// 스낵바는 기본으로 걷는다 — 연달아 눌렀을 때 옛 되돌리기가 남아 있으면 엉뚱한 것을 되돌린다.
void showSnackBarWithActionButton(
  ScaffoldMessengerState messenger, {
  required String message,
  required String actionLabel,
  required VoidCallback onActionPressed,
  Duration duration = const Duration(seconds: 4),

  /// 사용자 동작과 무관하게 뜨는 안내(앱 업데이트 등)는 false — 앞에 떠 있는
  /// 되돌리기를 걷으면 복원할 기회가 사라진다. 뒤에 줄을 선다
  bool replaceCurrentSnackBar = true,
}) {
  if (replaceCurrentSnackBar) messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: SnackBarAction(label: actionLabel, onPressed: onActionPressed),
    ),
  );
}
