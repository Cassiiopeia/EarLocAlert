/// 로그 표기를 맞추는 공통 서식 (이슈 #127)
///
/// **읽는 사람이 형식을 외운다.** 같은 값이 파일마다 다르게 찍히면
/// 로그를 눈으로 훑을 수 없고, 다른 로그와 대조하지도 못한다.
library;

/// UUIDv7 앞 8자.
///
/// 전체를 쓰면 한 줄이 36자를 먹는데, 앞 8자면 같은 장소를 다른 로그와
/// 대조하기에 충분하다 — UUIDv7 은 상위 비트가 타임스탬프라 같은 시각에
/// 만들어진 것끼리도 앞자리가 갈린다.
String shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

/// 미터 표기. 소수점을 버린다 — GPS 정확도에 소수점은 의미가 없다.
String meters(double? value) =>
    value == null ? '?' : '${value.toStringAsFixed(0)}m';
