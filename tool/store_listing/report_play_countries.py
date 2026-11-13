"""Play 트랙별 출시 국가 조회 (#369, 읽기 전용): 서비스 계정 키 > 임시 편집 > countryavailability > 편집 삭제

사용: python3 tool/store_listing/report_play_countries.py <서비스 계정 JSON> <패키지 이름>
조회 실패는 기록만 남기고 0으로 끝남 (등록정보 업로드를 막지 않음)
"""

import sys

from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

API_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
# 출시 국가를 볼 트랙 (production 이 실제 사용자 노출 범위)
TRACKS = ["production", "beta", "alpha", "internal"]


def main() -> int:
    key_path, package_name = sys.argv[1], sys.argv[2]
    credentials = service_account.Credentials.from_service_account_file(key_path, scopes=SCOPES)
    session = AuthorizedSession(credentials)
    edit = session.post(f"{API_BASE}/{package_name}/edits")
    if not edit.ok:
        print(f"[play countries] edit open failed status={edit.status_code}")
        return 0
    edit_id = edit.json()["id"]
    try:
        for track in TRACKS:
            response = session.get(f"{API_BASE}/{package_name}/edits/{edit_id}/countryAvailability/{track}")
            if not response.ok:
                print(f"[play countries] track={track} unavailable status={response.status_code}")
                continue
            body = response.json()
            countries = sorted(country.get("countryCode", "?") for country in body.get("countries", []))
            print(
                f"[play countries] track={track} count={len(countries)} "
                f"rest_of_world={body.get('restOfWorld', False)} countries={','.join(countries)}"
            )
    finally:
        # 읽기만 했으므로 편집은 버림 (성공·실패 공통)
        session.delete(f"{API_BASE}/{package_name}/edits/{edit_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
