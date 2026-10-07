import 'dart:io';

import 'package:ear_loc_alert/app/background/background_alert_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이슈 #221 — iOS 백그라운드 알림의 무음 소리 파일을 지킨다.
///
/// 지정한 파일이 번들에 없으면 iOS 는 **기본 알림음을 스피커로** 낸다.
/// 이 앱이 절대 하면 안 되는 일이라 파일·프로젝트 등록·무음 여부를 막는다.
void main() {
  final file = File('ios/Runner/$iosSilentHapticSound');

  test('소리 파일이 Runner 폴더에 있다', () {
    expect(file.existsSync(), isTrue);
  });

  test('Xcode 프로젝트의 리소스로 등록돼 있다', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      project,
      contains('$iosSilentHapticSound in Resources */,'),
      reason: '등록이 빠지면 번들에 안 들어가 기본 알림음이 난다',
    );
  });

  test('파일 내용이 전부 무음이다', () {
    final bytes = file.readAsBytesSync();
    // CAF 의 오디오 데이터 청크('data') 뒤 4바이트 편집 횟수를 건너뛴 부분
    final marker = 'data'.codeUnits;
    var start = -1;
    for (var i = 0; i + 4 <= bytes.length; i++) {
      if (bytes[i] == marker[0] &&
          bytes[i + 1] == marker[1] &&
          bytes[i + 2] == marker[2] &&
          bytes[i + 3] == marker[3]) {
        start = i;
      }
    }
    expect(start, isNonNegative, reason: 'CAF data 청크가 없다');
    // 청크 이름(4) + 크기(8) + 편집 횟수(4)
    final samples = bytes.sublist(start + 16);
    expect(samples, isNotEmpty);
    expect(samples.every((b) => b == 0), isTrue, reason: '들리는 소리가 섞였다');
  });
}
