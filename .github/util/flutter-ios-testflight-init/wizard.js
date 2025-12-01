/**
 * Flutter iOS TestFlight 설정 마법사
 * 다크모드 UI 버전
 */

// ============================================
// State Management
// ============================================

const state = {
    currentStep: 1,
    totalSteps: 5,
    projectPath: '',
    bundleId: '',
    teamId: '',
    profileName: '',
    appName: '',
    encryptionType: 'none' // 'none' = false (HTTPS만), 'standard' = true (암호화 사용)
};

// ============================================
// Secret Generation Guides
// ============================================

const secretGuides = {
    certificate: {
        title: '📜 배포 인증서 (.p12) 생성 가이드',
        steps: [
            '1. Mac에서 "키체인 접근" 앱을 엽니다.',
            '2. "로그인" 키체인에서 "Apple Distribution" 인증서를 찾습니다.',
            '3. 인증서를 우클릭 → "내보내기"를 선택합니다.',
            '4. 파일 형식을 ".p12"로 선택합니다.',
            '5. 안전한 비밀번호를 설정합니다 (이 비밀번호가 APPLE_CERTIFICATE_PASSWORD)',
            '6. 아래 명령어로 Base64 인코딩합니다:'
        ],
        commands: [
            'base64 -i ~/Desktop/Certificates.p12 | pbcopy',
            '# 클립보드에 복사됨 → GitHub Secret에 붙여넣기'
        ]
    },
    profile: {
        title: '📋 프로비저닝 프로파일 생성 가이드',
        steps: [
            '1. Apple Developer Console (https://developer.apple.com) 접속',
            '2. Certificates, Identifiers & Profiles → Profiles',
            '3. "+" 버튼으로 새 프로파일 생성 또는 기존 프로파일 선택',
            '4. "App Store" Distribution 타입 선택',
            '5. 앱의 Bundle ID 선택',
            '6. Distribution Certificate 선택',
            '7. 프로파일 다운로드 (.mobileprovision 파일)',
            '8. 아래 명령어로 Base64 인코딩:'
        ],
        commands: [
            'base64 -i ~/Downloads/YourProfile.mobileprovision | pbcopy',
            '# 클립보드에 복사됨 → GitHub Secret에 붙여넣기'
        ]
    },
    apikey: {
        title: '🔑 App Store Connect API Key 생성 가이드',
        steps: [
            '1. App Store Connect (https://appstoreconnect.apple.com) 접속',
            '2. Users and Access → Keys 탭',
            '3. "+" 버튼으로 새 API Key 생성',
            '4. 이름 입력, Access: "App Manager" 또는 "Admin" 선택',
            '5. Key ID 복사 → APP_STORE_CONNECT_API_KEY_ID',
            '6. Issuer ID 복사 (상단에 표시됨) → APP_STORE_CONNECT_ISSUER_ID',
            '7. API Key 다운로드 (.p8 파일, 한 번만 다운로드 가능!)',
            '8. 아래 명령어로 Base64 인코딩:'
        ],
        commands: [
            'base64 -i ~/Downloads/AuthKey_XXXXXX.p8 | pbcopy',
            '# 클립보드에 복사됨 → GitHub Secret에 붙여넣기'
        ]
    }
};

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
// Folder Selection (File System Access API)
// ============================================

async function selectProjectFolder() {
    // File System Access API 지원 확인
    if ('showDirectoryPicker' in window) {
        try {
            const dirHandle = await window.showDirectoryPicker();
            const projectPath = dirHandle.name;

            // 입력 필드에 경로 설정 (브라우저 보안상 실제 경로는 알 수 없으므로 폴더명만)
            const input = document.getElementById('projectPath');
            if (input) {
                // 힌트 메시지와 함께 표시
                input.value = `선택된 폴더: ${projectPath} (터미널에서 실제 경로를 사용하세요)`;
                input.placeholder = '선택된 폴더를 확인하고 실제 경로를 입력하세요';
            }

            showToast(`폴더 "${projectPath}" 선택됨`);
            updatePathCheckCommand();
        } catch (err) {
            if (err.name !== 'AbortError') {
                console.error('폴더 선택 오류:', err);
                showToast('폴더 선택에 실패했습니다. 경로를 직접 입력해주세요.');
            }
        }
    } else {
        // File System Access API를 지원하지 않는 브라우저
        showToast('이 브라우저는 폴더 선택을 지원하지 않습니다. 경로를 직접 입력해주세요.');
        const input = document.getElementById('projectPath');
        if (input) {
            input.focus();
        }
    }
}

