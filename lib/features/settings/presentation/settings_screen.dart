import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 설정 화면 (이슈 #98)
///
/// **왜 만들었나** — 홈 상태 바에 아이콘이 셋(알림음 크기·알림 미리보기·
/// 진단 기록) 늘어서면서 정작 중요한 감시 상태가 묻혔다. 상태 바는
/// "지금 감시 중인가"를 보여주는 곳이지 설정 모음이 아니다.
///
/// 평소에 쓸 일이 없는 것부터 여기로 내린다. 진단 기록은 문제가 생겼을
/// 때만 여는 화면이라 홈 최상단을 차지할 자리가 아니었다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.onOpenVolumeSettings,
    required this.onOpenDiagnostics,
    this.onPreviewAlert,
    super.key,
  });

  final VoidCallback onOpenVolumeSettings;
  final VoidCallback onOpenDiagnostics;

  /// 알림 흐름 수동 확인 (실기기 스파이크용).
  /// 지오펜스 실기기 검증이 끝나면 제거한다 (docs/11-ROADMAP.md).
  final VoidCallback? onPreviewAlert;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          children: [
            const _SectionLabel('알림'),
            _SettingTile(
              icon: Icons.tune_outlined,
              title: '알림음 크기',
              subtitle: '이어폰으로 들릴 소리 크기',
              onTap: onOpenVolumeSettings,
            ),
            if (onPreviewAlert != null)
              _SettingTile(
                icon: Icons.notifications_active_outlined,
                title: '알림 미리보기',
                subtitle: '알림 화면과 진동을 지금 확인합니다',
                onTap: onPreviewAlert!,
              ),

            const _SectionLabel('문제 해결'),
            _SettingTile(
              icon: Icons.receipt_long_outlined,
              title: '진단 기록',
              subtitle: '알림이 오지 않았을 때 무슨 일이 있었는지 봅니다',
              onTap: onOpenDiagnostics,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(text, style: AppTypography.caption),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTypography.body),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
