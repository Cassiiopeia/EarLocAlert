import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/domain/vibration_pattern_label.dart';
import '../../../core/entitlement/feature_access_controller.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/components/locked_content_blur.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../data/alert_providers.dart';
import '../domain/alert_effects.dart';
import '../domain/vibration_waveform.dart';

/// 패턴 시트 결과: [pattern] null = 기본 설정 따르기 (장소 폼 전용)
typedef VibrationPatternChoice = ({VibrationPattern? pattern});

/// 진동 패턴 고르기 시트 (#311): 탭 > 고르고 한 번 느껴 보기, 완료 > 확정
///
/// [allowFollowDefault] true 면 장소 폼용 ("기본 설정 따르기" 행). 닫으면 null (기존 값 유지).
/// 무료는 기본 패턴만, 나머지는 흐린 잠금 + [onUnlockPro] (알림음 시트와 같은 방식).
Future<VibrationPatternChoice?> showVibrationPatternSheet(
  BuildContext context, {
  required VibrationPattern? current,
  required bool allowFollowDefault,
  VoidCallback? onUnlockPro,
}) {
  return showAppBottomSheet<VibrationPatternChoice>(
    context,
    builder: (context) => _VibrationPatternSheet(
      initial: current,
      allowFollowDefault: allowFollowDefault,
      onUnlockPro: onUnlockPro,
    ),
  );
}

/// 설정 화면용: 기본 패턴을 고르고 저장 (#311)
Future<void> showDefaultVibrationPatternSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onUnlockPro,
}) async {
  final store = ref.read(vibrationPatternStoreProvider);
  final current = await store.pattern();
  if (!context.mounted) return;
  final choice = await showVibrationPatternSheet(
    context,
    current: current,
    allowFollowDefault: false,
    onUnlockPro: onUnlockPro,
  );
  final picked = choice?.pattern;
  if (picked == null || picked == current) return;
  try {
    await store.save(picked);
    Diagnostics.log(
      'vibration',
      'pattern saved scope=default from=${current.name} to=${picked.name}',
    );
  } on Object catch (error) {
    Diagnostics.log('vibration', 'pattern save failed error=$error');
  }
}

class _VibrationPatternSheet extends ConsumerStatefulWidget {
  const _VibrationPatternSheet({
    required this.initial,
    required this.allowFollowDefault,
    required this.onUnlockPro,
  });

  final VibrationPattern? initial;
  final bool allowFollowDefault;
  final VoidCallback? onUnlockPro;

  @override
  ConsumerState<_VibrationPatternSheet> createState() =>
      _VibrationPatternSheetState();
}

class _VibrationPatternSheetState
    extends ConsumerState<_VibrationPatternSheet> {
  /// 라디오 값: null 대신 쓰는 "기본 설정 따르기" 표식이 필요해 래핑
  late _PatternOption _selected = _PatternOption(widget.initial);

  /// dispose 에서 ref 를 쓸 수 없어 미리 잡아 둠 (#122)
  late final VibrationService _vibration;

  /// 미리 느껴 보기 번호: 빠르게 여러 개 누를 때 앞 미리보기의 멈춤이 뒤를 끊지 않게
  int _previewToken = 0;

  @override
  void initState() {
    super.initState();
    _vibration = ref.read(vibrationServiceProvider);
  }

  @override
  void dispose() {
    // 시트가 닫히면 미리보기 진동도 멈춤 (화면 없이 떨지 않게)
    _vibration.stop();
    super.dispose();
  }

  /// 고르기 > 한 번 느껴 보기 (기본 따르기는 지금 기본 패턴으로)
  Future<void> _select(_PatternOption option) async {
    setState(() => _selected = option);
    final token = ++_previewToken;
    try {
      final intensity = await ref
          .read(vibrationIntensityStoreProvider)
          .intensity();
      final pattern =
          option.pattern ??
          await ref.read(vibrationPatternStoreProvider).pattern();
      final waveform = VibrationWaveform.build(pattern, intensity);
      await _vibration.startRepeating(
        // 한 번만 느끼면 됨: 반복 주기를 길게 주고 파형이 끝나면 멈춤
        interval: const Duration(days: 1),
        intensity: intensity,
        waveform: waveform,
      );
      final previewMs = waveform?.totalMs ?? intensity.pulseMs + 120;
      await Future<void>.delayed(Duration(milliseconds: previewMs));
      if (token == _previewToken) await _vibration.stop();
    } on Object catch (error) {
      // 미리보기 실패는 고르기를 막지 않음
      Diagnostics.log('vibration', 'pattern preview failed error=$error');
    }
  }

  Widget _tile(_PatternOption option, String title, {String? subtitle}) =>
      RadioListTile<_PatternOption>(
        value: option,
        title: Text(title, style: context.appTextStyles.body),
        subtitle: subtitle == null
            ? null
            : Text(
                context.keepAllText(subtitle),
                style: context.appTextStyles.caption,
              ),
        contentPadding: EdgeInsets.zero,
      );

  /// 무료면 프로 패턴 묶음을 흐리게 잠금. 시트 안에서 결제해도 바로 풀리게 등급을 지켜봄
  Widget _lockedIfFree(Widget child) {
    final onUnlockPro = widget.onUnlockPro;
    final isLocked = !ref
        .watch(featureAccessControllerProvider)
        .canUseAllVibrationPatterns;
    if (!isLocked || onUnlockPro == null) return child;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: LockedContentBlur(
        caption: context.l10n.proLockedVibrationPatterns,
        actionLabel: context.l10n.proUnlockAction,
        onUnlock: onUnlockPro,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomSheetWithHeaderLayout(
      headerIcon: Icons.vibration_outlined,
      title: l10n.vibrationPatternTitle,
      description: Platform.isIOS
          ? '${l10n.vibrationPatternDescription} ${l10n.vibrationPatternIosNote}'
          : l10n.vibrationPatternDescription,
      body: RadioGroup<_PatternOption>(
        groupValue: _selected,
        onChanged: (value) {
          if (value != null) _select(value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.allowFollowDefault)
              _tile(
                const _PatternOption(null),
                l10n.vibrationPatternFollowDefault,
                subtitle: l10n.vibrationPatternFollowDefaultHint,
              ),
            // 무료여도 기본 패턴은 고를 수 있음
            _tile(
              const _PatternOption(VibrationPattern.standard),
              VibrationPattern.standard.localizedLabel(l10n),
            ),
            _lockedIfFree(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final pattern in VibrationPattern.values)
                    if (!pattern.isFree)
                      _tile(
                        _PatternOption(pattern),
                        pattern.localizedLabel(l10n),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      primaryAction: FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).pop<VibrationPatternChoice>((pattern: _selected.pattern)),
        child: Text(l10n.vibrationPatternDone),
      ),
    );
  }
}

/// 라디오 값 래퍼: [pattern] null = 기본 설정 따르기
@immutable
class _PatternOption {
  const _PatternOption(this.pattern);

  final VibrationPattern? pattern;

  @override
  bool operator ==(Object other) =>
      other is _PatternOption && other.pattern == pattern;

  @override
  int get hashCode => pattern.hashCode;
}
