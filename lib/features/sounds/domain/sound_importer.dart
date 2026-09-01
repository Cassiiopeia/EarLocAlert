import '../../../core/diagnostics/diagnostics.dart';
import 'custom_sound.dart';
import 'custom_sound_repository.dart';
import 'sound_file_picker.dart';
import 'sound_probe.dart';
import 'sound_validator.dart';

/// 음원 등록 결과 (이슈 #121)
sealed class SoundImportOutcome {
  const SoundImportOutcome();
}

/// 사용자가 선택기를 닫았다. 아무 일도 일어나지 않는다
final class SoundImportCancelled extends SoundImportOutcome {
  const SoundImportCancelled();
}

final class SoundImported extends SoundImportOutcome {
  const SoundImported(this.sound);

  final CustomSound sound;
}

/// 검증에 걸렸다. [error] 가 이유를 담는다
final class SoundImportRejected extends SoundImportOutcome {
  const SoundImportRejected(this.error);

  final SoundImportError error;
}

/// 복사나 저장이 실패했다 — 사용자 잘못이 아니다
final class SoundImportFailed extends SoundImportOutcome {
  const SoundImportFailed(this.reason);

  final String reason;
}

/// 파일 선택 → 검증 → 등록 (이슈 #121)
///
/// **화면이 이 순서를 알 필요가 없게 한다.** 검증을 화면에 두면
/// 순서가 흐트러지기 쉽고(비싼 디코딩을 먼저 돌린다든지), 그 로직을
/// 테스트하려면 위젯을 띄워야 한다.
///
/// 순수 조율이라 인터페이스만 알면 된다 — 파일 시스템도 플러그인도 모른다.
class SoundImporter {
  const SoundImporter({
    required SoundFilePicker picker,
    required SoundProbe probe,
    required CustomSoundRepository repository,
  }) : _picker = picker,
       _probe = probe,
       _repository = repository;

  final SoundFilePicker _picker;
  final SoundProbe _probe;
  final CustomSoundRepository _repository;

  Future<SoundImportOutcome> import() async {
    final picked = await _picker.pick();
    if (picked == null) return const SoundImportCancelled();

    // **싼 것부터 본다.** 개수·형식·크기를 통과한 것만 디코딩한다 —
    // 5MB 파일을 열어보고 나서 "개수가 찼습니다"라고 하면 낭비다.
    final rejected = SoundValidator.checkBeforeProbe(
      fileName: picked.displayName,
      sizeBytes: picked.sizeBytes,
      currentCount: await _repository.count(),
    );
    if (rejected != null) {
      Diagnostics.log(
        'sound',
        '음원 등록 거부 name=${picked.displayName} '
            '크기=${picked.sizeBytes}B 사유=${rejected.runtimeType}',
      );
      return SoundImportRejected(rejected);
    }

    // 확장자만 믿지 않는다 — 실제로 재생되는지 확인한다
    final duration = await _probe.probe(picked.path);
    final probeRejected = SoundValidator.checkProbeResult(duration);
    if (probeRejected != null) {
      Diagnostics.log(
        'sound',
        '음원 등록 거부 name=${picked.displayName} '
            '길이=${duration?.inMilliseconds}ms 사유=${probeRejected.runtimeType}',
      );
      return SoundImportRejected(probeRejected);
    }

    try {
      final sound = await _repository.add(
        sourcePath: picked.path,
        displayName: picked.displayName,
        duration: duration!,
      );
      return SoundImported(sound);
    } on Object catch (error) {
      // 복사·저장 실패는 사용자가 고칠 수 있는 것이 아니다.
      // 거부와 구분해서 다른 문구를 보여준다.
      Diagnostics.log('sound', '음원 등록 실패 name=${picked.displayName} 사유=$error');
      return SoundImportFailed('$error');
    }
  }
}
