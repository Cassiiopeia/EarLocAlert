/**
 * Flutter OAuth 설정 마법사
 * 다중 OAuth 제공자 지원, 동적 단계 생성, OS 자동 감지
 */

// ============================================
// OS Detection
// ============================================

let detectedOS = 'mac'; // 기본값: Mac

function detectOS() {
    const userAgent = navigator.userAgent || navigator.appVersion || navigator.platform;
    
    if (/Win/i.test(userAgent)) {
        return 'windows';
    } else if (/Mac/i.test(userAgent)) {
        return 'mac';
    }
    return 'mac'; // 기본값: Mac
}

// ============================================
// State Management
// ============================================

const state = {
    currentStep: 1,
    totalSteps: 1, // 동적으로 업데이트됨
    projectPath: '',
    selectedProviders: [], // 선택한 OAuth 제공자 ID 배열
    providerData: {}, // 각 제공자별 입력 데이터
    detectedOS: 'mac'
};

// ============================================
// OAuth Providers Data
// ============================================

let oauthProviders = [];

function loadProviders() {
    try {
        const scriptEl = document.getElementById('oauthProvidersJson');
        if (scriptEl) {
            const data = JSON.parse(scriptEl.textContent);
            oauthProviders = data.providers;
            return true;
        } else {
            console.error('OAuth 제공자 데이터 스크립트 태그를 찾을 수 없습니다.');
            showToast('⚠️ OAuth 제공자 데이터를 불러올 수 없습니다.');
            return false;
        }
    } catch (error) {
        console.error('OAuth 제공자 데이터 파싱 실패:', error);
        showToast('⚠️ OAuth 제공자 데이터를 파싱할 수 없습니다.');
        return false;
    }
}

// ============================================
// LocalStorage Functions
// ============================================

const STORAGE_KEY = 'flutter_oauth_wizard_state';
const STORAGE_WARNING_KEY = 'flutter_oauth_wizard_security_warning_dismissed';

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
            const currentTotalSteps = state.totalSteps;
            Object.assign(state, savedState);
            state.totalSteps = currentTotalSteps;
            state.detectedOS = detectedOS; // 항상 최신 OS 사용
            
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
    // 프로젝트 경로 복원
    const projectPathInput = document.getElementById('projectPath');
    if (projectPathInput && state.projectPath) {
        projectPathInput.value = state.projectPath;
    }
    
    // 프로젝트 경로 변경 시 스크립트 명령어 업데이트
    if (projectPathInput) {
        projectPathInput.addEventListener('input', () => {
            state.projectPath = projectPathInput.value;
            // 모든 제공자별 스크립트 명령어 업데이트
            state.selectedProviders.forEach(providerId => {
                updateSha1ScriptCommand(providerId);
                // 프로젝트 경로 표시 업데이트
                const pathDisplay = document.getElementById(`${providerId}-project-path-display`);
                if (pathDisplay) {
                    pathDisplay.textContent = state.projectPath || '입력 필요';
                }
            });
            saveState();
        });
    }
    
    // 선택한 제공자 복원
    if (state.selectedProviders && state.selectedProviders.length > 0) {
        state.selectedProviders.forEach(providerId => {
            const card = document.querySelector(`[data-provider-id="${providerId}"]`);
            if (card) {
                card.classList.add('selected');
            }
        });
        updateNextButton();
        generateDynamicSteps();
    }
    
    // 각 제공자별 입력 데이터 복원
    Object.entries(state.providerData).forEach(([providerId, data]) => {
        Object.entries(data).forEach(([fieldKey, value]) => {
            const input = document.getElementById(`${providerId}-${fieldKey}`);
            if (input && value) {
                input.value = value;
            }
        });
    });
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
// Clipboard Functions
// ============================================

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

