import 'package:ear_loc_alert/core/audio/alert_sound_source.dart';
import 'package:ear_loc_alert/core/audio/headphone_detector.dart';
import 'package:ear_loc_alert/core/di/providers.dart';
import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/sounds/domain/custom_sound.dart';
import 'package:ear_loc_alert/features/sounds/domain/custom_sound_repository.dart';
import 'package:ear_loc_alert/features/sounds/domain/sound_preview_player.dart';
import 'package:ear_loc_alert/features/sounds/presentation/sound_picker_sheet.dart';
import 'package:ear_loc_alert/features/sounds/presentation/sound_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림음 선택 시트 (이슈 #121)
///
/// **가장 중요한 것은 이어폰 없이 소리가 나지 않는 것이다** (F3.7).
/// 미리듣기는 사용자가 직접 누른 것이라 예외를 두고 싶어지지만, 규칙 2 에
/// 우회 경로가 하나 생기면 그 코드가 다음에 재사용된다.
class FakeDetector implements HeadphoneDetector {
  FakeDetector(this.connected);

  final bool connected;

  @override
  Future<bool> isConnected() async => connected;
}

class RecordingPlayer implements SoundPreviewPlayer {
  int playCount = 0;
  AlertSoundSource? lastSource;

  @override
  Future<void> play(AlertSoundSource source) async {
    playCount++;
    lastSource = source;
  }

  @override
  Future<void> stop() async {}
}

class FakeSoundRepository implements CustomSoundRepository {
  List<CustomSound> sounds = const [];
  final List<String> deleted = [];

  @override
  Future<List<CustomSound>> findAll() async => sounds;

  @override
  Future<CustomSound?> findById(String id) async =>
      sounds.where((s) => s.id == id).firstOrNull;

  @override
  Future<int> count() async => sounds.length;

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    sounds = sounds.where((s) => s.id != id).toList();
  }

  @override
  Future<CustomSound> add({
    required String sourcePath,
    required String displayName,
    required Duration duration,
  }) => throw UnimplementedError();

  @override
  Future<String?> resolvePlayablePath(String id) async => '/tmp/$id.mp3';
}

CustomSound makeSound({String id = 's1', String name = '알람소리.mp3'}) {
  return CustomSound(
    id: id,
    displayName: name,
    fileExtension: 'mp3',
    duration: const Duration(seconds: 3),
    sizeBytes: 640 * 1024,
    createdAt: DateTime.utc(2026, 9),
  );
}