// ============================================
// Clipboard Functions
// ============================================

async function copyToClipboard(elementId) {
    const element = document.getElementById(elementId);
    if (!element) return;

    const text = element.textContent || '';

    try {
        await navigator.clipboard.writeText(text);
        showToast('클립보드에 복사되었습니다!');
    } catch (err) {
        // Fallback for older browsers
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('클립보드에 복사되었습니다!');
    }
}

// Copy code from code block
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
        // Fallback
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('복사되었습니다!');
    });
}

function showToast(message) {
    // 기존 토스트 제거
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
    }, 2000);
}

// ============================================
// Navigation Functions
// ============================================

function updateProgress() {
    // Step indicators 업데이트
    $$('.step-indicator').forEach((indicator, index) => {
        const stepNum = index + 1;
        const circle = indicator.querySelector('.step-circle');
        const label = indicator.querySelector('span');

        if (stepNum < state.currentStep) {
            // 완료된 스텝
            circle.className = 'step-circle w-10 h-10 rounded-full bg-green-500 text-white flex items-center justify-center font-bold text-sm z-10 shadow-lg';
            circle.innerHTML = '✓';
            if (label) label.className = 'text-xs mt-2 text-green-400 text-center hidden md:block';
        } else if (stepNum === state.currentStep) {
            // 현재 스텝
            circle.className = 'step-circle w-10 h-10 rounded-full bg-orange-500 text-white flex items-center justify-center font-bold text-sm z-10 shadow-lg';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-xs mt-2 text-slate-400 text-center hidden md:block';
        } else {
            // 아직 안 한 스텝
            circle.className = 'step-circle w-10 h-10 rounded-full bg-slate-700 text-slate-400 flex items-center justify-center font-bold text-sm z-10';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-xs mt-2 text-slate-500 text-center hidden md:block';
        }
    });
}

function showStep(stepNumber) {
    // 모든 스텝 숨기기
    $$('.step-content').forEach(step => {
        step.classList.add('hidden');
        step.classList.remove('fade-in');
    });

    // 현재 스텝 표시
    const currentStepElement = $(`.step-content[data-step="${stepNumber}"]`);
    if (currentStepElement) {
        currentStepElement.classList.remove('hidden');
        currentStepElement.classList.add('fade-in');
    }

    // 스텝별 초기화
    initializeStep(stepNumber);
}

function initializeStep(stepNumber) {
    switch (stepNumber) {
        case 1:
            updatePathCheckCommand();
            break;
        case 2:
            // 이전 값들 복원
            restoreInputValues();
            break;
        case 3:
            generateInitCommand();
            break;
        case 4:
            updateSecretsPreview();
            break;
        case 5:
            generateSummary();
            break;
    }
}

function restoreInputValues() {
    const bundleIdInput = document.getElementById('bundleId');
    const teamIdInput = document.getElementById('teamId');
    const profileNameInput = document.getElementById('profileName');
    const appNameInput = document.getElementById('appName');

    if (bundleIdInput && state.bundleId) bundleIdInput.value = state.bundleId;
    if (teamIdInput && state.teamId) teamIdInput.value = state.teamId;
    if (profileNameInput && state.profileName) profileNameInput.value = state.profileName;
    if (appNameInput && state.appName) appNameInput.value = state.appName;
}

function nextStep() {
    if (!validateCurrentStep()) {
        return;
    }

    saveCurrentStepData();

    if (state.currentStep < state.totalSteps) {
        state.currentStep++;
        showStep(state.currentStep);
        updateProgress();

        // 스크롤 맨 위로
        window.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
        // 완료
        showToast('설정이 완료되었습니다!');
    }
}

