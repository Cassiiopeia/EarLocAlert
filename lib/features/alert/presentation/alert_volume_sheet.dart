import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/alert_effects.dart';
import 'alert_controller_provider.dart';

/// 알림음 크기 설정 바텀시트 (이슈 #86)
///
/// 홈 상태 바에서 연다. 슬라이더 조작이 끝나면 즉시 저장한다 —
/// 확인 버튼을 두지 않는 이유는, 볼륨은 "듣고 맞추는" 값이라 미리듣기와
/// 저장이 분리되면 사용자가 저장을 잊는다.
Future<void> showAlertVolumeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
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
    // 저장된 값을 읽어 슬라이더 초기 위치를 맞춘다
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
            '알림음 크기',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '알림이 울릴 때 시스템 볼륨이 이 수준보다 낮으면 여기까지 '
            '올렸다가, 끄면 원래대로 되돌립니다.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),

          if (volume == null)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                const Icon(Icons.volume_down_outlined, size: 20),
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
                const Icon(Icons.volume_up_outlined, size: 20),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(volume * 100).round()}%',
                    style: AppTypography.body,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),

          if (_previewNotice != null)
            Text(_previewNotice!, style: AppTypography.caption),

          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: volume == null ? null : _togglePreview,
            child: Text(_previewing ? '미리듣기 멈추기' : '미리듣기'),
          ),
        ],
      ),
    );
  }

  /// 미리듣기도 실제 알림과 같은 문을 지난다 — **이어폰이 없으면 재생하지
  /// 않는다** (docs/03-DOMAIN.md 규칙 5). 설정 화면이라고 예외를 두면
  /// 도서관에서 스피커로 샌다.
  Future<void> _togglePreview() async {
    final sound = ref.read(alertSoundServiceProvider);

    if (_previewing) {
      await sound.stop();
      if (mounted) setState(() => _previewing = false);
      return;
    }

    var connected = false;
    try {
      connected = await sound.isHeadphoneConnected();
    } on Object {
      connected = false;
    }
    if (!mounted) return;

    if (!connected) {
      setState(() => _previewNotice = '이어폰이 연결되어 있지 않아 미리듣기를 할 수 없습니다.');
      return;
    }

    try {
      await sound.play(volume: _volume ?? AlertVolumeStore.defaultVolume);
      setState(() {
        _previewing = true;
        _previewNotice = null;
      });
    } on Object {
      setState(() => _previewNotice = '재생에 실패했습니다.');
    }
  }
}
