import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/alert_sound_source.dart';
import '../../../core/di/providers.dart';
import '../../../core/domain/alert_sound.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/custom_sound.dart';
import '../domain/sound_importer.dart';
import '../domain/sound_preview_player.dart';
import '../domain/sound_validator.dart';
import 'sound_import_message.dart';
import 'sound_providers.dart';

/// 알림음 선택 시트 (이슈 #121)
///
/// 고른 값을 돌려준다. 취소하면 `null` — 호출자는 기존 값을 유지한다.
///
/// **라우트가 아니라 시트다.** 값 하나를 고르는 UI 는 전부 시트라는 것이
/// 이 앱의 관례이고, 예외는 지도 선택 화면 하나뿐이다.
Future<AlertSound?> showSoundPickerSheet(
  BuildContext context, {
  required AlertSound current,
}) {
  return showModalBottomSheet<AlertSound>(
    context: context,
    showDragHandle: true,
    // 음원이 늘면 목록이 길어진다 — 화면을 넘기면 스크롤되어야 한다
    isScrollControlled: true,
    builder: (context) => _SoundPickerSheet(current: current),
  );
}

class _SoundPickerSheet extends ConsumerStatefulWidget {
  const _SoundPickerSheet({required this.current});

  final AlertSound current;

  @override
  ConsumerState<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends ConsumerState<_SoundPickerSheet>
    with WidgetsBindingObserver {
  late AlertSound _selected = widget.current;

  /// null 이면 아직 읽는 중
  List<CustomSound>? _customSounds;

  /// null 이면 아직 판정 전
  bool? _headphonesConnected;

  bool _busy = false;

  /// **dispose 에서 `ref` 를 쓸 수 없다.**
  ///
  /// riverpod 은 위젯이 unmount 될 때 ref 를 먼저 무효화하고 그다음
  /// `State.dispose()` 를 부른다. 거기서 `ref.read` 를 하면
  /// "Cannot use ref after the widget was disposed" 로 터지고,
  /// **미리듣기가 멎지 않은 채 시트만 사라진다.** 화면 없이 소리가
  /// 남는 것이 정확히 이 앱이 피해야 하는 상태다.
  late final SoundPreviewPlayer _previewPlayer;

  @override
  void initState() {
    super.initState();
    _previewPlayer = ref.read(soundPreviewPlayerProvider);
    // 시트가 열려 있는 동안 이어폰을 꽂을 수 있다 — 앱이 재개될 때 다시 본다
    WidgetsBinding.instance.addObserver(this);
    _loadSounds();
    _checkHeadphones();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 시트를 닫으면 미리듣기도 멎는다 — 화면 없이 소리가 남으면 안 된다.
    // initState 에서 잡아둔 참조를 쓴다 (위 주석 참조)
    _previewPlayer.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkHeadphones();
  }

  Future<void> _loadSounds() async {
    try {
      final sounds = await ref.read(customSoundRepositoryProvider).findAll();
      if (mounted) setState(() => _customSounds = sounds);
    } on Object {
      // 목록을 못 읽어도 프리셋은 고를 수 있어야 한다
      if (mounted) setState(() => _customSounds = const []);
    }
  }

  Future<void> _checkHeadphones() async {
    try {
      final connected = await ref.read(headphoneDetectorProvider).isConnected();
      if (mounted) setState(() => _headphonesConnected = connected);
    } on Object {
      // 확인하지 못했으면 연결되지 않은 것으로 본다 —
      // 확인 못 한 상태로 재생하면 스피커로 샐 수 있다
      if (mounted) setState(() => _headphonesConnected = false);
    }
  }

  Future<void> _preview(AlertSound sound) async {
    final source = await _sourceOf(sound);
    if (source == null || !mounted) return;
    try {
      await _previewPlayer.play(source);
    } on Object {
      if (mounted) _showMessage('재생할 수 없는 음원입니다');
    }
  }

  /// 미리듣기에 쓸 소스. 파일이 없으면 null.
  Future<AlertSoundSource?> _sourceOf(AlertSound sound) async {
    switch (sound) {
      case PresetSound(:final preset):
        return AssetSound(preset.assetPath);
      case CustomSoundRef(:final id):
        final path = await ref
            .read(customSoundRepositoryProvider)
            .resolvePlayablePath(id);
        return path == null ? null : FileSound(path);
    }
  }

  Future<void> _addSound() async {
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(soundImporterProvider).import();
      if (!mounted) return;

      switch (outcome) {
        case SoundImportCancelled():
          break;
        case SoundImported(:final sound):
          await _loadSounds();
          // 방금 넣은 것을 바로 쓰게 한다 — 목록에서 다시 찾게 하지 않는다
          if (mounted) setState(() => _selected = CustomSoundRef(sound.id));
        case SoundImportRejected(:final error):
          _showMessage(soundImportErrorMessage(error));
        case SoundImportFailed():
          _showMessage('음원을 저장하지 못했습니다. 잠시 후 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSound(CustomSound sound) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음원을 삭제할까요?'),
        content: Text(
          '${sound.displayName}\n\n'
          '이 음원을 쓰던 장소는 기본음으로 알립니다.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _previewPlayer.stop();
    await ref.read(customSoundRepositoryProvider).delete(sound.id);
    await _loadSounds();

    // 지운 음원을 고른 상태로 두면 저장했을 때 없는 것을 가리킨다
    if (mounted && _selected == CustomSoundRef(sound.id)) {
      setState(() => _selected = AlertSound.fallback);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final customSounds = _customSounds;
    final canPreview = _headphonesConnected ?? false;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '알림음',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('완료'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            if (!canPreview) const _HeadphoneNotice(),

            Flexible(
              child: SingleChildScrollView(
                child: RadioGroup<AlertSound>(
                  groupValue: _selected,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selected = value);
                    if (canPreview) _preview(value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xs),
                      Text('기본 제공', style: AppTypography.caption),
                      for (final preset in SoundPreset.values)
                        _SoundTile(
                          value: PresetSound(preset),
                          title: preset.label,
                          canPreview: canPreview,
                          onPreview: () => _preview(PresetSound(preset)),
                        ),

                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '내 음원  ${customSounds?.length ?? 0}/'
                        '${SoundLimits.maxCount}',
                        style: AppTypography.caption,
                      ),

                      if (customSounds == null)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (customSounds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            '기기에 있는 음원 파일을 등록해 쓸 수 있습니다.',
                            style: AppTypography.caption,
                          ),
                        )
                      else
                        for (final sound in customSounds)
                          _SoundTile(
                            value: CustomSoundRef(sound.id),
                            title: sound.displayName,
                            subtitle:
                                '${formatDuration(sound.duration)} · '
                                '${formatBytes(sound.sizeBytes)}',
                            canPreview: canPreview,
                            onPreview: () => _preview(CustomSoundRef(sound.id)),
                            onDelete: () => _deleteSound(sound),
                          ),

                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _addSound,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_outlined),
                          label: Text(_busy ? '확인 중…' : '음원 추가'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이어폰이 없으면 미리듣기를 막는다는 안내 (이슈 #121)
///
/// **예외를 두지 않는 이유** — 규칙 2 에 우회 경로가 하나 생기면 그 코드가
/// 다음에 재사용된다. 그리고 어차피 실제 알림도 이어폰 없이는 울리지
/// 않으므로, 못 들어보는 것이 정확한 재현이다.
class _HeadphoneNotice extends StatelessWidget {
  const _HeadphoneNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.headphones_outlined, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '이어폰을 연결하면 들어볼 수 있습니다. '
              '알림음은 이어폰이 연결됐을 때만 재생됩니다.',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.value,
    required this.title,
    required this.canPreview,
    required this.onPreview,
    this.subtitle,
    this.onDelete,
  });

  final AlertSound value;
  final String title;
  final String? subtitle;
  final bool canPreview;
  final VoidCallback onPreview;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return RadioListTile<AlertSound>(
      value: value,
      title: Text(title, style: AppTypography.body),
      subtitle: sub == null ? null : Text(sub, style: AppTypography.caption),
      contentPadding: EdgeInsets.zero,
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            // 이어폰이 없으면 눌리지 않는다 — 소리가 샐 경로를 만들지 않는다
            onPressed: canPreview ? onPreview : null,
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: '미리듣기',
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
            ),
        ],
      ),
    );
  }
}
