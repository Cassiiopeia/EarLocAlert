import 'package:flutter/material.dart';

import '../../../core/config/build_info.dart';
import '../../../core/diagnostics/diagnostic_log_reader.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../domain/bug_report_sending.dart';

/// 문제 신고 시트 (이슈 #255)
///
/// 메일 앱을 열어 주는 데까지만 한다. **보내는 것은 사용자다** — 작성 화면에서
/// 첨부를 확인하고 직접 보내야 전송된다. 그래서 앱이 좌표를 몰래 전송하지 않는다.
Future<void> showBugReportSheet(
  BuildContext context, {
  required String appVersion,
  required BugReportSending sender,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _BugReportSheet(appVersion: appVersion, sender: sender),
  );
}

class _BugReportSheet extends StatefulWidget {
  const _BugReportSheet({required this.appVersion, required this.sender});

  final String appVersion;
  final BugReportSending sender;

  @override
  State<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<_BugReportSheet> {
  final _sendKey = GlobalKey();

  /// 기록이 있을 때만 켜져 있다. 없으면 체크를 막고 이유를 보여준다
  bool _attachLog = true;
  bool _hasLog = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkLog();
  }

  Future<void> _checkLog() async {
    final size = await DiagnosticLogReader.sizeInBytes();
    if (!mounted) return;
    setState(() {
      _hasLog = size > 0;
      _attachLog = _hasLog;
    });
  }

  Rect _origin() {
    final box = _sendKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 1,
      height: 1,
    );
  }

  Future<void> _send() async {
    if (_busy) return;
    final l10n = context.l10n;
    // await 뒤에는 context 를 쓰지 않도록 줄바꿈 처리한 문구를 미리 구한다
    final failedText = context.keepAllText(l10n.reportFailed);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final origin = _origin();
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() => _busy = true);

    String? attachmentPath;
    if (_attachLog && _hasLog) {
      try {
        attachmentPath =
            (await DiagnosticLogReader.createExportSnapshot()).path;
      } on Object catch (error) {
        // 기록을 못 만들어도 신고는 보낼 수 있어야 한다
        Diagnostics.log('report', 'snapshot failed error=$error');
      }
    }

    final body = [
      l10n.reportMailPrompt,
      '\n\n',
      '----',
      l10n.reportMailInfoHeader,
      widget.sender.describeDevice(
        appVersion: widget.appVersion,
        locale: locale,
        device: BuildInfo.deviceLabel,
      ),
    ].join('\n');

    final outcome = await widget.sender.send(
      subject: l10n.reportMailSubject,
      body: body,
      origin: origin,
      attachmentPath: attachmentPath,
      fallbackNotice: l10n.reportFallbackNotice(bugReportAddress),
    );

    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case BugReportOutcome.mailComposer:
      case BugReportOutcome.shareSheet:
        navigator.pop();
      case BugReportOutcome.failed:
        messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outlined),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.reportSheetTitle,
                  style: context.appTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.keepAllText(l10n.reportSheetHint),
              style: context.appTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _attachLog && _hasLog,
              onChanged: _hasLog && !_busy
                  ? (value) => setState(() => _attachLog = value ?? false)
                  : null,
              title: Text(
                l10n.reportAttachLog,
                style: context.appTextStyles.body,
              ),
              subtitle: Text(
                context.keepAllText(
                  _hasLog
                      ? l10n.reportAttachLogNote
                      : l10n.reportAttachLogEmpty,
                ),
                style: context.appTextStyles.caption,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: _sendKey,
              onPressed: _busy ? null : _send,
              child: Text(l10n.reportOpenMail),
            ),
          ],
        ),
      ),
    );
  }
}
