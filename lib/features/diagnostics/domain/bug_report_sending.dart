import 'dart:ui' show Rect;

/// 문제 신고를 받는 주소 (이슈 #255)
const bugReportAddress = 'chan4760@naver.com';

/// 신고 메일이 어디로 열렸는가
enum BugReportOutcome {
  /// 받는 사람·제목·본문·첨부가 채워진 메일 작성 화면
  mailComposer,

  /// 메일 계정이 없어 공유 시트로 대신 열었다 — 받는 사람은 비어 있다
  shareSheet,

  /// 둘 다 열지 못했다
  failed,
}

/// 문제 신고를 메일(또는 공유 시트)로 넘기는 일 (이슈 #255)
///
/// 화면은 이 인터페이스만 안다 — 메일·공유 플러그인은 data 계층의 구현이
/// 맡는다 (docs/02-ARCHITECTURE.md 규칙 3, 아키텍처 검수 #276).
abstract interface class BugReportSending {
  /// [attachmentPath] 가 null 이면 기록 없이 본문만 보낸다
  Future<BugReportOutcome> send({
    required String subject,
    required String body,
    required Rect origin,
    String? attachmentPath,
    String? fallbackNotice,
  });

  /// 메일 본문 끝에 붙일 앱·기기 정보
  String describeDevice({
    required String appVersion,
    String? locale,
    String? device,
  });
}
