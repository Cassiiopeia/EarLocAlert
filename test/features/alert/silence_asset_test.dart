import 'dart:io';
import 'dart:typed_data';

import 'package:ear_loc_alert/features/alert/data/alert_sound_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// 무음 유지 음원이 정말 무음인지 지킨다 (이슈 #241, CLAUDE.md 규칙 2)
///
/// 이 파일은 이어폰 없이도 재생된다. 표본 하나라도 0 이 아니면 스피커로
/// 소리가 새는 것이고, 그 순간 이 앱은 존재 이유를 잃는다.
void main() {
  test('무음 유지 음원의 PCM 표본은 전부 0 이다', () {
    final bytes = File(
      AlertSoundServiceImpl.silenceAssetPath,
    ).readAsBytesSync();
    final data = ByteData.sublistView(bytes);

    // RIFF/WAVE 의 data 청크를 찾는다 — 헤더 길이를 가정하지 않는다
    var offset = 12;
    int? start;
    int? length;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      if (id == 'data') {
        start = offset + 8;
        length = size;
        break;
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }

    expect(start, isNotNull, reason: 'data 청크가 없다');
    expect(length, greaterThan(0));
    final samples = bytes.sublist(start!, start + length!);
    expect(samples.every((b) => b == 0), isTrue, reason: '들리는 표본이 있다');
  });
}
