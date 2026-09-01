import 'package:file_picker/file_picker.dart';

import '../domain/sound_file_picker.dart';

/// `file_picker` 기반 파일 선택 (이슈 #121)
///
/// **SAF / DocumentPicker 를 쓴다.** 패키지 매니페스트에 `uses-permission`
/// 이 하나도 없어(`<queries>` 뿐이다) 앱의 권한 목록이 늘지 않는다 —
/// 심사 항목이 늘어나지 않는다는 뜻이다.
///
/// 11.x 부터 `FilePicker.platform` 이 사라지고 static 호출이 됐다.
class FilePickerSoundSource implements SoundFilePicker {
  const FilePickerSoundSource();

  @override
  Future<PickedSoundFile?> pick() async {
    try {
      final result = await FilePicker.pickFiles(
        // 오디오만 보여준다. 형식 검증은 그래도 따로 한다 —
        // 이 필터는 MIME 기준이라 우리가 재생 못 하는 것도 통과한다
        type: FileType.audio,
        // **파일 내용을 메모리에 올리지 않는다.** 5MB 상한이 있어도
        // 선택 직후에는 아직 크기를 모른다
        withData: false,
      );

      final file = result?.files.singleOrNull;
      if (file == null) return null;

      final path = file.path;
      if (path == null) return null;

      return PickedSoundFile(
        path: path,
        displayName: file.name,
        sizeBytes: file.size,
      );
    } on Object {
      // 선택기를 열지 못하는 것은 등록 실패일 뿐 앱이 죽을 일이 아니다.
      // 호출자는 null 을 취소와 같게 다룬다.
      return null;
    }
  }
}
