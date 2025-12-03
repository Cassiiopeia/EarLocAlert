/**
 * Flutter Android Play Store 통합 마법사
 * 파일 업로드, Base64 변환, localStorage 진행률 저장 포함
 */

// ============================================
// State Management
// ============================================

const state = {
    currentStep: 1,
    totalSteps: 7,
    projectPath: '',
    // Project Info
    applicationId: '',
    versionName: '',
    versionCode: '',
    gradleType: 'kts',
    // Keystore
    keyAlias: '',
    storePassword: '',
    keyPassword: '',
    keystoreBase64: '',
    // Certificate Info
    certCN: '',
    certO: '',
    certL: '',
    certC: 'KR',
    // Service Account
    serviceAccountBase64: '',
    // Optional
    googleServicesJson: '',
    envFileContent: ''
};

// ============================================
// LocalStorage Functions
// ============================================

const STORAGE_KEY = 'flutter_playstore_wizard_state';
const STORAGE_WARNING_KEY = 'flutter_playstore_wizard_security_warning_dismissed';

function saveState() {
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
        console.warn('localStorage 저장 실패:', e);
    }
}

function loadState() {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            const savedState = JSON.parse(saved);
            // 현재 코드의 totalSteps 보존 (버전 업그레이드 시 캐시된 값 무시)
            const currentTotalSteps = state.totalSteps;
            Object.assign(state, savedState);
            state.totalSteps = currentTotalSteps;

            // currentStep이 totalSteps를 초과하면 보정
            if (state.currentStep > state.totalSteps) {
                state.currentStep = state.totalSteps;
            }

            restoreUIFromState();
            return true;
        }
    } catch (e) {
        console.warn('localStorage 로드 실패:', e);
    }
    return false;
}

function clearState() {
    try {
        localStorage.removeItem(STORAGE_KEY);
    } catch (e) {
        console.warn('localStorage 삭제 실패:', e);
    }
}

function restoreUIFromState() {
    // 입력 필드 복원
    const inputs = {
        'projectPath': state.projectPath,
        'keyAlias': state.keyAlias,
        'storePassword': state.storePassword,
        'keyPassword': state.keyPassword,
        'certCN': state.certCN,
        'certO': state.certO,
        'certL': state.certL,
        'certC': state.certC,
        'envFileContent': state.envFileContent
    };

    Object.entries(inputs).forEach(([id, value]) => {
        const el = document.getElementById(id);
        if (el && value) el.value = value;
    });

    // 파일 업로드 상태 복원
    if (state.keystoreBase64) {
        const upload = document.getElementById('keystoreUpload');
        if (upload) {
            upload.classList.add('has-file');
            const p = upload.querySelector('p');
            if (p) p.textContent = '✅ Keystore 파일 로드됨';
        }
        const result = document.getElementById('keystoreBase64Result');
        if (result) {
            result.classList.remove('hidden');
            const pre = document.getElementById('keystoreBase64');
            if (pre) pre.textContent = state.keystoreBase64;
        }
    }

    if (state.serviceAccountBase64) {
        const upload = document.getElementById('serviceAccountUpload');
        if (upload) {
            upload.classList.add('has-file');
            const p = upload.querySelector('p');
            if (p) p.textContent = '✅ Service Account 파일 로드됨';
        }
        const result = document.getElementById('serviceAccountBase64Result');
        if (result) {
            result.classList.remove('hidden');
            const pre = document.getElementById('serviceAccountBase64');
            if (pre) pre.textContent = state.serviceAccountBase64;
        }
    }

    // Project Info 복원
    if (state.applicationId) {
        const detected = document.getElementById('detectedInfo');
        if (detected) detected.classList.remove('hidden');
        setElementText('detectedAppId', state.applicationId);
        setElementText('detectedVersion', state.versionName);
        setElementText('detectedVersionCode', state.versionCode);
        setElementText('detectedGradleType', state.gradleType);
    }
}

