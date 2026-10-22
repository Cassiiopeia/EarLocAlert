import 'package:in_app_review/in_app_review.dart';

import '../../../core/diagnostics/diagnostics.dart';

/// 스토어 공식 인앱 후기 창 (#296): Android Play In-App Review, iOS SKStoreReviewController
/// 실제 표시 여부는 스토어가 정함(할당량) — 앱은 요청만 하고 결과를 알 수 없음
class StoreReviewService {
  const StoreReviewService();

  /// 요청했으면 true. 이 기기·설치에서 지원하지 않거나 실패하면 false
  Future<bool> request() async {
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) {
        Diagnostics.log('review', 'request skipped reason=not_available');
        return false;
      }
      await review.requestReview();
      Diagnostics.log('review', 'requested');
      return true;
    } on Object catch (error) {
      Diagnostics.log('review', 'request failed error=$error');
      return false;
    }
  }
}
