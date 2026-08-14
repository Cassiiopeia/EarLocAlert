import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/diagnostic_log_file.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 진단 로그 화면 (이슈 #95)
///
/// **문제가 생겼을 때 볼 수 있는 유일한 창구다.** 이 앱은 백그라운드
/// 동작이 핵심이라 재현이 어렵고, "어제 도착했는데 안 울렸다"는 상황에서
/// 개발자가 확인할 수 있는 것이 여기뿐이다.
///
/// 최근 기록이 위로 오게 뒤집어 보여준다 — 방금 일어난 일을 찾으러
/// 오는 화면이라 아래로 스크롤하게 만들면 안 된다.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = await Diagnostics.logger.readAll();
    if (!mounted) return;
    setState(() {
      _content = content;
      _loading = false;
    });
  }

  /// 최근 것이 위로 오게 뒤집는다
  List<String> get _lines {
    final lines = _content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    return lines.reversed.toList();
  }

  Future<void> _export() async {
    try {
      final file = await DiagnosticLogFile.resolve();
      if (!file.existsSync()) {
        _toast('내보낼 기록이 없습니다');
        return;
      }
      await Share.shareXFiles([XFile(file.path)], subject: 'EarLocAlert 진단 로그');
    } on Object {
      // 공유 시트를 못 띄우면 복사로 물러난다 — 꺼낼 길이 하나는 남아야 한다
      await _copy();
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _content));
    _toast('클립보드에 복사했습니다');
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록을 지울까요?'),
        content: const Text('지운 기록은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await Diagnostics.logger.clear();
    await _load();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;

    return Scaffold(
      appBar: AppBar(
        title: const Text('진단 기록'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: '새로고침',
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
            tooltip: '지우기',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _Header(lineCount: lines.length),
                Expanded(
                  child: lines.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          itemCount: lines.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _LogLine(raw: lines[index]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _export,
        icon: const Icon(Icons.ios_share_outlined),
        label: const Text('내보내기'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.lineCount});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$lineCount건 · 이 기록은 기기 안에만 저장되며 전송되지 않습니다',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '아직 기록이 없습니다.\n장소를 등록하고 감시가 시작되면 쌓입니다.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 로그 한 줄 — 시각·태그·내용을 갈라 보여준다
class _LogLine extends StatelessWidget {
  const _LogLine({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    // 형식: `2026-08-14T01:23:45.678Z [tag] 메시지`
    final match = RegExp(r'^(\S+)\s+\[([^\]]+)\]\s+(.*)$').firstMatch(raw);
    final time = match?.group(1) ?? '';
    final tag = match?.group(2) ?? '';
    final message = match?.group(3) ?? raw;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tag.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tag, style: AppTypography.caption),
                ),
              const SizedBox(width: AppSpacing.xs),
              Text(_shortTime(time), style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(message, style: AppTypography.body),
        ],
      ),
    );
  }

  /// 날짜는 대부분 같으므로 시각만 보여준다 — 한 화면에 더 많이 들어간다
  String _shortTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
