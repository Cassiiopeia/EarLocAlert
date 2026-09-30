/// 두 자리로 맞춘 숫자 — 시각·날짜 표기용 (`7` → `07`)
String twoDigits(int value) => value.toString().padLeft(2, '0');
