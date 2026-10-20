import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/text/keep_all.dart';
import '../domain/alert_effects.dart';
import '../data/alert_providers.dart';
import '../../../core/ui/components/loading_indicator.dart';

/// 알림음 크기 설정 바텀시트 (이슈 #86)
///
/// 홈 상태 바에서 연다. 슬라이더 조작이 끝나면 즉시 저장한다 —
/// 확인 버튼을 두지 않는 이유는, 볼륨은 "듣고 맞추는" 값이라 미리듣기와
/// 저장이 분리되면 사용자가 저장을 잊는다.
Future<void> showAlertVolumeSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    builder: (context) => const _AlertVolumeSheet(),
  );
}

class _AlertVolumeSheet extends ConsumerStatefulWidget {
  const _AlertVolumeSheet();

  @override
  ConsumerState<_AlertVolumeSheet> createState() => _AlertVolumeSheetState();
}

class _AlertVolumeSheetState extends ConsumerState<_AlertVolumeSheet> {
  double? _volume;
  bool _previewing = false;
  String? _previewNotice;

  /// **dispose 에서 `ref` 를 쓸 수 없다** (이슈 #122).
  ///
  /// riverpod 은 위젯이 unmount 될 때 ref 를 먼저 무효화하고 그다음
  /// `State.dispose()` 를 부른다. 거기서 `ref.read` 를 하면
  /// "Cannot use ref after the widget was disposed" 로 터지고,
  /// **그 줄에서 멈추므로 정지 호출이 아예 실행되지 않는다.**
  /// 화면 없이 소리·진동이 남는 것이 정확히 막으려던 상태다.
  late final AlertSoundService _sound;

  @override
  void initState() {
    super.initState();
    _sound = ref.read(alertSoundServiceProvider);
    ref.read(alertVolumeStoreProvider).volume().then((value) {
      if (mounted) setState(() => _volume = value);
    });
  }

  @override
  void dispose() {
    // 시트를 닫으면 미리듣기도 끝난다 — 소리가 화면 없이 남으면 안 된다.
    // initState 에서 잡아둔 참조를 쓴다 (위 주석 참조)
    _sound.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final volume = _volume;

    // **값을 제목 줄에 둔다.** 슬라이더 옆 고정 폭(44px)에 두었더니
    // Pretendard 로 '100%' 가 41px 이라 여유가 3px 뿐이었고, 시스템 글자
    // 크기를 한 단계만 키워도 '100' / '%' 로 쪼개졌다
    return BottomSheetWithHeaderLayout(
      // 설정 화면의 알림음 크기 줄과 같은 아이콘 — 다른 시트와 머리 모양을 맞춘다
      headerIcon: Icons.tune_outlined,
      title: context.l10n.volumeTitle,
      headerTrailing: volume == null
          ? null
          : Text(
              '${(volume * 100).round()}%',
              style: context.appTextStyles.headline.copyWith(
                color: context.appColors.accent,
              ),
              maxLines: 1,
            ),
      description: context.l10n.volumeDescription,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (volume == null)
            const CenteredLoadingIndicator()
          else
            Row(
              children: [
                const Icon(
                  Icons.volume_down_outlined,
                  size: AppIconSize.standard,
                ),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: (value) => setState(() => _volume = value),
                    // 조작이 끝났을 때만 저장한다 — 드래그 중 매 프레임
                    // 디스크에 쓰지 않는다
                    onChangeEnd: (value) =>
                        ref.read(alertVolumeStoreProvider).save(value),
                  ),
                ),
                const Icon(
                  Icons.volume_up_outlined,
                  size: AppIconSize.standard,
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),

          if (_previewNotice != null)
            Text(
              context.keepAllText(_previewNotice!),
              style: context.appTextStyles.caption,
            ),
        ],
      ),
      // **보조 동작이라 주 버튼이 아니다** (docs/06-UX.md 주 액션 규칙). 이
      // 시트는 고치는 즉시 적용되므로 확정할 것이 없다
      secondaryAction: OutlinedButton(
        onPressed: volume == null ? null : _togglePreview,
        child: Text(
          _previewing
              ? context.l10n.volumePreviewStop
              : context.l10n.soundPreview,
        ),
      ),
    );
  }

  /// 미리듣기도 실제 알림과 같은 문을 지난다 — **이어폰이 없으면 재생하지
  /// 않는다** (docs/03-DOMAIN.md 규칙 5). 설정 화면이라고 예외를 두면
  /// 도서관에서 스피커로 샌다.
  Future<void> _togglePreview() async {
    final sound = ref.read(alertSoundServiceProvider);
    // await 를 건너기 전에 문구를 잡아 둔다 (비동기 뒤 context 사용 금지)
    final l10n = context.l10n;

    if (_previewing) {
      await sound.stop();
      if (mounted) setState(() => _previewing = false);
      return;
    }

    var connected = false;
    try {
      connected = await sound.isHeadphoneConnected();
    } on Object catch (error) {
      Diagnostics.log(
        'audio',
        'preview headphone check failed result=not_connected error=$error',
      );
      connected = false;
    }
    if (!mounted) return;

    if (!connected) {
      setState(() => _previewNotice = l10n.volumePreviewNoHeadphones);
      return;
    }

    try {
      await sound.play(volume: _volume ?? AlertVolumeStore.defaultVolume);
      setState(() {
        _previewing = true;
        _previewNotice = null;
      });
    } on Object catch (error) {
      Diagnostics.log('audio', 'preview play failed error=$error');
      setState(() => _previewNotice = l10n.volumePreviewFailed);
    }
  }
}
