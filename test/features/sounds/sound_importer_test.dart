import 'package:ear_loc_alert/features/sounds/domain/custom_sound.dart';
import 'package:ear_loc_alert/features/sounds/domain/custom_sound_repository.dart';
import 'package:ear_loc_alert/features/sounds/domain/sound_file_picker.dart';
import 'package:ear_loc_alert/features/sounds/domain/sound_importer.dart';
import 'package:ear_loc_alert/features/sounds/domain/sound_probe.dart';
import 'package:ear_loc_alert/features/sounds/domain/sound_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 음원 등록 흐름 (이슈 #121)
///
/// **검증 순서가 이 테스트의 핵심이다.** 싼 것부터 보지 않으면 5MB 파일을
/// 디코딩하고 나서 "개수가 찼습니다"를 말하게 된다.
class FakePicker implements SoundFilePicker {
  PickedSoundFile? result;
  int pickCount = 0;

  @override
  Future<PickedSoundFile?> pick() async {
    pickCount++;
    return result;
  }
}

class FakeProbe implements SoundProbe {
  Duration? result = const Duration(seconds: 3);
  int probeCount = 0;

  @override
  Future<Duration?> probe(String filePath) async {
    probeCount++;
    return result;
  }
}

class FakeRepository implements CustomSoundRepository {
  int stored = 0;
  bool failOnAdd = false;
  int addCount = 0;
  String? lastSourcePath;

  @override
  Future<int> count() async => stored;

  @override
  Future<CustomSound> add({
    required String sourcePath,
    required String displayName,
    required Duration duration,
  }) async {
    addCount++;
    lastSourcePath = sourcePath;
    if (failOnAdd) throw Exception('디스크 가득참');
    return CustomSound(
      id: 'generated',
      displayName: displayName,
      fileExtension: SoundValidator.extensionOf(displayName),
      duration: duration,
      sizeBytes: 1000,
      createdAt: DateTime.utc(2026, 9),
    );
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<CustomSound>> findAll() async => const [];

  @override
  Future<CustomSound?> findById(String id) async => null;

  @override
  Future<String?> resolvePlayablePath(String id) async => null;
}

void main() {
  late FakePicker picker;
  late FakeProbe probe;
  late FakeRepository repo;
  late SoundImporter importer;

  setUp(() {
    picker = FakePicker();
    probe = FakeProbe();
    repo = FakeRepository();
    importer = SoundImporter(picker: picker, probe: probe, repository: repo);
  });

  PickedSoundFile pick({
    String name = 'ring.mp3',
    int size = 1024,
    String path = '/tmp/ring.mp3',
  }) => PickedSoundFile(path: path, displayName: name, sizeBytes: size);

  test('취소하면 아무 일도 하지 않는다', () async {
    picker.result = null;

    final outcome = await importer.import();

    expect(outcome, isA<SoundImportCancelled>());
    expect(probe.probeCount, 0);
    expect(repo.addCount, 0);
  });

  test('정상 파일은 등록된다', () async {
    picker.result = pick();

    final outcome = await importer.import();

    expect(outcome, isA<SoundImported>());
    expect((outcome as SoundImported).sound.displayName, 'ring.mp3');
    expect(repo.lastSourcePath, '/tmp/ring.mp3');
  });

  test('개수가 찼으면 디코딩하지 않는다', () async {
    repo.stored = SoundLimits.maxCount;
    picker.result = pick();

    final outcome = await importer.import();

    expect(outcome, isA<SoundImportRejected>());
    expect(probe.probeCount, 0, reason: '어차피 못 넣는데 파일을 열어보는 것은 낭비다');
  });

  test('큰 파일은 디코딩하지 않는다', () async {
    picker.result = pick(size: SoundLimits.maxBytes + 1);

    final outcome = await importer.import();

    expect(outcome, isA<SoundImportRejected>());
    expect((outcome as SoundImportRejected).error, isA<SoundTooLarge>());
    expect(probe.probeCount, 0);
  });

  test('모르는 형식은 디코딩하지 않는다', () async {
    picker.result = pick(name: 'clip.mp4');

    final outcome = await importer.import();

    expect(
      (outcome as SoundImportRejected).error,
      isA<UnsupportedSoundFormat>(),
    );
    expect(probe.probeCount, 0);
  });

  test('확장자는 맞지만 재생 못 하면 거부한다', () async {
    picker.result = pick();
    probe.result = null;

    final outcome = await importer.import();

    expect(
      (outcome as SoundImportRejected).error,
      isA<SoundNotPlayable>(),
      reason:
          '.mp3 로 이름만 바꾼 파일이 여기서 걸린다 — '
          '통과시키면 알림이 울려야 할 순간에 진동만 남는다',
    );
    expect(repo.addCount, 0);
  });

  test('너무 긴 음원은 거부한다', () async {
    picker.result = pick();
    probe.result = SoundLimits.maxDuration + const Duration(seconds: 1);

    final outcome = await importer.import();

    expect((outcome as SoundImportRejected).error, isA<SoundTooLong>());
    expect(repo.addCount, 0);
  });

  test('저장 실패는 거부와 구분한다', () async {
    picker.result = pick();
    repo.failOnAdd = true;

    final outcome = await importer.import();

    expect(
      outcome,
      isA<SoundImportFailed>(),
      reason: '사용자가 고칠 수 있는 문제가 아니라 다른 문구를 보여줘야 한다',
    );
  });
}
