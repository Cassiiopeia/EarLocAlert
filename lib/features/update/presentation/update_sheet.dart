import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/app_update.dart';
import 'update_provider.dart';

/// 업데이트 확인 바텀시트 (이슈 #104)
///
/// **여는 순간 확인을 시작한다.** 확인 버튼을 한 번 더 누르게 하면
/// "업데이트 확인"을 두 번 누르는 화면이 된다.
Future<void> showUpdateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    showDragHandle: true,
    builder: (context) => const _UpdateSheet(),
  );
}

class _UpdateSheet extends ConsumerStatefulWidget {
  const _UpdateSheet();

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  UpdateCheck? _result;
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final result = await ref.read(appUpdateServiceProvider).check();
    if (mounted) setState(() => _result = result);
  }

  Future<void> _download(AppRelease release) async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await ref
          .read(appUpdateServiceProvider)
          .download(
            release,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            },
          );
      // 설치 화면이 앞으로 나왔다 — 시트를 닫아 뒤에 남기지 않는다
      if (mounted) Navigator.of(context).pop();
    } on AppUpdateException catch (error) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '업데이트',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._body(),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // 내려받는 중에는 닫지 못한다 — 중간에 끊으면 반쪽 파일이 남는다
              onPressed: _downloading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final error = _error;
    if (error != null) {
      return [
        Text('업데이트하지 못했습니다', style: AppTypography.body),
        const SizedBox(height: AppSpacing.xs),
        Text(error, style: AppTypography.caption),
      ];
    }

    if (_downloading) {
      return [
        Text('내려받는 중입니다', style: AppTypography.body),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(value: _progress > 0 ? _progress : null),
        const SizedBox(height: AppSpacing.xs),
        Text('끝나면 설치 화면이 열립니다. 설치는 직접 확인해주세요.', style: AppTypography.caption),
      ];
    }

    return switch (_result) {
      null => [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: AppSpacing.sm),
        Center(child: Text('최신 버전을 확인하고 있습니다', style: AppTypography.caption)),
      ],
      UpdateNotNeeded(:final current) => [
        Text('최신 버전입니다', style: AppTypography.body),
        const SizedBox(height: AppSpacing.xs),
        Text('현재 $current', style: AppTypography.caption),
      ],
      UpdateCheckFailed(:final reason) => [
        Text('확인하지 못했습니다', style: AppTypography.body),
        const SizedBox(height: AppSpacing.xs),
        // 실패를 "최신"으로 뭉뚱그리지 않는다 — 확인됐다고 믿는데
        // 실제로는 확인이 안 된 상태가 가장 나쁘다
        Text(reason, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () {
              setState(() => _result = null);
              unawaited(_check());
            },
            child: const Text('다시 확인'),
          ),
        ),
      ],
      UpdateAvailable(:final current, :final release) => [
        Text('새 버전 ${release.version}', style: AppTypography.body),
        const SizedBox(height: AppSpacing.xs),
        Text('현재 $current', style: AppTypography.caption),
        if (release.notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(release.notes, style: AppTypography.caption),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _download(release),
            child: const Text('내려받고 설치'),
          ),
        ),
      ],
    };
  }
}
