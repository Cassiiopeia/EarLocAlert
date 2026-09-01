import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 사용자 음원 파일의 위치 (이슈 #121)
///
/// **경로를 DB 에 저장하지 않고 여기서 조립한다.** 절대경로를 저장하면
/// 앱 재설치·OS 업데이트로 컨테이너 경로가 바뀌었을 때 전부 죽는다.
/// `DiagnosticLogFile` 이 같은 이유로 같은 모양을 하고 있다.
///
/// **support 디렉토리를 쓴다.** 앱 안에 쓰이는 디렉토리가 셋인데 목적이
/// 다르다 — DB 는 documents, 공유 스냅샷은 temporary, 그리고 여기.
/// 사용자 음원은 영구 보존이 필요하고(temporary 는 OS 가 지운다),
/// 파일 앱에 노출될 이유가 없다(iOS 의 documents 는 노출될 수 있다).
///
/// 진단 로그와 같은 디렉토리 아래지만 `sounds/` 하위로 분리되어 섞이지 않는다.
abstract final class CustomSoundFile {
  static const dirName = 'sounds';

  /// 없으면 만든다.
  static Future<Directory> resolveDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// `<applicationSupport>/sounds/<id>.<확장자>`
  ///
  /// 파일이 실제로 있는지는 확인하지 않는다 — 호출자가 판단한다.
  static Future<File> resolve(String id, String fileExtension) async {
    final dir = await resolveDir();
    return File(p.join(dir.path, '$id.$fileExtension'));
  }
}
