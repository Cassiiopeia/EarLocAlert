# =============================================================================
# OAuth 설정 마법사 - SHA-1 인증서 지문 생성 스크립트 (Windows PowerShell)
# =============================================================================
# 이 스크립트는 Android Keystore에서 SHA-1 인증서 지문을 추출합니다.
# 카카오 키 해시 및 Google/Firebase SHA-1 지문 생성에 사용됩니다.
# Debug keystore 자동 생성 및 Release keystore 생성 옵션 지원
# Usage: powershell -ExecutionPolicy Bypass -File oauth-wizard-get-sha1.ps1 [keystore_type] [keystore_path] [alias] [password]
# =============================================================================

param(
    [string]$KeystoreType = "",
    [string]$KeystorePath = "",
    [string]$KeyAlias = "",
    [string]$KeystorePassword = ""
)

# Colors for output
function Write-Info {
    Write-Host "ℹ️  $args" -ForegroundColor Blue
}

function Write-Success {
    Write-Host "✅ $args" -ForegroundColor Green
}

function Write-Error-Custom {
    Write-Host "❌ $args" -ForegroundColor Red
}

function Write-Warning-Custom {
    Write-Host "⚠️  $args" -ForegroundColor Yellow
}

# Check if keytool is available
$keytoolPath = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytoolPath) {
    Write-Error-Custom "keytool을 찾을 수 없습니다."
    Write-Host ""
    Write-Host "Java JDK가 설치되어 있는지 확인하세요:"
    Write-Host "  Windows: https://adoptium.net/ 에서 JDK 다운로드"
    exit 1
}

# Function to create debug keystore
function Create-DebugKeystore {
    $debugKeystorePath = Join-Path $env:USERPROFILE ".android\debug.keystore"
    $debugDir = Join-Path $env:USERPROFILE ".android"
    
    # Create .android directory if it doesn't exist
    if (-not (Test-Path $debugDir)) {
        New-Item -ItemType Directory -Path $debugDir -Force | Out-Null
        Write-Info ".android 디렉토리 생성: $debugDir"
    }
    
    # Check if debug keystore already exists
    if (Test-Path $debugKeystorePath) {
        Write-Info "Debug keystore가 이미 존재합니다: $debugKeystorePath"
        return $true
    }
    
    Write-Info "Debug keystore 생성 중..."
    
    # Create debug keystore with standard Android debug credentials
    $keytoolArgs = @(
        "-genkey", "-v",
        "-keystore", $debugKeystorePath,
        "-alias", "androiddebugkey",
        "-storepass", "android",
        "-keypass", "android",
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-dname", "CN=Android Debug,O=Android,C=US"
    )
    
    & keytool $keytoolArgs 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Debug keystore 생성 완료: $debugKeystorePath"
        # Set permissions (read/write for owner only)
        $acl = Get-Acl $debugKeystorePath
        $permission = $env:USERNAME, "FullControl", "Allow"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.SetAccessRule($accessRule)
        Set-Acl $debugKeystorePath $acl
        return $true
    } else {
        Write-Error-Custom "Debug keystore 생성 실패"
        return $false
    }
}

# Function to create release keystore
function Create-ReleaseKeystore {
    param(
        [string]$KeystorePath,
        [string]$Alias,
        [string]$Password,
        [string]$CN = "Unknown",
        [string]$O = "Unknown",
        [string]$L = "Unknown",
        [string]$C = "KR"
    )
    
    Write-Info "Release keystore 생성 중..."
    Write-Host ""
    
    $dname = "CN=$CN, O=$O, L=$L, C=$C"
    
    # Create directory if it doesn't exist
    $keystoreDir = Split-Path $KeystorePath -Parent
    if (-not (Test-Path $keystoreDir)) {
        New-Item -ItemType Directory -Path $keystoreDir -Force | Out-Null
        Write-Info "디렉토리 생성: $keystoreDir"
    }
    
    # Create release keystore
    $keytoolArgs = @(
        "-genkey", "-v",
        "-keystore", $KeystorePath,
        "-alias", $Alias,
        "-storepass", $Password,
        "-keypass", $Password,
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-dname", $dname
    )
    
    & keytool $keytoolArgs 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Release keystore 생성 완료: $KeystorePath"
        # Set permissions (read/write for owner only)
        $acl = Get-Acl $KeystorePath
        $permission = $env:USERNAME, "FullControl", "Allow"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.SetAccessRule($accessRule)
        Set-Acl $KeystorePath $acl
        return $true
    } else {
        Write-Error-Custom "Release keystore 생성 실패"
        return $false
    }
}