// ============================================
// Security Warning
// ============================================

function showSecurityWarning() {
    const dismissed = localStorage.getItem(STORAGE_WARNING_KEY);
    if (!dismissed) {
        const warning = document.getElementById('securityWarning');
        if (warning) {
            warning.classList.remove('hidden');
        }
    }
}

function closeSecurityWarning() {
    const warning = document.getElementById('securityWarning');
    if (warning) {
        warning.classList.add('hidden');
        localStorage.setItem(STORAGE_WARNING_KEY, 'true');
    }
}

// ============================================
// DOM Utility Functions
// ============================================

function $(selector) {
    return document.querySelector(selector);
}

function $$(selector) {
    return document.querySelectorAll(selector);
}

function getInputValue(id) {
    const element = document.getElementById(id);
    return element?.value?.trim() || '';
}

function setElementText(id, text) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = text;
    }
}

function setElementHtml(id, html) {
    const element = document.getElementById(id);
    if (element) {
        element.innerHTML = html;
    }
}

// ============================================
// File Upload & Base64 Conversion
// ============================================

function fileToBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            resolve(base64);
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
    });
}

// Keystore 파일 업로드
async function handleKeystoreUpload(input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.jks') && !file.name.endsWith('.keystore')) {
        showToast('⚠️ .jks 또는 .keystore 파일만 업로드 가능합니다');
        return;
    }

    try {
        state.keystoreBase64 = await fileToBase64(file);

        document.getElementById('keystoreBase64').textContent = state.keystoreBase64;
        document.getElementById('keystoreBase64Result').classList.remove('hidden');
        document.getElementById('keystoreUpload').classList.add('has-file');
        document.getElementById('keystoreUpload').querySelector('p').textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;

        saveState();
        showToast('✅ Keystore 파일 업로드 완료');
    } catch (error) {
        showToast('❌ 파일 읽기 실패: ' + error.message);
    }
}

// Service Account JSON 업로드
async function handleServiceAccountUpload(input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.json')) {
        showToast('⚠️ .json 파일만 업로드 가능합니다');
        return;
    }

    try {
        const reader = new FileReader();
        reader.onload = function(e) {
            state.serviceAccountBase64 = btoa(e.target.result);

            document.getElementById('serviceAccountBase64').textContent = state.serviceAccountBase64;
            document.getElementById('serviceAccountBase64Result').classList.remove('hidden');
            document.getElementById('serviceAccountUpload').classList.add('has-file');
            document.getElementById('serviceAccountUpload').querySelector('p').textContent = `✅ ${file.name}`;

            saveState();
            showToast('✅ Service Account 파일 업로드 완료');
        };
        reader.readAsText(file);
    } catch (error) {
        showToast('❌ 파일 읽기 실패: ' + error.message);
    }
}

// Google Services JSON 업로드
function handleGoogleServicesUpload(input) {
    const file = input.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function(e) {
        state.googleServicesJson = e.target.result;
        document.getElementById('googleServicesResult').classList.remove('hidden');
        saveState();
        showToast('✅ google-services.json 업로드 완료');
    };
    reader.readAsText(file);
}

// Drag & Drop 설정
function setupDragAndDrop() {
    document.querySelectorAll('.file-upload').forEach(el => {
        el.addEventListener('dragover', (e) => {
            e.preventDefault();
            el.classList.add('dragover');
        });

        el.addEventListener('dragleave', () => {
            el.classList.remove('dragover');
        });

        el.addEventListener('drop', (e) => {
            e.preventDefault();
            el.classList.remove('dragover');
            const input = el.querySelector('input');
            if (input && e.dataTransfer.files.length > 0) {
                input.files = e.dataTransfer.files;
                input.dispatchEvent(new Event('change'));
            }
        });
    });
}

// ============================================
// Folder Selection (File System Access API)
// ============================================

