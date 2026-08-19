/// 앱 버전 (이슈 #104)
///
/// **순수 값이다.** 문자열 비교로는 `1.10.0` 이 `1.9.0` 보다 작다고 나온다 —
/// 그러면 새 버전이 나와도 사용자에게 영영 보이지 않는다.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// `v1.7.2`, `1.7.2`, `1.7.2+84`, `v1.7.2-beta` 를 모두 받는다.
  ///
  /// 태그 표기는 사람이 손으로 붙이는 값이라 흔들린다. 파싱에 실패하면
  /// null 이고, 호출자는 **업데이트 없음으로 취급한다** — 못 읽은 버전을
  /// 새 버전이라고 알리면 받을 수 없는 업데이트를 권하게 된다.
  static AppVersion? parse(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}