function prevStep() {
    if (state.currentStep > 1) {
        saveCurrentStepData();
        state.currentStep--;
        showStep(state.currentStep);
        updateProgress();

        // 스크롤 맨 위로
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function resetWizard() {
    // 상태 초기화
    state.currentStep = 1;
    state.projectPath = '';
    state.bundleId = '';
    state.teamId = '';
    state.profileName = '';
    state.appName = '';

    // localStorage 초기화
    localStorage.removeItem('wizardState');

    // 입력 필드 초기화
    const inputs = ['projectPath', 'bundleId', 'teamId', 'profileName', 'appName'];
    inputs.forEach(id => {
        const input = document.getElementById(id);
        if (input) input.value = '';
    });

    // UI 초기화
    showStep(1);
    updateProgress();

    showToast('마법사가 초기화되었습니다.');
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// ============================================
// Validation Functions
// ============================================

function validateCurrentStep() {
    clearAllValidationErrors();

    switch (state.currentStep) {
        case 1:
            // Step 1은 선택사항 - 항상 통과
            return true;
        case 2:
            return validateStep2();
        default:
            return true;
    }
}

function validateStep1() {
    const projectPath = getInputValue('projectPath');
    const validationEl = document.getElementById('step1Validation');

    if (!projectPath) {
        showValidationError('projectPath', '프로젝트 경로를 입력해주세요.');
        if (validationEl) {
            validationEl.innerHTML = '<div class="error-message">❌ 프로젝트 경로를 입력해주세요.</div>';
        }
        return false;
    }

    // 선택된 폴더 표시인 경우 경고만 표시
    if (projectPath.startsWith('선택된 폴더:')) {
        if (validationEl) {
            validationEl.innerHTML = '<div class="text-yellow-400 text-sm">⚠️ 터미널에서 실제 절대 경로를 사용하세요.</div>';
        }
        return true;
    }

    // Mac/Linux 절대 경로 확인
    if (!projectPath.startsWith('/') && !projectPath.match(/^[A-Za-z]:\\/)) {
        showValidationError('projectPath', '절대 경로를 입력해주세요. (예: /Users/... 또는 C:\\...)');
        if (validationEl) {
            validationEl.innerHTML = '<div class="error-message">❌ 절대 경로를 입력해주세요. (예: /Users/username/project)</div>';
        }
        return false;
    }

    clearValidationError('projectPath');
    if (validationEl) {
        validationEl.innerHTML = '<div class="success-message">✅ 경로가 입력되었습니다.</div>';
    }
    return true;
}

function validateStep2() {
    const bundleId = getInputValue('bundleId');
    const teamId = getInputValue('teamId');
    const profileName = getInputValue('profileName');
    const validationEl = document.getElementById('step2Validation');

    let errors = [];

    // Bundle ID 검증
    if (!bundleId) {
        showValidationError('bundleId', 'Bundle ID를 입력해주세요.');
        errors.push('Bundle ID를 입력해주세요.');
    } else if (!bundleId.includes('.')) {
        showValidationError('bundleId', 'Bundle ID 형식이 올바르지 않습니다. (예: com.example.app)');
        errors.push('Bundle ID 형식이 올바르지 않습니다.');
    } else if (!/^[a-zA-Z][a-zA-Z0-9.-]*\.[a-zA-Z][a-zA-Z0-9.-]*$/.test(bundleId)) {
        showValidationError('bundleId', 'Bundle ID는 영문자로 시작하고 점(.)으로 구분되어야 합니다.');
        errors.push('Bundle ID 형식을 확인해주세요.');
    } else {
        clearValidationError('bundleId');
    }

    // Team ID 검증
    if (!teamId) {
        showValidationError('teamId', 'Team ID를 입력해주세요.');
        errors.push('Team ID를 입력해주세요.');
    } else if (teamId.length !== 10) {
        showValidationError('teamId', 'Team ID는 10자리여야 합니다.');
        errors.push('Team ID는 10자리여야 합니다.');
    } else if (!/^[A-Z0-9]{10}$/.test(teamId.toUpperCase())) {
        showValidationError('teamId', 'Team ID는 영문 대문자와 숫자로만 구성됩니다.');
        errors.push('Team ID 형식을 확인해주세요.');
    } else {
        clearValidationError('teamId');
    }

    // Profile Name 검증
    if (!profileName) {
        showValidationError('profileName', 'Provisioning Profile 이름을 입력해주세요.');
        errors.push('Provisioning Profile 이름을 입력해주세요.');
    } else {
        clearValidationError('profileName');
    }

    // 검증 결과 표시
    if (validationEl) {
        if (errors.length > 0) {
            validationEl.innerHTML = `<div class="error-message">❌ ${errors.join('<br>❌ ')}</div>`;
        } else {
            validationEl.innerHTML = '<div class="success-message">✅ 모든 정보가 입력되었습니다.</div>';
        }
    }

    return errors.length === 0;
}

function showValidationError(inputId, message) {
    const input = document.getElementById(inputId);
    if (input) {
        input.classList.add('input-error');
    }
}

function clearValidationError(inputId) {
    const input = document.getElementById(inputId);
    if (input) {
        input.classList.remove('input-error');
    }
}

function clearAllValidationErrors() {
    $$('.input-error').forEach(el => el.classList.remove('input-error'));
}

// ============================================
// Data Management Functions
// ============================================

function saveCurrentStepData() {
    switch (state.currentStep) {
        case 1:
            state.projectPath = getInputValue('projectPath');
            // 선택된 폴더 표시 제거
            if (state.projectPath.startsWith('선택된 폴더:')) {
                state.projectPath = '';
            }
            break;
        case 2:
            state.bundleId = getInputValue('bundleId');
            state.teamId = getInputValue('teamId').toUpperCase();
            state.profileName = getInputValue('profileName');
            state.appName = getInputValue('appName');
            // 암호화 설정 저장
            const encryptionRadio = document.querySelector('input[name="encryptionType"]:checked');
            state.encryptionType = encryptionRadio ? encryptionRadio.value : 'none';
            break;
    }

    // LocalStorage에 저장 (새로고침 시 복원용)
    localStorage.setItem('wizardState', JSON.stringify(state));
}

function loadSavedState() {
    const saved = localStorage.getItem('wizardState');
    if (saved) {
        try {
            const savedState = JSON.parse(saved);
            Object.assign(state, savedState);

            // 입력 필드에 값 복원
            const projectPathInput = document.getElementById('projectPath');
            const bundleIdInput = document.getElementById('bundleId');
            const teamIdInput = document.getElementById('teamId');
            const profileNameInput = document.getElementById('profileName');
            const appNameInput = document.getElementById('appName');

            if (projectPathInput) projectPathInput.value = state.projectPath;
            if (bundleIdInput) bundleIdInput.value = state.bundleId;
            if (teamIdInput) teamIdInput.value = state.teamId;
            if (profileNameInput) profileNameInput.value = state.profileName;
            if (appNameInput) appNameInput.value = state.appName;

            // 암호화 설정 복원
            if (state.encryptionType) {
                const encryptionRadio = document.querySelector(`input[name="encryptionType"][value="${state.encryptionType}"]`);
                if (encryptionRadio) encryptionRadio.checked = true;
            }
        } catch (e) {
            console.error('Failed to load saved state:', e);
        }
    }
}

// ============================================
// Command Generation Functions
// ============================================

function updatePathCheckCommand() {
    let projectPath = getInputValue('projectPath') || '/path/to/project';

    // 선택된 폴더 표시인 경우 기본값 사용
    if (projectPath.startsWith('선택된 폴더:')) {
        projectPath = '/path/to/project';
    }

    const cmd = `cd "${projectPath}" && ls pubspec.yaml ios/`;
    setElementText('pathCheckCmd', cmd);
}

function generateInitCommand() {
    const scriptPath = getScriptPath();
    const projectPath = state.projectPath || '/path/to/project';
    const bundleId = state.bundleId || 'com.example.app';
    const teamId = state.teamId || 'TEAM_ID';
    const profileName = state.profileName || 'Profile Name';
    // 암호화 설정: 'none' = false, 'standard' = true
    const usesNonExemptEncryption = state.encryptionType === 'standard' ? 'true' : 'false';

    const cmd = `cd "${projectPath}" && bash "${scriptPath}/init.sh" "${projectPath}" "${bundleId}" "${teamId}" "${profileName}" "${usesNonExemptEncryption}"`;
    setElementText('initCmd', cmd);

    const verifyCmd = `ls -la "${projectPath}/ios/Gemfile" "${projectPath}/ios/fastlane/"`;
    setElementText('verifyCmd', verifyCmd);
}

function getScriptPath() {
    const projectPath = state.projectPath || '/path/to/project';
    return `${projectPath}/.github/util/flutter-ios-testflight-init`;
}

function updateSecretsPreview() {
    setElementText('teamIdPreview', state.teamId || '-');
    setElementText('bundleIdPreview', state.bundleId || '-');
    setElementText('profileNamePreview', state.profileName || '-');
}

function generateSummary() {
    const encryptionLabel = state.encryptionType === 'standard'
        ? 'Standard encryption (true)'
        : 'None - HTTPS only (false)';

    const summaryHtml = `
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
                <p class="text-xs text-slate-500 mb-1">프로젝트 경로</p>
                <p class="text-sm font-medium text-slate-200 break-all">${state.projectPath || '-'}</p>
            </div>
            <div>
                <p class="text-xs text-slate-500 mb-1">Bundle ID</p>
                <p class="text-sm font-medium text-slate-200">${state.bundleId || '-'}</p>
            </div>
            <div>
                <p class="text-xs text-slate-500 mb-1">Team ID</p>
                <p class="text-sm font-medium text-slate-200">${state.teamId || '-'}</p>
            </div>
            <div>
                <p class="text-xs text-slate-500 mb-1">Provisioning Profile</p>
                <p class="text-sm font-medium text-slate-200">${state.profileName || '-'}</p>
            </div>
            <div>
                <p class="text-xs text-slate-500 mb-1">🔐 암호화 설정</p>
                <p class="text-sm font-medium text-slate-200">${encryptionLabel}</p>
            </div>
            ${state.appName ? `
            <div>
                <p class="text-xs text-slate-500 mb-1">앱 이름</p>
                <p class="text-sm font-medium text-slate-200">${state.appName}</p>
            </div>
            ` : ''}
        </div>
    `;
    setElementHtml('summaryContent', summaryHtml);

    // 커밋 명령어 업데이트
    const projectPath = state.projectPath || '.';
    const commitCmd = `cd "${projectPath}" && git add ios/Gemfile ios/fastlane/ ios/Runner/Info.plist && git commit -m "chore: iOS Fastlane 설정 및 암호화 선언 추가"`;
    setElementText('commitCmd', commitCmd);
}

// ============================================
// Secret Guide Modal Functions
// ============================================

function showSecretGuide(type) {
    const guide = secretGuides[type];
    if (!guide) return;

    const modal = document.getElementById('guideModal');
    const titleEl = document.getElementById('guideTitle');
    const content = document.getElementById('guideContent');

    if (!modal || !content) return;

    if (titleEl) {
        titleEl.textContent = guide.title;
    }

    let html = '<ol class="list-decimal list-inside space-y-2 mb-4">';
    guide.steps.forEach(step => {
        html += `<li class="text-slate-300 text-sm">${step}</li>`;
    });
    html += '</ol>';

    if (guide.commands && guide.commands.length > 0) {
        html += '<div class="space-y-2">';
        guide.commands.forEach(cmd => {
            html += `
                <div class="code-block">
                    <button class="copy-btn absolute top-2 right-2 px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-xs text-slate-300 transition" onclick="copyCode(this)">복사</button>
                    <pre>${cmd}</pre>
                </div>
            `;
        });
        html += '</div>';
    }

    content.innerHTML = html;
    modal.classList.remove('hidden');
}

function closeGuideModal(event) {
    // 이벤트가 있고 모달 내부 클릭이면 무시
    if (event && event.target !== event.currentTarget) {
        return;
    }

    const modal = document.getElementById('guideModal');
    if (modal) {
        modal.classList.add('hidden');
    }
}

// ============================================
// GitHub Integration
// ============================================

function openGitHubSecrets() {
    // 프로젝트 경로에서 GitHub 레포지토리 URL 추출 시도
    const repoUrl = prompt(
        'GitHub Repository URL을 입력하세요:\n(예: https://github.com/username/repo)',
        'https://github.com/'
    );

    if (repoUrl && repoUrl !== 'https://github.com/') {
        const secretsUrl = `${repoUrl}/settings/secrets/actions`;
        window.open(secretsUrl, '_blank');
    }
}

// ============================================
// Input Event Handlers
// ============================================

function setupInputHandlers() {
    // 프로젝트 경로 입력 시 명령어 업데이트
    const projectPathInput = document.getElementById('projectPath');
    if (projectPathInput) {
        projectPathInput.addEventListener('input', () => {
            updatePathCheckCommand();
        });
    }

    // Team ID 대문자 자동 변환
    const teamIdInput = document.getElementById('teamId');
    if (teamIdInput) {
        teamIdInput.addEventListener('input', (e) => {
            e.target.value = e.target.value.toUpperCase();
        });
    }

    // ESC 키로 모달 닫기
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeGuideModal();
        }
    });

    // 입력 필드 포커스 시 에러 스타일 제거
    $$('input').forEach(input => {
        input.addEventListener('focus', () => {
            input.classList.remove('input-error');
        });
    });
}

// ============================================
// Initialization
// ============================================

function initialize() {
    loadSavedState();
    setupInputHandlers();
    showStep(state.currentStep);
    updateProgress();
}

// DOM 로드 완료 시 초기화
document.addEventListener('DOMContentLoaded', initialize);
