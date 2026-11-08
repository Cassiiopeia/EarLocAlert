import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:ear_loc_alert/features/places/data/cloud_sync_providers.dart';
import 'package:ear_loc_alert/features/places/domain/cloud_sync_service.dart';
import 'package:ear_loc_alert/features/places/presentation/cloud_sync_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 가져오기 확인에서 "나중에" (#330): 연결만 남으면 동기화가 조용히 멈추고, 장소를 하나 더하는 순간 Drive 장소가 묻지도 않고 섞인다
void main() {
  testWidgets(
    'choosing later on import prompt disconnects without deleting drive',
    (tester) async {
      var disconnectCount = 0;
      bool? didDeleteRemote;
      var confirmCount = 0;
      final actions = (
        connect: () async => CloudSyncConnectNeedsImport(
          remotePlaceCount: 3,
          deviceLabel: 'iPhone',
          savedAtUtc: DateTime.utc(2026, 11, 4, 9),
        ),
        confirmImport: () async {
          confirmCount++;
          return CloudSyncOutcome.synced;
        },
        syncNow: () async => CloudSyncOutcome.synced,
        disconnect: ({required bool deleteRemote}) async {
          disconnectCount++;
          didDeleteRemote = deleteRemote;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudSyncStatusProvider.overrideWith(
              (ref) async => (accountEmail: null, lastSyncedAtUtc: null),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      showCloudSyncSheet(context, actions: actions),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect Google account'));
      // 연결 중 버튼 안 로딩 표시가 계속 돌아 settle 대신 시간으로 넘김
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Bring back your places?'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(confirmCount, 0);
      expect(disconnectCount, 1);
      expect(didDeleteRemote, isFalse);
    },
  );
}
