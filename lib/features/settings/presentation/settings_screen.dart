import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 설정 화면이 보여줄 권한 한 줄 (이슈 #102)
///
/// **왜 권한 타입을 그대로 받지 않나** — settings 는 permission feature 를
/// 직접 import 하지 않는다 (docs/02-ARCHITECTURE.md 규칙 1). app 계층이
/// 권한 상태를 읽어 이 형태로 옮겨 내려준다.
class SettingsPermissionRow {
  const SettingsPermissionRow({
    required this.title,
    required this.description,
    required this.granted,
    required this.onTap,
  });

  final String title;

  /// 없으면 무엇이 안 되는지. 권한 이름만으로는 아무도 켜지 않는다
  final String description;
  final bool granted;
  final VoidCallback onTap;
}

/// 설정 화면 (이슈 #98, #102)
///
/// **왜 만들었나** — 홈 상태 바에 아이콘이 셋(알림음 크기·알림 미리보기·
/// 진단 기록) 늘어서면서 정작 중요한 감시 상태가 묻혔다. 상태 바는
/// "지금 감시 중인가"를 보여주는 곳이지 설정 모음이 아니다.
///
/// 평소에 쓸 일이 없는 것부터 여기로 내린다. 진단 기록은 문제가 생겼을
/// 때만 여는 화면이라 홈 최상단을 차지할 자리가 아니었다.
///
/// **권한 항목이 여기 있어야 하는 이유** (이슈 #102) — 알림 신뢰성 권한은
/// 온보딩의 선택 단계라 한 번 지나가면 다시 묻지 않는다. 그런데 그것을
/// 나중에 켤 자리가 앱 어디에도 없어서, 놓친 사용자는 "권한을 다 줬는데
/// 왜 알림 화면이 안 뜨는가"에 갇혔다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.onOpenVolumeSettings,
    required this.onOpenVibrationSettings,
    required this.onOpenDiagnostics,
    this.permissions = const [],
    this.onPreviewAlert,
    super.key,
  });

  final VoidCallback onOpenVolumeSettings;

  /// 진동 세기 (이슈 #103)
  final VoidCallback onOpenVibrationSettings;
  final VoidCallback onOpenDiagnostics;

  /// 알림이 확실히 도달하는 데 필요한 권한들 (이슈 #102)
  final List<SettingsPermissionRow> permissions;

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
              icon: Icons.vibration_outlined,
              title: '진동 세기',
              subtitle: '이어폰이 없을 때는 진동만으로 알립니다',
              onTap: onOpenVibrationSettings,
            ),
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

            if (permissions.isNotEmpty) ...[
              const _SectionLabel('알림 도달 권한'),
              for (final row in permissions) _PermissionTile(row: row),
            ],

            const _SectionLabel('문제 해결'),
            _SettingTile(
              icon: Icons.receipt_long_outlined,
              title: '동작 기록',
              subtitle: '알림이 언제 왜 울렸는지 기록을 보고 내보냅니다',
              onTap: onOpenDiagnostics,
            ),
          ],
        ),
      ),
    );
  }
}

/// 권한 한 줄 (이슈 #102)
///
/// 허용된 것도 **숨기지 않고 보여준다.** 무엇이 켜져 있고 무엇이 꺼져
/// 있는지가 한눈에 보여야 "알림이 왜 약한가"를 스스로 판단할 수 있다.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.row});

  final SettingsPermissionRow row;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final grantedColor = semantic?.statusActive ?? AppColors.textSecondary;

    return ListTile(
      leading: Icon(
        row.granted ? Icons.check_circle_outline : Icons.error_outline,
        color: row.granted ? grantedColor : AppColors.textSecondary,
      ),
      title: Text(row.title, style: AppTypography.body),
      subtitle: Text(
        row.granted ? '허용됨' : row.description,
        style: AppTypography.caption,
      ),
      // 이미 허용된 권한도 열 수 있게 둔다 — 사용자가 끄고 싶을 수 있다
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: row.onTap,
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