void main() {
  late FakeSoundRepository repo;
  late RecordingPlayer player;

  setUp(() {
    repo = FakeSoundRepository();
    player = RecordingPlayer();
  });

  Future<AlertSound?> pumpSheet(
    WidgetTester tester, {
    required bool headphones,
    AlertSound current = AlertSound.fallback,
  }) async {
    AlertSound? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customSoundRepositoryProvider.overrideWithValue(repo),
          headphoneDetectorProvider.overrideWithValue(FakeDetector(headphones)),
          soundPreviewPlayerProvider.overrideWithValue(player),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showSoundPickerSheet(
                      context,
                      current: current,
                    );
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return result;
  }

  /// 미리듣기 버튼들. 프리셋·커스텀 순서로 나온다.
  Iterable<IconButton> previewButtons(WidgetTester tester) =>
      tester.widgetList<IconButton>(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.play_arrow_outlined,
        ),
      );

  testWidgets('이어폰이 없으면 안내를 띄운다', (tester) async {
    await pumpSheet(tester, headphones: false);

    expect(find.textContaining('이어폰을 연결하면'), findsOneWidget);
  });

  testWidgets('이어폰이 없으면 미리듣기를 누를 수 없다', (tester) async {
    repo.sounds = [makeSound()];
    await pumpSheet(tester, headphones: false);

    final buttons = previewButtons(tester);
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(
        button.onPressed,
        isNull,
        reason:
            '누를 수 있으면 도서관에서 스피커가 울린다 — '
            '이 앱은 그 순간 존재 이유를 잃는다 (F3.7)',
      );
    }
  });

  testWidgets('이어폰이 없으면 항목을 골라도 재생하지 않는다', (tester) async {
    repo.sounds = [makeSound()];
    await pumpSheet(tester, headphones: false);

    await tester.tap(find.text('알람소리.mp3'));
    await tester.pumpAndSettle();

    expect(player.playCount, 0, reason: '선택은 되어야 하지만 소리는 나면 안 된다');
  });

  testWidgets('이어폰이 있으면 미리듣기가 활성이다', (tester) async {
    await pumpSheet(tester, headphones: true);

    expect(previewButtons(tester).first.onPressed, isNotNull);
  });

  testWidgets('이어폰이 있으면 ▶ 로 들어볼 수 있다', (tester) async {
    repo.sounds = [makeSound()];
    await pumpSheet(tester, headphones: true);

    // **행 탭은 고르고 닫는 동작이다** (docs/06-UX.md 시트 확정 규칙).
    // 들어보기는 ▶ 가 맡는다 — 예전에는 탭 하나가 선택과 재생을 동시에
    // 해서 무엇이 일어난 것인지 모호했다.
    // 프리셋 5개 뒤에 내 음원이 온다 — 마지막 ▶ 가 그것이다
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w is IconButton &&
                w.icon is Icon &&
                (w.icon as Icon).icon == Icons.play_arrow_outlined,
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(player.playCount, 1);
    expect((player.lastSource! as FileSound).filePath, '/tmp/s1.mp3');
  });

  testWidgets('고른 값을 돌려준다', (tester) async {
    repo.sounds = [makeSound()];

    AlertSound? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customSoundRepositoryProvider.overrideWithValue(repo),
          headphoneDetectorProvider.overrideWithValue(FakeDetector(false)),
          soundPreviewPlayerProvider.overrideWithValue(player),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    picked = await showSoundPickerSheet(
                      context,
                      current: AlertSound.fallback,
                    );
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 하단 확정 버튼이 생기며 목록이 짧아졌다 — 화면 안으로 끌어온 뒤 누른다
    await tester.ensureVisible(find.text('알람소리.mp3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알람소리.mp3'));
    await tester.pumpAndSettle();

    expect(picked, isNull, reason: '고르기만 해서는 닫히지 않는다 — 여러 개를 들어보며 고르는 화면이다');

    await tester.tap(find.widgetWithText(FilledButton, '완료'));
    await tester.pumpAndSettle();

    expect(picked, const CustomSoundRef('s1'));
  });

  testWidgets('확정은 하단 주 버튼이 받는다', (tester) async {
    repo.sounds = [makeSound()];
    await pumpSheet(tester, headphones: false);

    // 예전에는 오른쪽 위 작은 TextButton 이었고, 큰 버튼 자리는 보조 동작인
    // '음원 추가' 가 차지했다 (이슈 #153 · #155)
    expect(find.widgetWithText(FilledButton, '완료'), findsOneWidget);
    // `OutlinedButton.icon` 은 내부 서브클래스라 byType 으로 안 잡힌다 —
    // "주 버튼이 아니다"를 세는 것이 이 검사의 목적이다
    expect(
      find.widgetWithText(FilledButton, '음원 추가'),
      findsNothing,
      reason: '보조 동작이 주 버튼 자리를 차지하면 안 된다',
    );
    expect(find.text('음원 추가'), findsOneWidget);
  });

  testWidgets('목록에 길이와 크기를 보여준다', (tester) async {
    repo.sounds = [makeSound()];
    await pumpSheet(tester, headphones: false);

    expect(
      find.textContaining('0:03'),
      findsOneWidget,
      reason: '무엇이 무엇인지 이름만으로는 구분이 안 될 수 있다',
    );
    expect(find.textContaining('640KB'), findsOneWidget);
  });

  testWidgets('등록 개수를 상한과 함께 보여준다', (tester) async {
    repo.sounds = [makeSound(), makeSound(id: 's2', name: 'b.mp3')];
    await pumpSheet(tester, headphones: false);

    expect(find.textContaining('2/10'), findsOneWidget);
  });
}
