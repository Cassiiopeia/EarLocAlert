import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_sound.freezed.dart';

/// 사용자가 올린 알림음 (이슈 #121)
///
/// **파일 경로를 담지 않는다.** [id] 와 [extension] 으로 재생 직전에
/// 조립한다 — 절대경로를 저장하면 앱 재설치·OS 업데이트로 컨테이너 경로가
/// 바뀌었을 때 전부 죽는다 (`CustomSoundFile.resolve` 참조).
@freezed
abstract class CustomSound with _$CustomSound {
  const factory CustomSound({
    /// uuid. 저장된 파일 이름이기도 하다
    required String id,

    /// 사용자가 고른 원본 파일명. 화면에 보여주는 이름이다
    required String displayName,

    /// 소문자 확장자 (`mp3` 등). 경로 조립에 쓴다.
    ///
    /// `extension` 이 아닌 것은 Dart 내장 식별자와 겹쳐
    /// 생성 코드에서 혼란을 주기 때문이다.
    required String fileExtension,

    /// 등록할 때 실제 재생을 시도해서 얻은 길이
    required Duration duration,

    required int sizeBytes,

    /// UTC (docs/04-CONVENTIONS.md)
    required DateTime createdAt,
  }) = _CustomSound;
}