async function selectProjectFolder() {
    if ('showDirectoryPicker' in window) {
        try {
            const dirHandle = await window.showDirectoryPicker();
            const projectPath = dirHandle.name;

            const input = document.getElementById('projectPath');
            if (input) {
                input.value = `선택된 폴더: ${projectPath} (터미널에서 실제 경로를 사용하세요)`;
                input.placeholder = '선택된 폴더를 확인하고 실제 경로를 입력하세요';
            }

            updateProjectCommands(projectPath);
            showToast(`폴더 "${projectPath}" 선택됨`);
        } catch (err) {
            if (err.name !== 'AbortError') {
                console.error('폴더 선택 오류:', err);
                showToast('폴더 선택에 실패했습니다. 경로를 직접 입력해주세요.');
            }
        }
    } else {
        showToast('이 브라우저는 폴더 선택을 지원하지 않습니다.');
        const input = document.getElementById('projectPath');
        if (input) input.focus();
    }
}

function updateProjectCommands(path) {
    const macCommand = document.getElementById('macCommand');
    const windowsCommand = document.getElementById('windowsCommand');

    if (!path || path.startsWith('선택된 폴더:')) {
        path = '/path/to/your/project';
    }

    const isWindowsPath = path.includes('\\') || /^[A-Za-z]:/.test(path);

    if (isWindowsPath) {
        const winPath = path.replace(/\//g, '\\');
        const unixPath = path.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, drive) => '/' + drive.toLowerCase());

        if (macCommand) macCommand.textContent = `cd "${unixPath}" && bash .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh`;
        if (windowsCommand) windowsCommand.textContent = `cd "${winPath}"; powershell -ExecutionPolicy Bypass -File .github\\util\\flutter\\playstore-wizard\\playstore-wizard-setup.ps1`;
    } else {
        const winPath = path.replace(/\//g, '\\');

        if (macCommand) macCommand.textContent = `cd "${path}" && bash .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh`;
        if (windowsCommand) windowsCommand.textContent = `cd "${winPath}"; powershell -ExecutionPolicy Bypass -File .github\\util\\flutter\\playstore-wizard\\playstore-wizard-setup.ps1`;
    }
}

// ============================================
// Clipboard Functions
// ============================================

async function copyToClipboard(text) {
    try {
        await navigator.clipboard.writeText(text);
        showToast('클립보드에 복사되었습니다!');
        return true;
    } catch (err) {
        // Fallback
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('클립보드에 복사되었습니다!');
        return true;
    }
}

function copyCode(button) {
    const codeBlock = button.closest('.code-block');
    const pre = codeBlock?.querySelector('pre');
    if (!pre) return;

    const text = pre.textContent || '';

    navigator.clipboard.writeText(text).then(() => {
        const originalText = button.textContent;
        button.textContent = '복사됨!';
        button.classList.add('bg-green-600');
        setTimeout(() => {
            button.textContent = originalText;
            button.classList.remove('bg-green-600');
        }, 2000);
    }).catch(() => {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('복사되었습니다!');
    });
}

function copySecret(name) {
    const value = state[name] || '';
    if (!value) {
        showToast('⚠️ 값이 비어있습니다');
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        showToast(`✅ ${name} 복사 완료!`);
    });
}

