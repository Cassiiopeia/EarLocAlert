import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// 잠금 화면 알람 소리가 들리지 않는 크기인지 지킨다 (이슈 #252, CLAUDE.md 규칙 2)
///
/// AlarmKit 알람은 스피커로 울린다. 이 파일이 들리면 이어폰 허용 목록 판정을 우회한다.
/// 완전한 0 이면 알람 진동이 안 났으므로(실기기) 0 도 아니어야 한다.
void main() {
  test('알람 소리는 들리지 않을 만큼 작지만 0 은 아니다', () {
    final bytes = File('ios/Runner/alarm_haptic.caf').readAsBytesSync();
    // CAF: 'data' 청크 = id(4) + 크기(8) + 편집 횟수(4) 뒤에 표본
    var offset = 8;
    int? start;
    while (offset + 12 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = ByteData.sublistView(
        bytes,
        offset + 4,
        offset + 12,
      ).getUint64(0, Endian.big);
      if (id == 'data') {
        start = offset + 12 + 4;
        break;
      }
      offset += 12 + size;
    }
    expect(start, isNotNull, reason: 'data 청크가 없다');

    final samples = Int16List.sublistView(
      Uint8List.fromList(
        bytes.sublist(start!, bytes.length - (bytes.length - start) % 2),
      ),
    );
    final peak = samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(0), reason: '완전한 0 이면 알람 진동이 안 난다');
    expect(peak, lessThanOrEqualTo(8), reason: '-72dBFS 보다 크면 들릴 수 있다');
  });
}