# Keystore type selection
if ([string]::IsNullOrEmpty($KeystoreType)) {
    Write-Host ""
    Write-Info "Keystore 타입을 선택하세요:"
    Write-Host "  1) Debug keystore (개발/테스트용, 자동 생성)"
    Write-Host "  2) Release keystore (배포용)"
    Write-Host ""
    $KeystoreType = Read-Host "선택 (1 또는 2)"
    
    if ($KeystoreType -ne "1" -and $KeystoreType -ne "2") {
        Write-Error-Custom "잘못된 선택입니다."
        exit 1
    }
}

# Handle Debug keystore
if ($KeystoreType -eq "1" -or $KeystoreType -eq "debug" -or $KeystoreType -eq "Debug") {
    $KeystoreType = "debug"
    $KeystorePath = Join-Path $env:USERPROFILE ".android\debug.keystore"
    $KeyAlias = "androiddebugkey"
    $KeystorePassword = "android"
    
    # Create debug keystore if it doesn't exist
    if (-not (Test-Path $KeystorePath)) {
        if (-not (Create-DebugKeystore)) {
            exit 1
        }
    }
    
    Write-Info "Debug keystore 사용: $KeystorePath"
    
# Handle Release keystore
} elseif ($KeystoreType -eq "2" -or $KeystoreType -eq "release" -or $KeystoreType -eq "Release") {
    $KeystoreType = "release"
    
    # Get keystore path
    if ([string]::IsNullOrEmpty($KeystorePath)) {
        Write-Host ""
        Write-Info "Release keystore 파일 경로를 입력하세요:"
        Write-Host "  예시: android\app\keystore\key.jks"
        $KeystorePath = Read-Host "Keystore 경로"
    }
    
    # Expand environment variables
    $KeystorePath = [System.Environment]::ExpandEnvironmentVariables($KeystorePath)
    
    # Check if keystore exists, if not, ask to create
    if (-not (Test-Path $KeystorePath)) {
        Write-Host ""
        Write-Warning-Custom "Keystore 파일을 찾을 수 없습니다: $KeystorePath"
        $createKeystore = Read-Host "새로 생성하시겠습니까? (y/n)"
        
        if ($createKeystore -eq "y" -or $createKeystore -eq "Y") {
            # Get alias
            if ([string]::IsNullOrEmpty($KeyAlias)) {
                $KeyAlias = Read-Host "Key alias (기본값: release-key)"
                if ([string]::IsNullOrEmpty($KeyAlias)) {
                    $KeyAlias = "release-key"
                }
            }
            
            # Get password
            if ([string]::IsNullOrEmpty($KeystorePassword)) {
                $securePassword = Read-Host -AsSecureString "Keystore 비밀번호"
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
                $KeystorePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                
                $securePasswordConfirm = Read-Host -AsSecureString "비밀번호 확인"
                $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordConfirm)
                $passwordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
                
                if ($KeystorePassword -ne $passwordConfirm) {
                    Write-Error-Custom "비밀번호가 일치하지 않습니다."
                    exit 1
                }
            }
            
            # Get certificate info
            $CN = Read-Host "인증서 CN (Common Name, 기본값: Unknown)"
            if ([string]::IsNullOrEmpty($CN)) { $CN = "Unknown" }
            $O = Read-Host "인증서 O (Organization, 기본값: Unknown)"
            if ([string]::IsNullOrEmpty($O)) { $O = "Unknown" }
            $L = Read-Host "인증서 L (Location, 기본값: Unknown)"
            if ([string]::IsNullOrEmpty($L)) { $L = "Unknown" }
            $C = Read-Host "인증서 C (Country, 기본값: KR)"
            if ([string]::IsNullOrEmpty($C)) { $C = "KR" }
            
            if (-not (Create-ReleaseKeystore -KeystorePath $KeystorePath -Alias $KeyAlias -Password $KeystorePassword -CN $CN -O $O -L $L -C $C)) {
                exit 1
            }
        } else {
            Write-Error-Custom "Keystore 파일이 필요합니다."
            exit 1
        }
    } else {
        # Get alias if not provided
        if ([string]::IsNullOrEmpty($KeyAlias)) {
            Write-Host ""
            Write-Info "Key alias를 입력하세요:"
            $KeyAlias = Read-Host "Key alias"
        }
        
        # Get password if not provided
        if ([string]::IsNullOrEmpty($KeystorePassword)) {
            Write-Host ""
            Write-Info "Keystore 비밀번호를 입력하세요:"
            Write-Host "  (입력 내용이 화면에 표시되지 않습니다)"
            $securePassword = Read-Host -AsSecureString "Keystore 비밀번호"
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            $KeystorePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        }
    }
} else {
    Write-Error-Custom "잘못된 keystore 타입입니다: $KeystoreType"
    exit 1
}

