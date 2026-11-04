import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/cloud_sync.dart';

/// [CloudSyncAccount] google_sign_in 구현 (#330): 범위는 drive.appdata 하나
class GoogleCloudSyncAccount implements CloudSyncAccount {
  GoogleCloudSyncAccount({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(scopes: const [DriveApi.driveAppdataScope]);

  final GoogleSignIn _googleSignIn;

  @override
  Future<String?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      Diagnostics.log(
        'cloudsync',
        'sign in result=${account == null ? 'cancelled' : 'ok'} '
            'account=${_domainOf(account?.email)}',
      );
      return account?.email;
    } on Object catch (error) {
      // 콘솔 설정(OAuth 클라이언트·SHA-1)이 어긋나면 여기서 실패함 > 사유를 남김
      Diagnostics.log('cloudsync', 'sign in failed error=$error');
      return null;
    }
  }

  @override
  Future<String?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account?.email;
    } on Object catch (error) {
      Diagnostics.log('cloudsync', 'silent sign in failed error=$error');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // disconnect: 앱 권한까지 반납 (다음 연결 때 범위 동의를 다시 받음)
      await _googleSignIn.disconnect();
    } on Object catch (error) {
      Diagnostics.log('cloudsync', 'sign out failed error=$error');
      await _googleSignIn.signOut();
    }
  }

  @override
  Future<Map<String, String>?> authHeaders() async {
    try {
      final account =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      return await account?.authHeaders;
    } on Object catch (error) {
      Diagnostics.log('cloudsync', 'auth headers failed error=$error');
      return null;
    }
  }

  /// 로그에는 계정 도메인만 (user@gmail.com > gmail.com)
  static String _domainOf(String? email) {
    if (email == null) return 'none';
    final at = email.indexOf('@');
    return at < 0 ? 'unknown' : email.substring(at + 1);
  }
}
