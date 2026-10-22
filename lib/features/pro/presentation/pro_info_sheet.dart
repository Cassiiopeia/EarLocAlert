import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/keep_all.dart';
import '../../../core/ui/components/bottom_sheet_with_header_layout.dart';
import '../../../core/ui/components/loading_indicator.dart';
import '../../../core/ui/foundation/app_color_palette.dart';
import '../../../core/ui/foundation/app_spacing.dart';
import '../domain/pro_purchase_record.dart';
import 'plan_badge_chip.dart';
import 'pro_purchase_record_controller.dart';
import 'pro_restore_action.dart';

/// 이용권 정보 시트 열기 (#294) — 설정의 "평생 이용권 · PRO" 줄을 누르면
Future<void> showProInfoSheet(BuildContext context) {
  Diagnostics.log('pro', 'info sheet shown');
  return showAppBottomSheet<void>(
    context,
    builder: (context) => const _ProInfoSheet(),
  );
}

/// 이용권 정보: 상태 > 열린 방식 > 구매일 > 주문 번호 > 안내 > 복원
class _ProInfoSheet extends ConsumerStatefulWidget {
  const _ProInfoSheet();

  @override
  ConsumerState<_ProInfoSheet> createState() => _ProInfoSheetState();
}

class _ProInfoSheetState extends ConsumerState<_ProInfoSheet> {
  /// 복원 조회 중 (버튼 중복 탭 방지)
  bool _isRestoring = false;

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    await restoreProPurchase(context, ref);
    if (mounted) setState(() => _isRestoring = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final record = ref.watch(proPurchaseRecordControllerProvider).valueOrNull;

    final rows = <(String, Widget)>[
      (l10n.proInfoStatus, _InfoTag(label: l10n.proInfoStatusActive)),
      (l10n.proInfoSource, _InfoValue(l10n.proSourcePurchase)),
      (
        l10n.proInfoPurchasedAt,
        _InfoValue(_formatPurchaseDate(context, record) ?? l10n.proInfoUnknown),
      ),
      (
        l10n.proInfoOrderId,
        _InfoValue(record?.orderId ?? l10n.proInfoUnknown, isMonospace: true),
      ),
    ];

    return BottomSheetWithHeaderLayout(
      title: l10n.proInfoTitle,
      headerTrailing: const PlanLabel(isPro: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: colors.separator),
            ),
            child: Column(
              children: [
                for (final (index, (label, value)) in rows.indexed) ...[
                  if (index > 0)
                    Divider(height: 1, thickness: 1, color: colors.separator),
                  _InfoRow(label: label, value: value),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.keepAllText(l10n.proInfoNotePurchase),
            style: context.appTextStyles.caption,
          ),
        ],
      ),
      primaryAction: OutlinedButton(
        onPressed: _isRestoring ? null : _restore,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppControlSize.floating),
          shape: const StadiumBorder(),
        ),
        child: _isRestoring
            ? const InlineLoadingIndicator()
            : Text(l10n.proInfoRestore),
      ),
    );
  }

  /// 구매 시각(UTC) > 기기 시간대의 날짜 (예: 2026. 10. 22). 기록 없으면 null
  String? _formatPurchaseDate(BuildContext context, ProPurchaseRecord? record) {
    final purchasedAt = record?.purchasedAt;
    if (purchasedAt == null) return null;
    return MaterialLocalizations.of(
      context,
    ).formatShortDate(purchasedAt.toLocal());
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm - AppSpacing.xs / 2,
      ),
      child: Row(
        children: [
          Text(label, style: context.appTextStyles.caption),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }
}

/// 오른쪽 값 글자 (주문 번호는 고정폭)
class _InfoValue extends StatelessWidget {
  const _InfoValue(this.text, {this.isMonospace = false});

  final String text;
  final bool isMonospace;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      maxLines: 1,
      textAlign: TextAlign.right,
      style: isMonospace
          ? context.appTextStyles.code
          : context.appTextStyles.body.copyWith(fontWeight: FontWeight.w500),
    );
  }
}

/// 상태 알약 (사용 중: 민트)
class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = colors.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs / 4,
        ),
        child: Text(
          label,
          style: context.appTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