function showToast(message) {
    const existingToast = document.querySelector('.toast');
    if (existingToast) {
        existingToast.remove();
    }

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(() => {
        toast.classList.add('show');
    }, 10);

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ============================================
// Navigation Functions
// ============================================

function updateProgress() {
    $$('.step-indicator').forEach((indicator, index) => {
        const stepNum = index + 1;
        const circle = indicator.querySelector('.step-circle');
        const label = indicator.querySelector('span:last-child');

        if (stepNum < state.currentStep) {
            // 완료된 스텝
            circle.className = 'step-circle w-8 h-8 rounded-full bg-green-500 text-white flex items-center justify-center font-bold text-xs z-10 shadow-lg';
            circle.innerHTML = '✓';
            if (label) label.className = 'text-[9px] mt-1 text-green-400 text-center hidden md:block';
        } else if (stepNum === state.currentStep) {
            // 현재 스텝 - 파랑-보라 그라데이션
            circle.className = 'step-circle w-8 h-8 rounded-full bg-gradient-to-r from-blue-500 to-purple-500 text-white flex items-center justify-center font-bold text-xs z-10 shadow-lg shadow-blue-500/30';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-[9px] mt-1 text-blue-400 text-center hidden md:block';
        } else {
            // 아직 안 한 스텝
            circle.className = 'step-circle w-8 h-8 rounded-full bg-slate-700 text-slate-400 flex items-center justify-center font-bold text-xs z-10';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-[9px] mt-1 text-slate-500 text-center hidden md:block';
        }
    });
}

function showStep(stepNumber) {
    $$('.step-content').forEach(step => {
        step.classList.add('hidden');
        step.classList.remove('fade-in');
    });

    const currentStepElement = $(`.step-content[data-step="${stepNumber}"]`);
    if (currentStepElement) {
        currentStepElement.classList.remove('hidden');
        currentStepElement.classList.add('fade-in');
    }

    initializeStep(stepNumber);
}

function initializeStep(stepNumber) {
    switch (stepNumber) {
        case 2:
            // Keystore 생성
            restoreInputValues();
            break;
        case 3:
            // 서명 설정
            generateSigningConfig();
            break;
        case 4:
            // Service Account
            restoreInputValues();
            break;
        case 5:
            // Fastlane
            generateFastfileContent();
            break;
        case 6:
            // .gitignore
            break;
        case 7:
            // 완료
            generateFinalResult();
            break;
    }
}

function restoreInputValues() {
    const inputs = {
        'projectPath': state.projectPath,
        'keyAlias': state.keyAlias,
        'storePassword': state.storePassword,
        'keyPassword': state.keyPassword,
        'certCN': state.certCN,
        'certO': state.certO,
        'certL': state.certL,
        'certC': state.certC,
        'envFileContent': state.envFileContent
    };

    Object.entries(inputs).forEach(([id, value]) => {
        const el = document.getElementById(id);
        if (el && value) el.value = value;
    });
}

function nextStep() {
    saveCurrentStepData();

    if (state.currentStep < state.totalSteps) {
        state.currentStep++;
        showStep(state.currentStep);
        updateProgress();
        saveState();
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function prevStep() {
    if (state.currentStep > 1) {
        saveCurrentStepData();
        state.currentStep--;
        showStep(state.currentStep);
        updateProgress();
        saveState();
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function resetWizard() {
    if (confirm('모든 데이터를 초기화하시겠습니까?')) {
        Object.keys(state).forEach(key => {
            if (key === 'currentStep') state[key] = 1;
            else if (key === 'totalSteps') state[key] = 7;
            else if (key === 'certC') state[key] = 'KR';
            else if (key === 'gradleType') state[key] = 'kts';
            else state[key] = '';
        });

        clearState();

        // UI 초기화
        const inputs = ['projectPath', 'keyAlias', 'storePassword', 'keyPassword', 'certCN', 'certO', 'certL', 'certC', 'envFileContent'];
        inputs.forEach(id => {
            const input = document.getElementById(id);
            if (input) input.value = id === 'certC' ? 'KR' : '';
        });

        // 파일 업로드 상태 초기화
        document.querySelectorAll('.file-upload').forEach(el => {
            el.classList.remove('has-file');
            const p = el.querySelector('p');
            if (p && p.textContent.includes('✅')) {
                p.textContent = '클릭하거나 파일을 드래그하세요';
            }
        });

        // 결과 영역 숨기기
        document.querySelectorAll('[id$="Result"]').forEach(el => {
            el.classList.add('hidden');
        });

        showStep(1);
        updateProgress();
        showToast('마법사가 초기화되었습니다.');
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

// ============================================
// Data Management Functions
// ============================================

function saveCurrentStepData() {
    switch (state.currentStep) {
        case 1:
            state.projectPath = getInputValue('projectPath');
            if (state.projectPath.startsWith('선택된 폴더:')) {
                state.projectPath = '';
            }
            break;
        case 2:
            state.keyAlias = getInputValue('keyAlias');
            state.storePassword = getInputValue('storePassword');
            state.keyPassword = getInputValue('keyPassword');
            state.certCN = getInputValue('certCN');
            state.certO = getInputValue('certO');
            state.certL = getInputValue('certL');
            state.certC = getInputValue('certC') || 'KR';
            break;
        case 5:
            state.envFileContent = getInputValue('envFileContent');
            break;
    }

    saveState();
}

// ============================================
// Step 1: Parse Project Info
// ============================================

function parseProjectInfo() {
    const output = getInputValue('scriptOutput');

    if (!output) {
        // Manual entry fallback
        state.applicationId = 'com.example.app';
        state.versionName = '1.0.0';
        state.versionCode = '1';
        state.gradleType = 'kts';
    } else {
        try {
            const info = JSON.parse(output);
            state.applicationId = info.applicationId || 'com.example.app';
            state.versionName = info.versionName || '1.0.0';
            state.versionCode = info.versionCode?.toString() || '1';
            state.gradleType = info.gradleType || 'kts';
        } catch (e) {
            showToast('JSON 파싱 실패. 형식을 확인해주세요.');
            return;
        }
    }

    setElementText('detectedAppId', state.applicationId);
    setElementText('detectedVersion', state.versionName);
    setElementText('detectedVersionCode', state.versionCode);
    setElementText('detectedGradleType', state.gradleType);
    document.getElementById('detectedInfo').classList.remove('hidden');

    // Auto-generate key alias
    if (state.applicationId) {
        const suggestedAlias = state.applicationId.split('.').pop() + '-release-key';
        const aliasInput = document.getElementById('keyAlias');
        if (aliasInput && !aliasInput.value) {
            aliasInput.value = suggestedAlias;
            state.keyAlias = suggestedAlias;
        }
    }

    saveState();
    showToast('✅ 프로젝트 정보 파싱 완료');
}

// ============================================
// Step 2: Keytool Command Generation
// ============================================

function generateKeytoolCommand() {
    const alias = getInputValue('keyAlias') || 'release-key';
    const storePass = getInputValue('storePassword') || 'changeit';
    const keyPass = getInputValue('keyPassword') || storePass;
    const validity = getInputValue('validityDays') || '10000';

    const cn = getInputValue('certCN') || 'Unknown';
    const o = getInputValue('certO') || 'Unknown';
    const l = getInputValue('certL') || 'Unknown';
    const c = getInputValue('certC') || 'KR';

    state.keyAlias = alias;
    state.storePassword = storePass;
    state.keyPassword = keyPass;
    state.certCN = cn;
    state.certO = o;
    state.certL = l;
    state.certC = c;

    const dname = `CN=${cn}, O=${o}, L=${l}, C=${c}`;

    const command = `keytool -genkey -v \\
  -keystore release-key.jks \\
  -keyalg RSA \\
  -keysize 2048 \\
  -validity ${validity} \\
  -alias ${alias} \\
  -storepass "${storePass}" \\
  -keypass "${keyPass}" \\
  -dname "${dname}"`;

    setElementText('keytoolCommandText', command);
    document.getElementById('keytoolCommand').classList.remove('hidden');
    saveState();
}

// ============================================
// Step 3: Signing Config Generation
// ============================================

function generateSigningConfig() {
    const alias = state.keyAlias || 'release-key';
    const appId = state.applicationId || 'com.example.app';

    const signingCode = `import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties 파일 로드
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "${appId}"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // 서명 설정
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    defaultConfig {
        applicationId = "${appId}"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}`;

    const keyProperties = `storeFile=keystore/key.jks
storePassword=${state.storePassword || 'YOUR_STORE_PASSWORD'}
keyAlias=${alias}
keyPassword=${state.keyPassword || 'YOUR_KEY_PASSWORD'}`;

    setElementText('signingConfigCode', signingCode);
    setElementText('keyPropertiesContent', keyProperties);
}

// ============================================
// Step 5: Fastlane Content Generation
// ============================================

function generateFastfileContent() {
    const appId = state.applicationId || 'com.example.app';

    const fastfile = `# Play Store 내부 테스트 배포용 Fastfile
# 경로: android/fastlane/Fastfile.playstore

default_platform(:android)

platform :android do
  desc "Play Store 내부 테스트로 배포"
  lane :deploy_internal do
    # 환경 변수
    aab_path = ENV["AAB_PATH"] || "../build/app/outputs/bundle/release/app-release.aab"
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"

    puts "========================================="
    puts "Play Store 내부 테스트 배포 시작"
    puts "========================================="
    puts "AAB 경로: #{aab_path}"
    puts "Service Account: #{json_key}"

    # AAB 파일 확인
    unless File.exist?(aab_path)
      UI.user_error!("AAB 파일을 찾을 수 없습니다: #{aab_path}")
    end

    # Service Account 확인
    unless File.exist?(json_key)
      UI.user_error!("Service Account JSON을 찾을 수 없습니다: #{json_key}")
    end

    # Play Store 업로드
    upload_to_play_store(
      package_name: "${appId}",
      track: "internal",
      aab: aab_path,
      json_key: json_key,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      release_status: "completed"
    )

    puts ""
    puts "========================================="
    puts "내부 테스트 배포 성공!"
    puts "========================================="
  end

  desc "Service Account JSON 검증"
  lane :validate do
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"

    validate_play_store_json_key(
      json_key: json_key
    )

    puts "Service Account 검증 성공!"
  end
end`;

    setElementText('fastfileContent', fastfile);
}

// ============================================
// Step 7: Final Result Generation
// ============================================

function generateFinalResult() {
    const secrets = [
        { key: 'RELEASE_KEYSTORE_BASE64', value: state.keystoreBase64, desc: 'Keystore 파일 (Base64)' },
        { key: 'RELEASE_KEYSTORE_PASSWORD', value: state.storePassword, desc: 'Keystore 비밀번호' },
        { key: 'RELEASE_KEY_ALIAS', value: state.keyAlias, desc: '키 별칭' },
        { key: 'RELEASE_KEY_PASSWORD', value: state.keyPassword, desc: '키 비밀번호' },
        { key: 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64', value: state.serviceAccountBase64, desc: 'Service Account (Base64)' },
        { key: 'GOOGLE_SERVICES_JSON', value: state.googleServicesJson, desc: 'Firebase 설정 (선택)' },
        { key: 'ENV_FILE', value: state.envFileContent, desc: '환경 변수 (선택)' }
    ];

    const tbody = document.getElementById('secretsTableBody');
    if (!tbody) return;

    tbody.innerHTML = secrets.map(s => {
        const hasValue = !!s.value;
        return `
            <tr>
                <td class="px-4 py-3">
                    <code class="text-blue-400">${s.key}</code>
                    <p class="text-xs text-slate-500 mt-1">${s.desc}</p>
                </td>
                <td class="px-4 py-3">
                    <span class="${hasValue ? 'text-green-400' : 'text-red-400'}">
                        ${hasValue ? '✓ 설정됨' : '✗ 미설정'}
                    </span>
                </td>
                <td class="px-4 py-3 text-right">
                    <button
                        class="px-3 py-1 ${hasValue ? 'bg-blue-600 hover:bg-blue-700' : 'bg-slate-700 cursor-not-allowed'} rounded text-xs transition"
                        onclick="copySecretValue('${s.key}')"
                        ${!hasValue ? 'disabled' : ''}>
                        복사
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

function copySecretValue(key) {
    const mapping = {
        'RELEASE_KEYSTORE_BASE64': state.keystoreBase64,
        'RELEASE_KEYSTORE_PASSWORD': state.storePassword,
        'RELEASE_KEY_ALIAS': state.keyAlias,
        'RELEASE_KEY_PASSWORD': state.keyPassword,
        'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64': state.serviceAccountBase64,
        'GOOGLE_SERVICES_JSON': state.googleServicesJson,
        'ENV_FILE': state.envFileContent
    };

    const value = mapping[key];
    if (!value) {
        showToast('⚠️ 값이 비어있습니다');
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        showToast(`✅ ${key} 복사 완료!`);
    });
}

// ============================================
// Download Functions
// ============================================

function downloadAsJson() {
    const secrets = {
        RELEASE_KEYSTORE_BASE64: state.keystoreBase64,
        RELEASE_KEYSTORE_PASSWORD: state.storePassword,
        RELEASE_KEY_ALIAS: state.keyAlias,
        RELEASE_KEY_PASSWORD: state.keyPassword,
        GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64: state.serviceAccountBase64,
        GOOGLE_SERVICES_JSON: state.googleServicesJson,
        ENV_FILE: state.envFileContent
    };

    const jsonStr = JSON.stringify(secrets, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets-playstore.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ JSON 파일 다운로드 완료!');
}

function downloadAsTxt() {
    const lines = [
        '# GitHub Secrets for Play Store Deployment',
        '# 생성일: ' + new Date().toLocaleString('ko-KR'),
        '',
        '===== GitHub Repository Secrets =====',
        '',
        'RELEASE_KEYSTORE_BASE64:',
        state.keystoreBase64 || '(미입력)',
        '',
        'RELEASE_KEYSTORE_PASSWORD:',
        state.storePassword || '(미입력)',
        '',
        'RELEASE_KEY_ALIAS:',
        state.keyAlias || '(미입력)',
        '',
        'RELEASE_KEY_PASSWORD:',
        state.keyPassword || '(미입력)',
        '',
        'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64:',
        state.serviceAccountBase64 || '(미입력)',
        '',
        'GOOGLE_SERVICES_JSON:',
        state.googleServicesJson ? '[설정됨]' : '(미입력)',
        '',
        'ENV_FILE:',
        state.envFileContent || '(미입력)',
        '',
        '====================================='
    ];

    const txtStr = lines.join('\n');
    const blob = new Blob([txtStr], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets-playstore.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ TXT 파일 다운로드 완료!');
}

function downloadConfig() {
    const config = {
        projectInfo: {
            applicationId: state.applicationId,
            versionName: state.versionName,
            versionCode: state.versionCode,
            gradleType: state.gradleType
        },
        generatedAt: new Date().toISOString(),
        secrets: {
            RELEASE_KEYSTORE_BASE64: state.keystoreBase64 ? '[설정됨]' : null,
            RELEASE_KEYSTORE_PASSWORD: state.storePassword ? '[설정됨]' : null,
            RELEASE_KEY_ALIAS: state.keyAlias || null,
            RELEASE_KEY_PASSWORD: state.keyPassword ? '[설정됨]' : null,
            GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64: state.serviceAccountBase64 ? '[설정됨]' : null
        }
    };

    const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'playstore-cicd-config.json';
    a.click();
    URL.revokeObjectURL(url);
    showToast('✅ 설정 JSON 다운로드 완료!');
}

// ============================================
// Changelog Modal Functions
// ============================================

function getVersionData() {
    const scriptEl = document.getElementById('versionJson');
    if (scriptEl) {
        try {
            return JSON.parse(scriptEl.textContent);
        } catch (e) {
            console.error('버전 정보 파싱 실패:', e);
        }
    }
    return null;
}

function openChangelogModal() {
    const modal = document.getElementById('changelogModal');
    const content = document.getElementById('changelogContent');
    const lastUpdated = document.getElementById('changelogLastUpdated');

    const data = getVersionData();
    if (!data) {
        content.innerHTML = '<div class="text-center text-red-400 py-4">버전 정보를 불러올 수 없습니다.</div>';
        modal.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
        return;
    }

    // Build changelog HTML
    let html = '';
    data.changelog.forEach((release, index) => {
        const isLatest = index === 0;

        html += `
            <div class="pb-4 ${index < data.changelog.length - 1 ? 'border-b border-slate-700 mb-4' : ''}">
                <div class="flex items-center gap-2 mb-2">
                    <span class="text-white font-semibold">v${release.version}</span>
                    ${isLatest ? '<span class="px-2 py-0.5 text-xs bg-blue-500/20 text-blue-400 rounded-full">Latest</span>' : ''}
                    <span class="text-slate-500 text-xs">${release.date}</span>
                </div>
                <ul class="space-y-1.5 pl-2">
                    ${release.changes.map(change => `
                        <li class="text-sm text-slate-400 flex items-start gap-2">
                            <span class="text-slate-600 mt-1">•</span>
                            <span>${change}</span>
                        </li>
                    `).join('')}
                </ul>
            </div>
        `;
    });

    content.innerHTML = html;
    lastUpdated.textContent = `Last updated: ${data.lastUpdated}`;

    modal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
}

function closeChangelogModal(event) {
    if (event && event.target !== event.currentTarget) return;
    const modal = document.getElementById('changelogModal');
    modal.classList.add('hidden');
    document.body.style.overflow = '';
}

// ============================================
// Input Event Handlers
// ============================================

function setupInputHandlers() {
    // ESC 키로 모달 닫기
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeChangelogModal();
        }
    });

    // 입력 필드 변경 시 저장
    const inputIds = ['projectPath', 'keyAlias', 'storePassword', 'keyPassword', 'certCN', 'certO', 'certL', 'certC', 'envFileContent', 'scriptOutput'];
    inputIds.forEach(id => {
        const input = document.getElementById(id);
        if (input) {
            input.addEventListener('change', saveCurrentStepData);
            input.addEventListener('blur', saveCurrentStepData);
        }
    });

    // projectPath 더블클릭으로 수동 편집
    const projectPathInput = document.getElementById('projectPath');
    if (projectPathInput) {
        projectPathInput.addEventListener('dblclick', function() {
            this.readOnly = false;
            this.classList.add('border-blue-500');
            this.focus();
        });

        projectPathInput.addEventListener('blur', function() {
            this.readOnly = true;
            this.classList.remove('border-blue-500');
            if (this.value.trim() && !this.value.startsWith('선택된 폴더:')) {
                updateProjectCommands(this.value.trim());
            }
        });

        projectPathInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                this.blur();
            }
        });
    }
}

// ============================================
// Initialization
// ============================================

function initialize() {
    // 저장된 상태 로드
    const hasState = loadState();

    if (hasState) {
        showStep(state.currentStep);
        updateProgress();
        showToast('이전 진행 상태를 복원했습니다');
    } else {
        showStep(1);
        updateProgress();
    }

    setupInputHandlers();
    setupDragAndDrop();
    showSecurityWarning();

    // 버전 배지 업데이트
    const data = getVersionData();
    if (data && data.version) {
        const versionBadge = document.getElementById('versionBadge');
        if (versionBadge) {
            versionBadge.textContent = `v${data.version}`;
        }
    }
}

// DOM 로드 완료 시 초기화
document.addEventListener('DOMContentLoaded', initialize);

// 페이지 언로드 시 경고 (데이터 손실 방지)
window.addEventListener('beforeunload', (e) => {
    if (state.currentStep > 1 || state.keystoreBase64 || state.serviceAccountBase64) {
        e.preventDefault();
        e.returnValue = '입력한 데이터가 사라질 수 있습니다. 정말 나가시겠습니까?';
    }
});
