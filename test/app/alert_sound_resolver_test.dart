import 'package:ear_loc_alert/app/alert_sound_resolver.dart';
import 'package:ear_loc_alert/core/domain/alert_sound.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:ear_loc_alert/features/sounds/domain/custom_sound.dart';
import 'package:ear_loc_alert/features/sounds/domain/custom_sound_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 알림음 해석 (이슈 #121)
///
/// **어떤 실패에도 소리를 포기하지 않는다.** 파일이 사라졌거나 저장소가
/// 죽어도 기본음으로 떨어진다 — 음원까지 골라둔 사용자의 알림이 진동만
/// 남는 것은 너무 약한 결과다.
class FakeCustomSoundRepository implements CustomSoundRepository {
  String? pathToReturn;
  bool failOnResolve = false;
  final List<String> resolvedIds = [];

  @override
  Future<String?> resolvePlayablePath(String id) async {
    resolvedIds.add(id);
    if (failOnResolve) throw Exception('저장소 조회 실패');
    return pathToReturn;
  }

  @override
  Future<CustomSound> add({
    required String sourcePath,
    required String displayName,
    required Duration duration,
  }) => throw UnimplementedError();

  @override
  Future<int> count() async => 0;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<CustomSound>> findAll() async => const [];

  @override
  Future<CustomSound?> findById(String id) async => null;
}

void main() {
  late FakeCustomSoundRepository repo;
  late AlertSoundResolver resolver;

  setUp(() {
    repo = FakeCustomSoundRepository();
    resolver = AlertSoundResolver(repo);
  });

  test('프리셋은 asset 경로가 된다', () async {
    final source = await resolver.resolve(
      const PresetSound(SoundPreset.defaultTone),
    );

    expect(source, isA<AssetSound>());
    expect((source as AssetSound).assetPath, SoundPreset.defaultTone.assetPath);
  });

  test('프리셋은 저장소를 건드리지 않는다', () async {
    await resolver.resolve(const PresetSound(SoundPreset.defaultTone));

    expect(repo.resolvedIds, isEmpty, reason: '내장 음원에 파일 조회가 붙으면 발화가 그만큼 늦어진다');
  });

  test('커스텀 음원은 파일 경로가 된다', () async {
    repo.pathToReturn = '/data/sounds/u-1.mp3';

    final source = await resolver.resolve(const CustomSoundRef('u-1'));

    expect(source, isA<FileSound>());
    expect((source as FileSound).filePath, '/data/sounds/u-1.mp3');
    expect(repo.resolvedIds, ['u-1']);
  });

  test('파일이 없으면 기본음으로 떨어진다', () async {
    repo.pathToReturn = null;

    final source = await resolver.resolve(const CustomSoundRef('gone'));

    expect(
      source,
      isA<AssetSound>(),
      reason:
          '재생 단계에서 터뜨리면 "재시도 금지" 규칙에 걸려 진동만 남는다. '
          '파일 부재는 그것과 성격이 다른 실패다',
    );
    expect((source as AssetSound).assetPath, SoundPreset.defaultTone.assetPath);
  });

  test('저장소가 실패해도 기본음으로 떨어진다', () async {
    repo.failOnResolve = true;

    final source = await resolver.resolve(const CustomSoundRef('u-1'));

    expect(source, isA<AssetSound>());
    expect(
      (source as AssetSound).assetPath,
      SoundPreset.defaultTone.assetPath,
      reason: 'DB 조회 하나가 실패했다고 알림이 조용해지면 안 된다',
    );
  });
}
