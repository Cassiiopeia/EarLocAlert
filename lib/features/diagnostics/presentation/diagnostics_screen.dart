import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/debug_report.dart';
import '../../../core/diagnostics/diagnostic_line.dart';
import '../../../core/diagnostics/diagnostic_log_file.dart';
import '../../../core/diagnostics/diagnostic_log_reader.dart';
import '../../../core/diagnostics/file_diagnostic_logger.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../../../core/text/two_digits.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../domain/diagnostic_line_filter.dart';
import 'diagnostic_app_state_card.dart';
import 'diagnostic_filter_bar.dart';
import 'diagnostic_log_line_tile.dart';

/// 진단 로그 화면 (이슈 #95)
///
/// **문제가 생겼을 때 볼 수 있는 유일한 창구다.** 이 앱은 백그라운드
/// 동작이 핵심이라 재현이 어렵고, "어제 도착했는데 안 울렸다"는 상황에서
/// 개발자가 확인할 수 있는 것이 여기뿐이다.
///
/// 최근 기록이 위로 오게 뒤집어 보여준다 — 방금 일어난 일을 찾으러
/// 오는 화면이라 아래로 스크롤하게 만들면 안 된다.
///
/// 구성 (이슈 #290): 앱 상태 카드 > 검색·출처·태그·문제만 필터 > 출처 표시 기록.
/// 내보내기·복사는 필터와 무관하게 앱 상태 + 전체 기록 보고서.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, required this.collectAppState});

  /// 권한·장소·설정·네이티브 상태 텍스트 (app 계층이 넣는다, 기능 간 import 금지)
  final Future<String> Function() collectAppState;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  /// 공유 시트 기준 위치를 재려고 내보내기 버튼에 단다 (이슈 #241)
  final _exportKey = GlobalKey();
  final _searchController = TextEditingController();

  // 읽은 기록 (오래된 것 먼저)과 그로부터 계산한 필터 재료
  List<DiagnosticLine> _lines = const [];
  List<DiagnosticLine> _visibleLines = const [];
  List<DiagnosticLogSource> _sourcesWithLines = const [];
  List<MapEntry<String, int>> _tagCounts = const [];
  int _problemCount = 0;
  DiagnosticLineFilter _filter = const DiagnosticLineFilter();

  String _appState = '';

  /// 기록 파일을 읽지 못한 사유. 비어 있으면 정상적으로 읽은 것이다
  String _readError = '';

  /// 기록이 차지하는 용량 (이슈 #110)
  int _sizeBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 기록을 읽는다 (이슈 #106).
  ///
  /// **파일을 직접 연다 — `Diagnostics.logger` 를 거치지 않는다.**
  /// 그 로거는 앱 시작 시 `init()` 이 성공해야 파일 로거가 되고, 실패하면
  /// 아무것도 하지 않는 로거로 남는다. 그 상태에서 `readAll()` 은 무조건
  /// 빈 문자열이라, **파일에 Kotlin 이 남긴 기록이 잔뜩 있어도 화면은
  /// 0건으로 보인다.** 진단 화면이 진단 대상의 초기화 성공 여부에
  /// 의존하면 안 된다 — 정확히 그것이 실패했을 때 열리는 화면이다.
  ///
  /// 초기화도 여기서 한 번 더 시도한다. 성공하면 이후 화면에서 발생하는
  /// 기록도 남고, 실패해도 읽기는 파일에서 직접 하므로 영향이 없다.
  Future<void> _load() async {
    setState(() => _loading = true);

    // 실패해도 아래 파일 읽기는 그대로 진행된다
    await Diagnostics.init();

    // **이 줄이 다음에 보이면 로깅이 살아있다는 뜻이다** (이슈 #106).
    // 기록이 비어 보일 때 "안 쌓이는 것"인지 "못 읽는 것"인지를
    // 사용자가 스스로 가릴 수 있는 가장 단순한 신호다
    Diagnostics.log('diag', 'diagnostics screen opened');

    final snapshot = await DiagnosticLogReader.readSnapshot();
    final size = await DiagnosticLogReader.sizeInBytes();
    final appState = await _collectAppState();

    if (!mounted) return;
    setState(() {
      _lines = snapshot.lines;
      _sourcesWithLines = [
        for (final summary in snapshot.sources)
          if (summary.lineCount > 0) summary.source,
      ];
      _tagCounts = countLinesByTag(snapshot.lines);
      _problemCount = snapshot.lines.where((line) => line.isProblem).length;
      _visibleLines = _filter.apply(_lines);
      _appState = appState;
      _readError = snapshot.error;
      _sizeBytes = size;
      _loading = false;
    });
  }

  /// 앱 상태 수집. 실패해도 화면·내보내기는 계속 (사유를 상태 자리에 남김)
  Future<String> _collectAppState() async {
    try {
      return await widget.collectAppState();
    } on Object catch (error) {
      Diagnostics.log('diag', 'app state collect failed error=$error');
      return 'unavailable error=$error';
    }
  }

  void _onFilterChanged(DiagnosticLineFilter next) {
    setState(() {
      _filter = next;
      _visibleLines = next.apply(_lines);
    });
  }

  /// 보고서를 파일로 내보낸다 (이슈 #110, 앱 상태 포함 #290).
  ///
  /// 앱 상태는 내보내는 순간 다시 읽는다 — 화면을 연 뒤 바뀌었을 수 있다.
  Future<void> _export() async {
    // await 뒤에는 context 를 쓰지 않도록 제목을 미리 구해둔다
    final subject = context.l10n.diagnosticsExportSubject;
    // **공유 시트의 기준 위치를 넘긴다** (이슈 #241). iOS 26 은 iPhone 에서도
    // 공유 시트를 popover 로 띄워, 위치가 비면 share_plus 가 예외를 던진다.
    // 그 예외를 기록 없이 복사로 삼켜서 "내보내기가 복사만 한다"가 됐다
    final origin = _exportOrigin();
    try {
      final report = await DebugReport.writeFile(
        appState: await _collectAppState(),
      );
      final result = await Share.shareXFiles(
        // **MIME 을 명시한다.** 없으면 확장자로 추론되는데, 받는 앱이
        // 알 수 없는 형식으로 보고 열기를 거부할 수 있다
        [XFile(report.path, mimeType: 'text/plain')],
        subject: subject,
        sharePositionOrigin: origin,
      );
      Diagnostics.log(
        'diag',
        'export shared status=${result.status.name} '
            'bytes=${await report.length()} lines=${_lines.length}',
      );
    } on Object catch (error) {
      // 공유 시트를 못 띄우면 복사로 물러난다 — 꺼낼 길이 하나는 남아야 한다.
      // 사유를 남긴다: 삼키기만 하면 다음에도 왜 복사로 갔는지 모른다
      Diagnostics.log(
        'diag',
        'export failed fallback=copy origin=$origin error=$error',
      );
      await _copy();
    }
  }

  /// 내보내기 버튼의 화면 위치. 못 구하면 화면 가운데 작은 사각형 —
  /// 비어 있는 것보다는 낫다 (빈 값이면 iOS 에서 공유 시트가 실패한다)
  Rect _exportOrigin() {
    final box = _exportKey.currentContext?.findRenderObject();
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

  /// 보고서 전체(앱 상태 + 전체 기록)를 클립보드로
  Future<void> _copy() async {
    final report = await DebugReport.compose(appState: _appState);
    await Clipboard.setData(ClipboardData(text: report));
    Diagnostics.log('diag', 'report copied chars=${report.length}');
    if (!mounted) return;
    _toast(context.l10n.diagnosticsCopied);
  }

  Future<void> _clear() async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.diagnosticsClearTitle,
      body: context.l10n.diagnosticsClearBody,
      cancelLabel: context.l10n.diagnosticsCancel,
      confirmLabel: context.l10n.diagnosticsClear,
    );
    if (!confirmed) return;

    // 로거가 초기화되지 않았을 수 있으므로 파일도 직접 비운다 (이슈 #106)
    await Diagnostics.logger.clear();
    await DiagnosticLogReader.clear();
    await _load();
  }

  void _toast(String message) {
    if (!mounted) return;
    context.showToast(message);
  }

  /// 출처 > 화면 표시 이름
  String _sourceLabelOf(DiagnosticLogSource source) => switch (source) {
    DiagnosticLogSource.app => context.l10n.diagnosticsSourceApp,
    DiagnosticLogSource.background => context.l10n.diagnosticsSourceBackground,
    DiagnosticLogSource.native => context.l10n.diagnosticsSourceNative,
    DiagnosticLogSource.iosNative => context.l10n.diagnosticsSourceIos,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diagnosticsTitle),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: context.l10n.diagnosticsRefresh,
          ),
          IconButton(
            onPressed: _loading ? null : _copy,
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: context.l10n.diagnosticsCopyAll,
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outlined),
            tooltip: context.l10n.diagnosticsClear,
          ),
        ],
      ),
      body: _loading
          ? const CenteredLoadingIndicator()
          : Column(
              children: [
                _Header(
                  lineCount: _lines.length,
                  shownCount: _filter.isActive ? _visibleLines.length : null,
                  sizeBytes: _sizeBytes,
                  firstAt: _lines.isEmpty ? null : _lines.first.at,
                  lastAt: _lines.isEmpty ? null : _lines.last.at,
                ),
                DiagnosticFilterBar(
                  filter: _filter,
                  onFilterChanged: _onFilterChanged,
                  searchController: _searchController,
                  problemCount: _problemCount,
                  sources: _sourcesWithLines,
                  tagCounts: _tagCounts,
                  sourceLabelOf: _sourceLabelOf,
                ),
                Expanded(child: _buildLineList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: _exportKey,
        onPressed: _loading ? null : _export,
        icon: const Icon(Icons.ios_share_outlined),
        label: Text(context.l10n.diagnosticsExport),
      ),
    );
  }

  /// 앱 상태 카드(맨 위) + 필터 결과 줄. 줄이 없으면 사유 안내
  Widget _buildLineList() {
    return ListView.separated(
      // 아래 여백: 마지막 줄이 내보내기 버튼에 가리지 않게
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppControlSize.primary + AppSpacing.md,
      ),
      itemCount: _visibleLines.length + 2,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return DiagnosticAppStateCard(appState: _appState);
        if (index == 1) {
          if (_visibleLines.isNotEmpty) return const SizedBox.shrink();
          return _EmptyState(
            readError: _readError,
            isFiltered: _lines.isNotEmpty,
          );
        }
        final line = _visibleLines[index - 2];
        return DiagnosticLogLineTile(
          line: line,
          sourceLabel: _sourceLabelOf(line.source),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.lineCount,
    required this.shownCount,
    required this.sizeBytes,
    required this.firstAt,
    required this.lastAt,
  });

  final int lineCount;

  /// 필터 중일 때만 값이 있다
  final int? shownCount;

  /// 기록이 차지하는 용량 (이슈 #110).
  ///
  /// **얼마나 쓰는지 보여야 지울지 판단할 수 있다.** 상한이 있다는 사실도
  /// 함께 알린다 — 무한히 커진다고 오해하면 불안해서 계속 지우게 된다.
  final int sizeBytes;

  /// 가장 오래된·최근 기록 시각 (얼마나 거슬러 볼 수 있는지)
  final DateTime? firstAt;
  final DateTime? lastAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstAt = this.firstAt;
    final lastAt = this.lastAt;
    final shownCount = this.shownCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outlined, size: AppIconSize.inline),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.keepAllText(
                    l10n.diagnosticsHeader(
                      lineCount,
                      _formatSize(sizeBytes),
                      _formatSize(FileDiagnosticLogger.defaultMaxBytes),
                    ),
                  ),
                  style: context.appTextStyles.caption,
                ),
                if (firstAt != null && lastAt != null)
                  Text(
                    l10n.diagnosticsPeriod(
                      _shortDateTime(firstAt),
                      _shortDateTime(lastAt),
                    ),
                    style: context.appTextStyles.caption,
                  ),
                if (shownCount != null)
                  Text(
                    l10n.diagnosticsShownCount(shownCount),
                    style: context.appTextStyles.caption.copyWith(
                      color: context.appColors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `10/19 08:00` (지역 시각)
  String _shortDateTime(DateTime at) {
    final local = at.toLocal();
    return '${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

/// 보여줄 줄이 없을 때 (이슈 #106)
///
/// **"기록 없음"·"읽지 못함"·"조건에 안 맞음"을 구분한다.** 파일을 못 읽는 중에
/// "아직 기록이 없습니다"를 보면 사용자는 감시가 안 도는 줄 알고 없는 문제를 찾게 된다.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.readError, required this.isFiltered});

  final String readError;

  /// 기록은 있는데 필터에 걸러진 경우
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final failed = readError.isNotEmpty;
    final message = isFiltered
        ? context.l10n.diagnosticsNoMatch
        : failed
        ? context.l10n.diagnosticsReadFailed
        : context.l10n.diagnosticsEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.keepAllText(message),
            textAlign: TextAlign.center,
            style: context.appTextStyles.body,
          ),
          if (failed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.keepAllText(readError),
              textAlign: TextAlign.center,
              style: context.appTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// `1.2MB` · `340KB` 처럼 읽기 쉬운 크기로 (이슈 #110)
String _formatSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}
