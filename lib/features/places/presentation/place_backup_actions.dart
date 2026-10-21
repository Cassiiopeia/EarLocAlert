import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/text/two_digits.dart';
import '../../../core/ui/feedback/app_feedback.dart';
import '../domain/place_backup.dart';
import '../domain/place_repository.dart';

/// 장소 내보내기 (이슈 #256) — JSON 파일을 만들어 공유 시트로 넘긴다
///
/// 파일로 저장하든 메일·메신저로 보내든 사용자가 공유 시트에서 고른다.
/// 서버를 거치지 않으므로 좌표는 사용자가 보낸 곳으로만 간다.
Future<void> exportPlacesBackup(
  BuildContext context, {
  required PlaceRepository repository,
  required String appVersion,
}) async {
  final l10n = context.l10n;
  final subject = l10n.backupExportSubject;
  final empty = l10n.backupExportEmpty;
  // await 뒤에는 context 를 쓰지 않도록 필요한 값을 미리 구해둔다
  final size = MediaQuery.sizeOf(context);
  final origin = Rect.fromCenter(
    center: size.center(Offset.zero),
    width: 1,
    height: 1,
  );
  String customSoundNote(int count) => l10n.backupExportCustomSound(count);

  try {
    final places = await repository.findAll();
    if (places.isEmpty) {
      if (context.mounted) context.showToast(empty);
      Diagnostics.log('backup', 'export skipped reason=no_places');
      return;
    }

    final now = DateTime.now();
    final export = PlaceBackup.encode(
      places,
      now: now.toUtc(),
      appVersion: appVersion,
    );
    final dir = await getTemporaryDirectory();
    final stamp =
        '${now.year}${twoDigits(now.month)}${twoDigits(now.day)}'
        '-${twoDigits(now.hour)}${twoDigits(now.minute)}';
    final file = File('${dir.path}/earlocalert-places-$stamp.json');
    await file.writeAsString(export.json, flush: true);

    // 사용자 음원을 쓰는 장소가 있으면 공유 시트를 띄우기 전에 알린다
    if (export.customSoundCount > 0 && context.mounted) {
      context.showToast(customSoundNote(export.customSoundCount));
    }

    final result = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: subject,
      sharePositionOrigin: origin,
    );
    Diagnostics.log(
      'backup',
      'export shared places=${export.placeCount} '
          'customSounds=${export.customSoundCount} '
          'status=${result.status.name}',
    );
  } on Object catch (error) {
    // 사유를 남긴다: 삼키기만 하면 내보내기가 왜 안 됐는지 알 수 없다
    Diagnostics.log('backup', 'export failed error=$error');
    if (context.mounted) context.showToast(l10n.backupImportReadFailed);
  }
}

/// 장소 불러오기 (이슈 #256)
///
/// 파일을 읽어 **무엇이 들어오는지 보여주고 나서** 넣는다. "모두 바꾸기"는
/// 되돌릴 수 없어 한 번 더 묻는다.
Future<void> importPlacesBackup(
  BuildContext context, {
  required PlaceRepository repository,

  /// 등록 상한 — `FeatureAccess.placeLimit` (#294)
  required int maxPlaces,
}) async {
  final l10n = context.l10n;

  String? raw;
  try {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    final path = picked?.files.singleOrNull?.path;
    if (path == null) {
      Diagnostics.log('backup', 'import cancelled');
      return;
    }
    raw = await File(path).readAsString();
  } on Object catch (error) {
    Diagnostics.log('backup', 'import read failed error=$error');
    if (context.mounted) context.showToast(l10n.backupImportReadFailed);
    return;
  }

  final decoded = PlaceBackup.decode(raw, now: DateTime.now().toUtc());
  if (decoded.error != null) {
    Diagnostics.log('backup', 'import rejected reason=${decoded.error!.name}');
    if (!context.mounted) return;
    context.showToast(switch (decoded.error!) {
      PlaceBackupError.newerVersion => l10n.backupImportNewer,
      PlaceBackupError.notJson ||
      PlaceBackupError.notBackup => l10n.backupImportInvalid,
    });
    return;
  }
  if (decoded.places.isEmpty) {
    Diagnostics.log(
      'backup',
      'import empty invalid=${decoded.invalidCount} reason=no_valid_places',
    );
    if (context.mounted) context.showToast(l10n.backupImportNone);
    return;
  }

  final existing = await repository.findAll();
  if (!context.mounted) return;
  final choice = await showChoiceDialog<_ImportChoice>(
    context,
    title: l10n.backupImportTitle,
    body: l10n.backupImportBody(decoded.places.length, existing.length),
    choices: [
      AppDialogChoice(label: l10n.backupCancel),
      if (existing.isNotEmpty)
        AppDialogChoice(
          label: l10n.backupImportReplace,
          value: _ImportChoice.replace,
        ),
      AppDialogChoice(label: l10n.backupImportAdd, value: _ImportChoice.add),
    ],
  );
  if (choice == null || !context.mounted) {
    Diagnostics.log('backup', 'import cancelled at=choice');
    return;
  }

  final replace = choice == _ImportChoice.replace;
  if (replace) {
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.backupReplaceTitle,
      body: l10n.backupReplaceBody(existing.length),
      cancelLabel: l10n.backupCancel,
      confirmLabel: l10n.backupReplaceConfirm,
    );
    if (!confirmed) {
      Diagnostics.log('backup', 'import cancelled at=replace_confirm');
      return;
    }
  }

  try {
    final plan = PlaceBackup.plan(
      existing: existing,
      incoming: decoded.places,
      replace: replace,
      maxPlaces: maxPlaces,
    );
    if (replace) {
      for (final place in existing) {
        await repository.delete(place.id);
      }
    }
    for (final place in plan.toAdd) {
      await repository.save(place);
    }
    final skipped =
        plan.duplicateCount + plan.overLimitCount + decoded.invalidCount;
    Diagnostics.log(
      'backup',
      'import done mode=${replace ? 'replace' : 'add'} '
          'added=${plan.toAdd.length} duplicate=${plan.duplicateCount} '
          'overLimit=${plan.overLimitCount} invalid=${decoded.invalidCount} '
          'removed=${replace ? existing.length : 0}',
    );
    if (!context.mounted) return;
    context.showToast(
      plan.toAdd.isEmpty
          ? l10n.backupImportNone
          : l10n.backupImportResult(plan.toAdd.length, skipped),
    );
  } on Object catch (error) {
    Diagnostics.log('backup', 'import failed error=$error');
    if (context.mounted) context.showToast(l10n.backupImportReadFailed);
  }
}

enum _ImportChoice { add, replace }