function copyValue(elementIdOrBtn, key) {
    // elementId가 문자열인 경우 (새로운 방식)
    if (typeof elementIdOrBtn === 'string') {
        const element = document.getElementById(elementIdOrBtn);
        if (!element) return;
        
        const value = element.value || element.textContent || '';
        if (!value) {
            showToast('⚠️ 복사할 값이 없습니다.');
            return;
        }
        
        navigator.clipboard.writeText(value).then(() => {
            showToast('✅ 복사되었습니다!');
            
            // 복사 버튼 피드백
            const copyBtn = document.getElementById(elementIdOrBtn + '-copy-btn');
            if (copyBtn) {
                const originalText = copyBtn.textContent;
                copyBtn.textContent = '복사됨!';
                copyBtn.classList.add('copied');
                setTimeout(() => {
                    copyBtn.textContent = originalText;
                    copyBtn.classList.remove('copied');
                }, 2000);
            }
        }).catch(err => {
            console.error('복사 실패:', err);
            showToast('❌ 복사 실패');
        });
        return;
    }
    
    // 기존 방식 (btn, key)
    const btn = elementIdOrBtn;
    const value = document.getElementById(`value-${key}`).textContent;
    if (value === '(비어있음)') {
        showToast('⚠️ 값이 비어있습니다');
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        btn.textContent = '복사됨!';
        btn.classList.add('copied');
        setTimeout(() => {
            btn.textContent = '복사';
            btn.classList.remove('copied');
        }, 2000);
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
// Provider Selection
// ============================================

function toggleProvider(providerId) {
    const card = document.querySelector(`[data-provider-id="${providerId}"]`);
    if (!card) return;

    const index = state.selectedProviders.indexOf(providerId);
    if (index > -1) {
        // 제거
        state.selectedProviders.splice(index, 1);
        card.classList.remove('selected');
        delete state.providerData[providerId];
    } else {
        // 추가
        state.selectedProviders.push(providerId);
        card.classList.add('selected');
        state.providerData[providerId] = {};
    }

    updateNextButton();
    saveState();
}

function updateNextButton() {
    const nextBtn = document.getElementById('nextBtnStep1');
    if (nextBtn) {
        nextBtn.disabled = state.selectedProviders.length === 0;
    }
}

// ============================================
// Dynamic Step Generation
// ============================================

function generateDynamicSteps() {
    // Step 1 + 선택한 제공자 수 + 완료 Step = 총 단계 수
    state.totalSteps = 1 + state.selectedProviders.length + 1;
    
    // Progress Steps 업데이트
    updateProgressSteps();
    
    // Provider 설정 Steps 생성
    generateProviderSteps();
}

function updateProgressSteps() {
    const progressContainer = document.getElementById('progressSteps');
    if (!progressContainer) return;

    let html = '';
    
    // Step 1: 시작하기
    html += `
        <div class="step-indicator flex flex-col items-center flex-1 relative min-w-[40px]" data-step="1">
            <div class="step-circle w-8 h-8 rounded-full ${state.currentStep === 1 ? 'bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg shadow-blue-500/30' : state.currentStep > 1 ? 'bg-green-500 text-white' : 'bg-slate-700 text-slate-400'} flex items-center justify-center font-bold text-xs z-10">
                ${state.currentStep > 1 ? '✓' : '1'}
            </div>
            <span class="text-[9px] mt-1 ${state.currentStep === 1 ? 'text-blue-400' : state.currentStep > 1 ? 'text-green-400' : 'text-slate-500'} text-center hidden md:block">시작</span>
        </div>
    `;
    
    // 선택한 제공자별 Step
    state.selectedProviders.forEach((providerId, index) => {
        const provider = oauthProviders.find(p => p.id === providerId);
        if (!provider) return;
        
        const stepNum = index + 2;
        const isCurrent = state.currentStep === stepNum;
        const isCompleted = state.currentStep > stepNum;
        
        html += `
            <div class="step-indicator flex flex-col items-center flex-1 relative min-w-[40px]" data-step="${stepNum}">
                <div class="step-circle w-8 h-8 rounded-full ${isCurrent ? 'bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg shadow-blue-500/30' : isCompleted ? 'bg-green-500 text-white' : 'bg-slate-700 text-slate-400'} flex items-center justify-center font-bold text-xs z-10">
                    ${isCompleted ? '✓' : stepNum}
                </div>
                <span class="text-[9px] mt-1 ${isCurrent ? 'text-blue-400' : isCompleted ? 'text-green-400' : 'text-slate-500'} text-center hidden md:block">${provider.name}</span>
            </div>
        `;
    });
    
    // 마지막 Step: 완료
    const finalStepNum = state.totalSteps;
    const isFinalCurrent = state.currentStep === finalStepNum;
    const isFinalCompleted = state.currentStep > finalStepNum;
    
    html += `
        <div class="step-indicator flex flex-col items-center flex-1 min-w-[40px]" data-step="${finalStepNum}">
            <div class="step-circle w-8 h-8 rounded-full ${isFinalCurrent ? 'bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg shadow-blue-500/30' : isFinalCompleted ? 'bg-green-500 text-white' : 'bg-slate-700 text-slate-400'} flex items-center justify-center font-bold text-xs z-10">
                ${isFinalCompleted ? '✓' : finalStepNum}
            </div>
            <span class="text-[9px] mt-1 ${isFinalCurrent ? 'text-blue-400' : isFinalCompleted ? 'text-green-400' : 'text-slate-500'} text-center hidden md:block">완료</span>
        </div>
    `;
    
    progressContainer.innerHTML = html;
}

function generateProviderSteps() {
    const container = document.getElementById('providerSteps');
    if (!container) return;

    let html = '';
    
    state.selectedProviders.forEach((providerId, index) => {
        const provider = oauthProviders.find(p => p.id === providerId);
        if (!provider) return;
        
        const stepNum = index + 2;
        
        html += `
            <div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="${stepNum}" data-provider="${providerId}">
                <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
                    <span class="w-8 h-8 rounded-lg flex items-center justify-center text-sm" style="background-color: ${provider.color}; color: white;">${provider.icon}</span>
                    ${provider.name} 설정
                </h2>

                <div class="bg-blue-900/30 border border-blue-700 rounded-lg p-4 mb-6">
                    <p class="text-sm text-blue-200 mb-3">
                        📋 ${provider.name} OAuth 설정을 완료하세요.
                    </p>
                    <div class="flex gap-2 mt-2">
                        <a href="${provider.consoleUrl}" target="_blank" rel="noopener"
                           class="inline-flex items-center gap-2 px-3 py-1.5 bg-blue-600 hover:bg-blue-700 rounded-lg text-xs font-medium transition">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
                            </svg>
                            ${provider.name} 콘솔 열기
                        </a>
                        ${provider.docsUrl ? `
                        <a href="${provider.docsUrl}" target="_blank" rel="noopener"
                           class="inline-flex items-center gap-2 px-3 py-1.5 bg-slate-600 hover:bg-slate-700 rounded-lg text-xs font-medium transition">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path>
                            </svg>
                            문서 보기
                        </a>
                        ` : ''}
                    </div>
                </div>

                <!-- 설정 단계 가이드 -->
                <div class="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4 mb-6">
                    <p class="text-sm text-yellow-200 mb-3">📋 ${provider.name} 콘솔 설정 단계</p>
                    <ol class="text-xs text-slate-300 list-decimal list-inside space-y-2">
                        ${provider.setupSteps.map((step, idx) => `
                            <li>${step}</li>
                        `).join('')}
                    </ol>
                </div>

                ${provider.requiresKeyHash || provider.requiresSha1 ? `
                <!-- SHA-1 인증서 지문 생성 섹션 -->
                <div class="bg-purple-900/30 border border-purple-700 rounded-lg p-4 mb-6">
                    <h3 class="text-sm font-bold text-purple-200 mb-3 flex items-center gap-2">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>
                        </svg>
                        ${provider.requiresKeyHash ? '카카오 키 해시' : 'SHA-1 인증서 지문'} 생성
                    </h3>
                    <p class="text-xs text-slate-300 mb-4">
                        아래 스크립트를 실행하여 ${provider.requiresKeyHash ? '카카오 키 해시' : 'SHA-1 인증서 지문'}를 생성하세요.
                    </p>
                    
                    <!-- 스크립트 실행 명령어 -->
                    <div class="mb-4">
                        <label class="block text-xs font-medium mb-2 text-slate-300">
                            스크립트 실행 명령어
                            <span class="text-xs text-slate-500 ml-2">(프로젝트 경로: <span id="${providerId}-project-path-display" class="font-mono text-xs">${state.projectPath || '입력 필요'}</span>)</span>
                        </label>
                        <div class="code-block">
                            <button class="copy-btn absolute top-2 right-2 px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-xs text-slate-300 transition" onclick="copyCode(this)">복사</button>
                            <pre id="${providerId}-sha1-script-command" class="text-xs"></pre>
                        </div>
                        <p class="text-xs text-slate-500 mt-2">
                            💡 터미널에서 위 명령어를 실행하면 ${provider.requiresKeyHash ? '카카오 키 해시' : 'SHA-1 인증서 지문'}가 출력됩니다.
                        </p>
                    </div>
                    
                    <!-- 생성된 값 표시 영역 -->
                    <div class="space-y-3">
                        ${provider.requiresKeyHash ? `
                        <div>
                            <label class="block text-xs font-medium mb-2 text-slate-300">
                                카카오 키 해시 (Key Hash)
                                <span class="text-xs text-slate-500 ml-2">스크립트 실행 후 아래에 붙여넣기</span>
                            </label>
                            <div class="flex gap-2">
                                <input type="text" 
                                       id="${providerId}-key-hash"
                                       placeholder="스크립트 실행 후 생성된 키 해시를 여기에 붙여넣으세요"
                                       class="flex-1 bg-slate-900 border border-slate-600 rounded-lg px-4 py-2.5 text-sm text-slate-300 focus:border-purple-500 focus:ring-1 focus:ring-purple-500 outline-none transition font-mono text-xs"
                                       onchange="saveProviderData('${providerId}', 'keyHash')">
                                <button class="copy-btn-small px-4 py-2.5 bg-purple-600 hover:bg-purple-700 rounded-lg text-xs font-medium transition" 
                                        onclick="copyValue('${providerId}-key-hash')"
                                        id="${providerId}-key-hash-copy-btn">
                                    복사
                                </button>
                            </div>
                            <div class="mt-2 bg-slate-900/50 border border-slate-700 rounded-lg p-3">
                                <p class="text-xs text-slate-400 mb-2">📋 카카오 콘솔 등록 위치:</p>
                                <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                                    ${provider.keyHashSetupGuide ? provider.keyHashSetupGuide.map(step => `<li>${step}</li>`).join('') : ''}
                                </ol>
                            </div>
                        </div>
                        ` : ''}
                        
                        ${provider.requiresSha1 ? `
                        <div>
                            <label class="block text-xs font-medium mb-2 text-slate-300">
                                SHA-1 인증서 지문 (콜론 포함)
                                <span class="text-xs text-slate-500 ml-2">스크립트 실행 후 아래에 붙여넣기</span>
                            </label>
                            <div class="flex gap-2">
                                <input type="text" 
                                       id="${providerId}-sha1-with-colons"
                                       placeholder="예: 29:6F:C9:4E:7D:17:D5:2A:D6:F1:FE:70:A8:CB:7C:47:C4:71:76:01"
                                       class="flex-1 bg-slate-900 border border-slate-600 rounded-lg px-4 py-2.5 text-sm text-slate-300 focus:border-purple-500 focus:ring-1 focus:ring-purple-500 outline-none transition font-mono text-xs"
                                       onchange="saveProviderData('${providerId}', 'sha1WithColons')">
                                <button class="copy-btn-small px-4 py-2.5 bg-purple-600 hover:bg-purple-700 rounded-lg text-xs font-medium transition" 
                                        onclick="copyValue('${providerId}-sha1-with-colons')"
                                        id="${providerId}-sha1-with-colons-copy-btn">
                                    복사
                                </button>
                            </div>
                        </div>
                        <div>
                            <label class="block text-xs font-medium mb-2 text-slate-300">
                                SHA-1 인증서 지문 (콜론 없음, Firebase용)
                                <span class="text-xs text-slate-500 ml-2">스크립트 실행 후 아래에 붙여넣기</span>
                            </label>
                            <div class="flex gap-2">
                                <input type="text" 
                                       id="${providerId}-sha1-without-colons"
                                       placeholder="예: 296FC94E7D17D52AD6F1FE70A8CB7C47C4717601"
                                       class="flex-1 bg-slate-900 border border-slate-600 rounded-lg px-4 py-2.5 text-sm text-slate-300 focus:border-purple-500 focus:ring-1 focus:ring-purple-500 outline-none transition font-mono text-xs"
                                       onchange="saveProviderData('${providerId}', 'sha1WithoutColons')">
                                <button class="copy-btn-small px-4 py-2.5 bg-purple-600 hover:bg-purple-700 rounded-lg text-xs font-medium transition" 
                                        onclick="copyValue('${providerId}-sha1-without-colons')"
                                        id="${providerId}-sha1-without-colons-copy-btn">
                                    복사
                                </button>
                            </div>
                            <div class="mt-2 bg-slate-900/50 border border-slate-700 rounded-lg p-3">
                                <p class="text-xs text-slate-400 mb-2">📋 Firebase/Google 콘솔 등록 위치:</p>
                                <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                                    ${provider.sha1SetupGuide ? provider.sha1SetupGuide.map(step => `<li>${step}</li>`).join('') : ''}
                                </ol>
                            </div>
                        </div>
                        ` : ''}
                    </div>
                </div>
                ` : ''}

                <!-- 입력 필드 -->
                <div class="space-y-4 mb-6">
                    ${provider.fields.map(field => `
                        <div>
                            <label class="block text-sm font-medium mb-2 text-slate-300">
                                ${field.label}
                                ${field.required ? '<span class="text-red-400">*</span>' : ''}
                                ${field.description ? `
                                <span class="tooltip-container">
                                    <svg class="w-4 h-4 text-slate-400 tooltip-trigger inline-block ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                    </svg>
                                    <div class="tooltip-content">${field.description}</div>
                                </span>
                                ` : ''}
                            </label>
                            <input type="${field.type}" 
                                   id="${providerId}-${field.key}"
                                   ${field.placeholder ? `placeholder="${field.placeholder}"` : ''}
                                   ${field.required ? 'required' : ''}
                                   class="w-full bg-slate-900 border border-slate-600 rounded-lg px-4 py-2.5 text-sm text-slate-300 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 outline-none transition"
                                   onchange="saveProviderData('${providerId}', '${field.key}')">
                        </div>
                    `).join('')}
                </div>

                <!-- 명령어 생성 -->
                <div class="mb-6">
                    <label class="block text-sm font-medium mb-2 text-slate-300">
                        환경 변수 설정 명령어
                        <span class="text-xs text-slate-500 ml-2">(현재 OS: <span class="font-bold ${detectedOS === 'windows' ? 'text-blue-400' : 'text-green-400'}">${detectedOS === 'windows' ? 'Windows' : 'Mac'}</span>)</span>
                    </label>
                    <div class="code-block">
                        <button class="copy-btn absolute top-2 right-2 px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-xs text-slate-300 transition" onclick="copyCode(this)">복사</button>
                        <pre id="${providerId}-commands" class="text-xs"></pre>
                    </div>
                </div>

                <div class="flex justify-between items-center mt-8">
                    <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
                    <div class="flex gap-2 items-center">
                        <span class="skip-btn" onclick="skipProviderStep('${providerId}')">나중에 설정 →</span>
                        <button class="px-6 py-2.5 bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 rounded-lg font-medium transition" onclick="nextStep()">
                            ${index === state.selectedProviders.length - 1 ? '완료 →' : '다음 →'}
                        </button>
                    </div>
                </div>
            </div>
        `;
    });
    
    container.innerHTML = html;
    
    // 명령어 업데이트
    state.selectedProviders.forEach(providerId => {
        updateProviderCommands(providerId);
        updateSha1ScriptCommand(providerId);
    });
    
    // 프로젝트 경로 표시 업데이트
    state.selectedProviders.forEach(providerId => {
        const pathDisplay = document.getElementById(`${providerId}-project-path-display`);
        if (pathDisplay) {
            pathDisplay.textContent = state.projectPath || '입력 필요';
        }
    });
}

function updateSha1ScriptCommand(providerId) {
    const provider = oauthProviders.find(p => p.id === providerId);
    if (!provider || (!provider.requiresSha1 && !provider.requiresKeyHash)) return;
    
    const commandElement = document.getElementById(`${providerId}-sha1-script-command`);
    if (!commandElement) return;
    
    const projectPath = state.projectPath || 'YOUR_PROJECT_PATH';
    const scriptName = detectedOS === 'windows' ? 'oauth-wizard-get-sha1.ps1' : 'oauth-wizard-get-sha1.sh';
    
    let command = '';
    if (detectedOS === 'windows') {
        // PowerShell 명령어
        command = `powershell -ExecutionPolicy Bypass -File "${projectPath}/.github/util/flutter/oauth-wizard/${scriptName}"`;
    } else {
        // Bash 명령어
        command = `cd "${projectPath}" && bash .github/util/flutter/oauth-wizard/${scriptName}`;
    }
    
    commandElement.textContent = command;
}

function updateProviderCommands(providerId) {
    const provider = oauthProviders.find(p => p.id === providerId);
    if (!provider) return;

    const commandsElement = document.getElementById(`${providerId}-commands`);
    if (!commandsElement) return;

    const providerData = state.providerData[providerId] || {};
    const commands = detectedOS === 'windows' ? provider.windowsCommands : provider.macCommands;
    
    let commandText = '';
    commands.forEach((cmd, index) => {
        // 실제 값으로 치환
        let finalCmd = cmd;
        
        // 각 필드의 실제 값으로 치환
        provider.fields.forEach(field => {
            const value = providerData[field.key] || `your-${field.key}`;
            const placeholder = `your-${field.key}`;
            finalCmd = finalCmd.replace(placeholder, value);
            
            // 특별한 경우 처리
            if (field.key === 'clientId' && cmd.includes('CLIENT_ID')) {
                finalCmd = finalCmd.replace('your-client-id', value);
            }
            if (field.key === 'clientSecret' && cmd.includes('CLIENT_SECRET')) {
                finalCmd = finalCmd.replace('your-client-secret', value);
            }
            if (field.key === 'restApiKey' && cmd.includes('REST_API_KEY')) {
                finalCmd = finalCmd.replace('your-rest-api-key', value);
            }
            if (field.key === 'apiKey' && cmd.includes('API_KEY')) {
                finalCmd = finalCmd.replace('your-api-key', value);
            }
            if (field.key === 'apiSecret' && cmd.includes('API_SECRET')) {
                finalCmd = finalCmd.replace('your-api-secret', value);
            }
            if (field.key === 'clientKey' && cmd.includes('CLIENT_KEY')) {
                finalCmd = finalCmd.replace('your-client-key', value);
            }
            if (field.key === 'redirectUri' && cmd.includes('REDIRECT_URI')) {
                finalCmd = finalCmd.replace('com.example.app://oauth/' + providerId, value);
            }
        });
        
        commandText += finalCmd + '\n';
    });
    
    commandsElement.textContent = commandText.trim();
}

function saveProviderData(providerId, fieldKey) {
    if (!state.providerData[providerId]) {
        state.providerData[providerId] = {};
    }
    
    const input = document.getElementById(`${providerId}-${fieldKey}`);
    if (input) {
        state.providerData[providerId][fieldKey] = input.value.trim();
        updateProviderCommands(providerId);
        saveState();
    }
}

function skipProviderStep(providerId) {
    // 해당 제공자 단계 건너뛰기
    nextStep();
}

// ============================================
// Navigation Functions
// ============================================

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

    // 마지막 Step (완료) 처리
    if (stepNumber === state.totalSteps) {
        const finalStep = document.getElementById('finalStep');
        if (finalStep) {
            finalStep.classList.remove('hidden');
            finalStep.classList.add('fade-in');
            generateResults();
        }
    }

    updateProgressSteps();
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function nextStep() {
    saveCurrentStepData();

    if (state.currentStep < state.totalSteps) {
        state.currentStep++;
        showStep(state.currentStep);
        saveState();
    }
}

function prevStep() {
    if (state.currentStep > 1) {
        saveCurrentStepData();
        state.currentStep--;
        showStep(state.currentStep);
        saveState();
    }
}

function resetWizard() {
    if (confirm('모든 데이터를 초기화하시겠습니까?')) {
        state.currentStep = 1;
        state.totalSteps = 1;
        state.projectPath = '';
        state.selectedProviders = [];
        state.providerData = {};
        state.detectedOS = detectedOS;

        clearState();

        // UI 초기화
        const projectPathInput = document.getElementById('projectPath');
        if (projectPathInput) projectPathInput.value = '';

        $$('.provider-card').forEach(card => {
            card.classList.remove('selected');
        });

        const providerStepsContainer = document.getElementById('providerSteps');
        if (providerStepsContainer) providerStepsContainer.innerHTML = '';

        showStep(1);
        updateProgressSteps();
        updateNextButton();
        showToast('마법사가 초기화되었습니다.');
    }
}

// ============================================
// Data Management Functions
// ============================================

function saveCurrentStepData() {
    switch (state.currentStep) {
        case 1:
            state.projectPath = getInputValue('projectPath');
            break;
        default:
            // Provider 단계는 이미 saveProviderData에서 저장됨
            break;
    }
    saveState();
}

// ============================================
// Provider Grid Generation
// ============================================

function generateProviderGrid() {
    const container = document.getElementById('providerGrid');
    if (!container || oauthProviders.length === 0) return;

    let html = '';
    oauthProviders.forEach(provider => {
        const isSelected = state.selectedProviders.includes(provider.id);
        html += `
            <div class="provider-card ${isSelected ? 'selected' : ''}" 
                 data-provider-id="${provider.id}"
                 onclick="toggleProvider('${provider.id}')">
                <div class="flex items-center gap-3 mb-3">
                    <span class="text-3xl">${provider.icon}</span>
                    <div>
                        <h3 class="font-bold text-lg" style="color: ${provider.color};">${provider.name}</h3>
                        <p class="text-xs text-slate-400">OAuth 2.0 지원</p>
                    </div>
                </div>
                ${isSelected ? '<div class="text-green-400 text-sm">✓ 선택됨</div>' : '<div class="text-slate-500 text-sm">클릭하여 선택</div>'}
            </div>
        `;
    });

    container.innerHTML = html;
}

// ============================================
// Results Generation
// ============================================

function generateResults() {
    const container = document.getElementById('results-container');
    if (!container) return;

    const secrets = [];
    
    state.selectedProviders.forEach(providerId => {
        const provider = oauthProviders.find(p => p.id === providerId);
        if (!provider) return;

        const providerData = state.providerData[providerId] || {};
        
        provider.fields.forEach(field => {
            const value = providerData[field.key] || '';
            if (!value && field.required) return; // 필수 필드인데 값이 없으면 스킵
            
            // Secret 이름 생성
            let secretKey = '';
            const providerName = providerId.toUpperCase();
            
            if (field.key === 'clientId') {
                secretKey = `OAUTH_${providerName}_CLIENT_ID`;
            } else if (field.key === 'clientSecret') {
                secretKey = `OAUTH_${providerName}_CLIENT_SECRET`;
            } else if (field.key === 'restApiKey') {
                secretKey = `OAUTH_${providerName}_REST_API_KEY`;
            } else if (field.key === 'apiKey') {
                secretKey = `OAUTH_${providerName}_API_KEY`;
            } else if (field.key === 'apiSecret') {
                secretKey = `OAUTH_${providerName}_API_SECRET`;
            } else if (field.key === 'bearerToken') {
                secretKey = `OAUTH_${providerName}_BEARER_TOKEN`;
            } else if (field.key === 'clientKey') {
                secretKey = `OAUTH_${providerName}_CLIENT_KEY`;
            } else if (field.key === 'redirectUri') {
                secretKey = `OAUTH_${providerName}_REDIRECT_URI`;
            } else {
                secretKey = `OAUTH_${providerName}_${field.key.toUpperCase()}`;
            }
            
            secrets.push({
                key: secretKey,
                value: value,
                desc: `${provider.name} - ${field.label}`
            });
        });
    });

    container.innerHTML = secrets.map(s => `
        <div class="result-item">
            <div class="key">
                <span>${s.key} <small style="color:#71717a">(${s.desc})</small></span>
                <button class="copy-btn-small" onclick="copyValue(this, '${s.key}')">복사</button>
            </div>
            <div class="value" id="value-${s.key}">${s.value || '(비어있음)'}</div>
        </div>
    `).join('');
}

// ============================================
// Download Functions
// ============================================

function downloadAsJson() {
    const secrets = {};
    
    state.selectedProviders.forEach(providerId => {
        const provider = oauthProviders.find(p => p.id === providerId);
        if (!provider) return;

        const providerData = state.providerData[providerId] || {};
        const providerName = providerId.toUpperCase();
        
        provider.fields.forEach(field => {
            const value = providerData[field.key] || '';
            if (!value && field.required) return;
            
            let secretKey = '';
            if (field.key === 'clientId') {
                secretKey = `OAUTH_${providerName}_CLIENT_ID`;
            } else if (field.key === 'clientSecret') {
                secretKey = `OAUTH_${providerName}_CLIENT_SECRET`;
            } else if (field.key === 'restApiKey') {
                secretKey = `OAUTH_${providerName}_REST_API_KEY`;
            } else if (field.key === 'apiKey') {
                secretKey = `OAUTH_${providerName}_API_KEY`;
            } else if (field.key === 'apiSecret') {
                secretKey = `OAUTH_${providerName}_API_SECRET`;
            } else if (field.key === 'bearerToken') {
                secretKey = `OAUTH_${providerName}_BEARER_TOKEN`;
            } else if (field.key === 'clientKey') {
                secretKey = `OAUTH_${providerName}_CLIENT_KEY`;
            } else if (field.key === 'redirectUri') {
                secretKey = `OAUTH_${providerName}_REDIRECT_URI`;
            } else {
                secretKey = `OAUTH_${providerName}_${field.key.toUpperCase()}`;
            }
            
            secrets[secretKey] = value;
        });
    });

    const jsonStr = JSON.stringify(secrets, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets-oauth.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ JSON 파일 다운로드 완료!');
}

function downloadAsTxt() {
    const lines = [
        '# GitHub Secrets for OAuth Configuration',
        '# 생성일: ' + new Date().toLocaleString('ko-KR'),
        '',
        '===== GitHub Repository Secrets =====',
        ''
    ];
    
    state.selectedProviders.forEach(providerId => {
        const provider = oauthProviders.find(p => p.id === providerId);
        if (!provider) return;

        const providerData = state.providerData[providerId] || {};
        const providerName = providerId.toUpperCase();
        
        provider.fields.forEach(field => {
            const value = providerData[field.key] || '';
            if (!value && field.required) return;
            
            let secretKey = '';
            if (field.key === 'clientId') {
                secretKey = `OAUTH_${providerName}_CLIENT_ID`;
            } else if (field.key === 'clientSecret') {
                secretKey = `OAUTH_${providerName}_CLIENT_SECRET`;
            } else if (field.key === 'restApiKey') {
                secretKey = `OAUTH_${providerName}_REST_API_KEY`;
            } else if (field.key === 'apiKey') {
                secretKey = `OAUTH_${providerName}_API_KEY`;
            } else if (field.key === 'apiSecret') {
                secretKey = `OAUTH_${providerName}_API_SECRET`;
            } else if (field.key === 'bearerToken') {
                secretKey = `OAUTH_${providerName}_BEARER_TOKEN`;
            } else if (field.key === 'clientKey') {
                secretKey = `OAUTH_${providerName}_CLIENT_KEY`;
            } else if (field.key === 'redirectUri') {
                secretKey = `OAUTH_${providerName}_REDIRECT_URI`;
            } else {
                secretKey = `OAUTH_${providerName}_${field.key.toUpperCase()}`;
            }
            
            lines.push(`${secretKey}:`);
            lines.push(value || '(미입력)');
            lines.push('');
        });
    });
    
    lines.push('=====================================');

    const txtStr = lines.join('\n');
    const blob = new Blob([txtStr], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets-oauth.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ TXT 파일 다운로드 완료!');
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
        return;
    }

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
}

function closeChangelogModal(event) {
    if (event && event.target !== event.currentTarget) return;
    const modal = document.getElementById('changelogModal');
    if (modal) {
        modal.classList.add('hidden');
    }
}

// ============================================
// Initialization
// ============================================

function initialize() {
    // OS 감지
    detectedOS = detectOS();
    state.detectedOS = detectedOS;
    
    // OS 배지 업데이트
    const osNameElement = document.getElementById('osName');
    if (osNameElement) {
        osNameElement.textContent = detectedOS === 'windows' ? 'Windows' : 'Mac';
        osNameElement.className = detectedOS === 'windows' ? 'font-bold text-blue-400' : 'font-bold text-green-400';
    }
    
    // OAuth 제공자 데이터 로드
    const loaded = loadProviders();
    if (!loaded) {
        showToast('⚠️ OAuth 제공자 데이터를 불러올 수 없습니다.');
        return;
    }
    
    // 제공자 그리드 생성
    generateProviderGrid();
    
    // 저장된 상태 로드
    const hasState = loadState();
    
    if (hasState && state.selectedProviders.length > 0) {
        generateDynamicSteps();
        showStep(state.currentStep);
        showToast('이전 진행 상태를 복원했습니다');
    } else {
        showStep(1);
    }
    
    updateProgressSteps();
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

// 페이지 언로드 시 경고
window.addEventListener('beforeunload', (e) => {
    if (state.currentStep > 1 || state.selectedProviders.length > 0) {
        e.preventDefault();
        e.returnValue = '입력한 데이터가 사라질 수 있습니다. 정말 나가시겠습니까?';
    }
});

