import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/text/two_digits.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/components/grouped_list_row.dart';
import '../../../core/ui/components/grouped_list_section.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../data/auto_backup_providers.dart';
import '../domain/auto_backup.dart';

/// 자동 백업 시트 (#314): 폴더 고르기·바꾸기, 지금 백업, 끄기
///
/// [onBackupNow] 는 app 계층의 백업 실행 (프로 확인 포함). 폴더를 고르면 바로 한 번 씀
Future<void> showAutoBackupSheet(
  BuildContext context, {
  required Future<AutoBackupOutcome?> Function() onBackupNow,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (context) => _AutoBackupSheet(onBackupNow: onBackupNow),
  );
}

/// 설정 줄 부제: 꺼짐 / 폴더 이름 · 마지막 시각
String autoBackupSubtitle(
  AppLocalizations l10n,
  ({String? folderName, DateTime? lastBackupAtUtc})? status,
) {
  final folderName = status?.folderName;
  if (folderName == null) return l10n.autoBackupOff;
  final lastAt = status?.lastBackupAtUtc;
  if (lastAt == null) return l10n.autoBackupOnNever(folderName);
  return l10n.autoBackupOnLast(folderName, formatBackupTime(lastAt));
}

/// 마지막 백업 시각 표기: M/D HH:mm (로컬)
String formatBackupTime(DateTime atUtc) {
  final local = atUtc.toLocal();
  return '${local.month}/${local.day} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

class _AutoBackupSheet extends ConsumerStatefulWidget {
  const _AutoBackupSheet({required this.onBackupNow});

  final Future<AutoBackupOutcome?> Function() onBackupNow;

  @override
  ConsumerState<_AutoBackupSheet> createState() => _AutoBackupSheetState();
}

class _AutoBackupSheetState extends ConsumerState<_AutoBackupSheet> {
  /// 폴더 고르기·쓰기 중 (버튼 중복 방지)
  bool _isBusy = false;

  /// 폴더 고르기 > 성공하면 바로 한 번 씀
  Future<void> _pickFolder() async {
    setState(() => _isBusy = true);
    final service = ref.read(autoBackupServiceProvider);
    final picked = await service.folder.pick();
    if (picked != null) {
      // 새 폴더에는 내용이 같아도 씀 (서명 비교 생략)
      await service.state.clear();
      await _backupNow(showResult: true);
    }
    ref.invalidate(autoBackupStatusProvider);
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _backupNow({required bool showResult}) async {
    final outcome = await widget.onBackupNow();
    ref.invalidate(autoBackupStatusProvider);
    if (!showResult || !mounted) return;
    final l10n = context.l10n;
    final message = switch (outcome) {
      AutoBackupOutcome.written ||
      AutoBackupOutcome.unchanged => l10n.autoBackupDone,
      AutoBackupOutcome.noPlaces => l10n.backupExportEmpty,
      AutoBackupOutcome.noFolder ||
      AutoBackupOutcome.failed ||
      null => l10n.autoBackupFailed,
    };
    context.showToast(message);
  }

  Future<void> _turnOff() async {
    final service = ref.read(autoBackupServiceProvider);
    await service.folder.clear();
    await service.state.clear();
    Diagnostics.log('backup', 'auto backup turned off');
    ref.invalidate(autoBackupStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(autoBackupStatusProvider);
    final folderName = status.valueOrNull?.folderName;
    final lastAt = status.valueOrNull?.lastBackupAtUtc;
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.cloud_sync_outlined,
      title: l10n.autoBackupTitle,
      description: l10n.autoBackupDescription,
      body: status.isLoading && !status.hasValue
          ? const CenteredLoadingIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GroupedListSection(
                  children: [
                    GroupedListRow.value(
                      icon: Icons.folder_outlined,
                      title: l10n.autoBackupFolderTitle,
                      valueText: folderName ?? l10n.autoBackupNoFolder,
                      onTap: _isBusy ? null : _pickFolder,
                    ),
                    if (folderName != null)
                      GroupedListRow.value(
                        icon: Icons.schedule_outlined,
                        title: l10n.autoBackupLastTitle,
                        valueText: lastAt == null
                            ? l10n.autoBackupNever
                            : formatBackupTime(lastAt),
                        onTap: null,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.keepAllText(l10n.autoBackupRestoreHint),
                  style: context.appTextStyles.caption,
                ),
                if (folderName != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _isBusy ? null : _turnOff,
                    icon: const Icon(Icons.cloud_off_outlined),
                    label: Text(l10n.autoBackupTurnOff),
                  ),
                ],
              ],
            ),
      primaryAction: FilledButton(
        onPressed: _isBusy
            ? null
            : folderName == null
            ? _pickFolder
            : () => _backupNow(showResult: true),
        child: Text(
          folderName == null ? l10n.autoBackupChooseFolder : l10n.autoBackupNow,
        ),
      ),
    );
  }
}
