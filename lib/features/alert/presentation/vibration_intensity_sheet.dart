import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/vibration_intensity.dart';
import 'alert_controller_provider.dart';

/// 진동 세기 설정 바텀시트 (이슈 #103)
///
/// **고르면 그 세기로 바로 울린다.** 진동은 숫자로 가늠할 수 없는 값이라
/// 미리 느껴보지 않으면 고를 수 없다. 알림음 크기 시트와 같은 이유로
/// 확인 버튼을 두지 않는다 — 고르는 즉시 저장된다.
Future<void> showVibrationIntensitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _VibrationIntensitySheet(),
  );
}

class _VibrationIntensitySheet extends ConsumerStatefulWidget {
  const _VibrationIntensitySheet();

  @override
  ConsumerState<_VibrationIntensitySheet> createState() =>
      _VibrationIntensitySheetState();
}

class _VibrationIntensitySheetState
    extends ConsumerState<_VibrationIntensitySheet> {
  VibrationIntensity? _selected;

  @override
  void initState() {
    super.initState();
    ref.read(vibrationIntensityStoreProvider).intensity().then((value) {
      if (mounted) setState(() => _selected = value);
    });
  }

  @override
  void dispose() {
    // 시트를 닫으면 미리보기 진동도 멎는다 — 화면 없이 계속 떨리면 안 된다
    ref.read(vibrationServiceProvider).stop();
    super.dispose();
  }

  /// 고른 세기를 저장하고 한 번 울려 들려준다.
  ///
  /// 저장이 먼저다 — 미리보기가 실패해도 선택은 남아야 한다.
  Future<void> _select(VibrationIntensity intensity) async {
    setState(() => _selected = intensity);
    try {
      await ref.read(vibrationIntensityStoreProvider).save(intensity);
    } on Object {
      // 저장 실패는 다음 선택에서 다시 시도된다
    }
    try {
      final vibration = ref.read(vibrationServiceProvider);
      // 한 번만 느끼면 된다 — 반복 주기를 길게 주고 곧바로 멈춘다
      await vibration.startRepeating(
        interval: const Duration(days: 1),
        intensity: intensity,
      );
      await Future<void>.delayed(
        Duration(milliseconds: intensity.pulseMs + 120),
      );
      await vibration.stop();
    } on Object {
      // 미리보기 실패는 설정을 막지 않는다
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

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
            '진동 세기',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '이어폰이 연결되지 않았을 때는 진동만으로 알립니다. '
            '고르면 그 세기로 한 번 울려 확인할 수 있습니다.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),

          if (selected == null)
            const Center(child: CircularProgressIndicator())
          else
            RadioGroup<VibrationIntensity>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) _select(value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final intensity in VibrationIntensity.values)
                    RadioListTile<VibrationIntensity>(
                      value: intensity,
                      title: Text(_label(intensity), style: AppTypography.body),
                      subtitle: Text(
                        _hint(intensity),
                        style: AppTypography.caption,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _label(VibrationIntensity intensity) => switch (intensity) {
    VibrationIntensity.weak => '약하게',
    VibrationIntensity.normal => '보통',
    VibrationIntensity.strong => '강하게',
  };

  String _hint(VibrationIntensity intensity) => switch (intensity) {
    VibrationIntensity.weak => '조용한 곳에서 주변에 들리지 않게',
    VibrationIntensity.normal => '기본값',
    VibrationIntensity.strong => '주머니나 가방 속에서도 느껴지게',
  };
}