# Extract SHA-1 fingerprint
Write-Info "SHA-1 인증서 지문 추출 중..."

try {
    $keytoolOutput = & keytool -list -v -keystore $KeystorePath -alias $KeyAlias -storepass $KeystorePassword 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "keytool 실행 실패"
        Write-Host $keytoolOutput
        exit 1
    }
    
    # Find SHA1 line
    $sha1Line = $keytoolOutput | Select-String -Pattern "SHA1:" -CaseSensitive
    
    if (-not $sha1Line) {
        Write-Error-Custom "SHA-1 지문을 찾을 수 없습니다."
        Write-Host ""
        Write-Host "확인 사항:"
        Write-Host "  1. Keystore 파일 경로가 올바른지 확인"
        Write-Host "  2. Key alias가 올바른지 확인"
        Write-Host "  3. Keystore 비밀번호가 올바른지 확인"
        exit 1
    }
    
    # Extract SHA-1 value
    $sha1Value = ($sha1Line -split "SHA1:")[1].Trim()
    $sha1Value = $sha1Value.ToUpper()
    
    if ([string]::IsNullOrEmpty($sha1Value)) {
        Write-Error-Custom "SHA-1 값을 파싱할 수 없습니다."
        exit 1
    }
    
    # Convert to formats
    $sha1WithColons = $sha1Value
    $sha1WithoutColons = $sha1Value -replace ':', ''
    
    # Generate Kakao Key Hash (Base64 encoded SHA-1 without colons)
    # Convert hex string to bytes, then to base64
    $hexBytes = [System.Convert]::FromHexString($sha1WithoutColons)
    $kakaoKeyHash = [System.Convert]::ToBase64String($hexBytes)
    
    Write-Success "인증서 지문 추출 완료!"
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Keystore 정보" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    $keystoreTypeDisplay = if ($KeystoreType -eq "debug") { "Debug" } else { "Release" }
    Write-Host "타입: $keystoreTypeDisplay keystore"
    Write-Host "경로: $KeystorePath"
    Write-Host "Alias: $KeyAlias"
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "카카오 개발자 콘솔용 키 해시 (Key Hash)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host $kakaoKeyHash -ForegroundColor Yellow
    Write-Host ""
    Write-Host "설정 위치:"
    Write-Host "1. https://developers.kakao.com 접속"
    Write-Host "2. 내 애플리케이션 → 앱 선택"
    Write-Host "3. 플랫폼 → Android"
    Write-Host "4. 키 해시 추가에 위 값 입력"
    Write-Host ""
    if ($KeystoreType -eq "debug") {
        Write-Host "💡 참고: 이 값은 개발 중 테스트용입니다." -ForegroundColor Yellow
        Write-Host "   실제 배포 시 Release keystore의 키 해시도 등록해야 합니다." -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "구글/Firebase용 SHA-1 인증서 지문" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SHA1: $sha1WithColons" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "콜론 없는 버전 (Firebase Console):"
    Write-Host $sha1WithoutColons -ForegroundColor Yellow
    Write-Host ""
    Write-Host "설정 위치:"
    Write-Host "1. Firebase Console (https://console.firebase.google.com)"
    Write-Host "2. 프로젝트 설정 → 일반 → 내 앱 → Android 앱"
    Write-Host "3. SHA 인증서 지문 추가에 위 SHA-1 값 입력"
    Write-Host ""
    if ($KeystoreType -eq "debug") {
        Write-Host "💡 참고: 이 값은 개발 중 테스트용입니다." -ForegroundColor Yellow
        Write-Host "   실제 배포 시 Release keystore의 SHA-1 지문도 등록해야 합니다." -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host "==========================================" -ForegroundColor Cyan
    
} catch {
    Write-Error-Custom "오류 발생: $_"
    exit 1
}

