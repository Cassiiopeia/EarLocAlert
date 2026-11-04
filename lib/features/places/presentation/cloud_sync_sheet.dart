import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/components/grouped_list_row.dart';
import '../../../core/ui/components/grouped_list_section.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../data/cloud_sync_providers.dart';
import '../domain/cloud_sync_service.dart';
import 'auto_backup_sheet.dart';

/// 동기화 실행 묶음 (app 계층 조율기가 넣음, 프로 확인 포함)
typedef CloudSyncActions = ({
  Future<CloudSyncConnectResult> Function() connect,
  Future<CloudSyncOutcome> Function() confirmImport,
  Future<CloudSyncOutcome> Function() syncNow,
  Future<void> Function({required bool deleteRemote}) disconnect,
});

/// 구글 드라이브 동기화 시트 (#330): 연결, 지금 동기화, 연결 끊기
Future<void> showCloudSyncSheet(
  BuildContext context, {
  required CloudSyncActions actions,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (context) => _CloudSyncSheet(actions: actions),
  );
}

/// 설정 줄 부제: 꺼짐 / 계정 · 마지막 시각
String cloudSyncSubtitle(
  AppLocalizations l10n,
  ({String? accountEmail, DateTime? lastSyncedAtUtc})? status,
) {
  final account = status?.accountEmail;
  if (account == null) return l10n.cloudSyncOff;
  final lastAt = status?.lastSyncedAtUtc;
  if (lastAt == null) return l10n.cloudSyncOnNever(account);
  return l10n.cloudSyncOnLast(account, formatBackupTime(lastAt));
}

class _CloudSyncSheet extends ConsumerStatefulWidget {
  const _CloudSyncSheet({required this.actions});

  final CloudSyncActions actions;

  @override
  ConsumerState<_CloudSyncSheet> createState() => _CloudSyncSheetState();
}

class _CloudSyncSheetState extends ConsumerState<_CloudSyncSheet> {
  /// 연결·동기화 중 (버튼 중복 방지)
  bool _isBusy = false;

  /// 바쁨 표시로 감싸 실행 (실패·시트 닫힘에도 상태 복구, 성공·실패 공통)
  Future<void> _runBusy(Future<void> Function() task) async {
    setState(() => _isBusy = true);
    try {
      await task();
    } finally {
      if (mounted) {
        ref.invalidate(cloudSyncStatusProvider);
        setState(() => _isBusy = false);
      }
    }
  }

  /// 연결 > (빈 기기 + Drive 장소) 가져오기 확인 > 결과 안내
  Future<void> _connect() => _runBusy(() async {
    final result = await widget.actions.connect();
    if (!mounted) return;
    switch (result) {
      case CloudSyncConnectCancelled():
        context.showToast(context.l10n.cloudSyncConnectFailed);
      case CloudSyncConnectNeedsImport():
        final shouldImport = await _askImport(result);
        if (shouldImport) {
          _showOutcome(await widget.actions.confirmImport());
        } else {
          // 나중에 = 연결하지 않음 (연결만 남으면 동기화가 조용히 멈추고, 장소를 더하는 순간 묻지 않고 섞임)
          await widget.actions.disconnect(deleteRemote: false);
        }
      case CloudSyncConnectDone(:final outcome):
        _showOutcome(outcome);
    }
  });

  Future<void> _syncNow() =>
      _runBusy(() async => _showOutcome(await widget.actions.syncNow()));

  /// 연결 끊기 > Drive 데이터도 지울지 묻기 (닫으면 취소)
  Future<void> _disconnect() async {
    final l10n = context.l10n;
    final deleteRemote = await showAppBottomSheet<bool>(
      context,
      builder: (context) => BottomSheetWithHeaderLayout(
        title: l10n.cloudSyncDisconnectDeleteTitle,
        body: const SizedBox.shrink(),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cloudSyncDisconnectKeep),
        ),
        secondaryAction: TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.cloudSyncDisconnectDelete),
        ),
      ),
    );
    if (deleteRemote == null) return;
    await _runBusy(() => widget.actions.disconnect(deleteRemote: deleteRemote));
  }

  /// 가져오기 확인: Drive 장소 수·저장 기기·날짜 > 가져오기 / 나중에
  Future<bool> _askImport(CloudSyncConnectNeedsImport needsImport) async {
    final l10n = context.l10n;
    final answer = await showAppBottomSheet<bool>(
      context,
      builder: (context) => BottomSheetWithHeaderLayout(
        headerIcon: Icons.cloud_download_outlined,
        title: l10n.cloudSyncImportTitle,
        description: l10n.cloudSyncImportMessage(
          needsImport.remotePlaceCount,
          needsImport.deviceLabel,
          formatBackupTime(needsImport.savedAtUtc),
        ),
        body: const SizedBox.shrink(),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.cloudSyncImportConfirm),
        ),
        secondaryAction: TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cloudSyncImportLater),
        ),
      ),
    );
    return answer ?? false;
  }

  /// 결과 > 안내 문구 (대기·연결 안 됨은 조용히)
  void _showOutcome(CloudSyncOutcome outcome) {
    if (!mounted) return;
    final l10n = context.l10n;
    final message = switch (outcome) {
      CloudSyncOutcome.synced ||
      CloudSyncOutcome.unchanged ||
      CloudSyncOutcome.skippedEmpty => l10n.cloudSyncDone,
      CloudSyncOutcome.newerSchema => l10n.cloudSyncNewerVersion,
      CloudSyncOutcome.readFailed ||
      CloudSyncOutcome.writeFailed => l10n.cloudSyncFailed,
      CloudSyncOutcome.notPro ||
      CloudSyncOutcome.notConnected ||
      CloudSyncOutcome.awaitingImport => null,
    };
    if (message != null) context.showToast(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(cloudSyncStatusProvider);
    final account = status.valueOrNull?.accountEmail;
    final lastAt = status.valueOrNull?.lastSyncedAtUtc;
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.cloud_outlined,
      title: l10n.cloudSyncTitle,
      description: l10n.cloudSyncDescription,
      body: status.isLoading && !status.hasValue
          ? const CenteredLoadingIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (account != null) ...[
                  GroupedListSection(
                    children: [
                      GroupedListRow.value(
                        icon: Icons.account_circle_outlined,
                        title: l10n.cloudSyncAccountTitle,
                        valueText: account,
                        onTap: null,
                      ),
                      GroupedListRow.value(
                        icon: Icons.schedule_outlined,
                        title: l10n.cloudSyncLastTitle,
                        valueText: lastAt == null
                            ? l10n.cloudSyncNever
                            : formatBackupTime(lastAt),
                        onTap: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _isBusy ? null : _disconnect,
                    icon: const Icon(Icons.cloud_off_outlined),
                    label: Text(l10n.cloudSyncDisconnect),
                  ),
                ] else
                  Text(
                    context.keepAllText(l10n.cloudSyncPrivacyNote),
                    style: context.appTextStyles.caption,
                  ),
              ],
            ),
      primaryAction: FilledButton(
        onPressed: _isBusy
            ? null
            : account == null
            ? _connect
            : _syncNow,
        child: _isBusy
            ? const InlineLoadingIndicator()
            : Text(account == null ? l10n.cloudSyncConnect : l10n.cloudSyncNow),
      ),
    );
  }
}
