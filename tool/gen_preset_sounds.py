"""프리셋 알림음 생성 — assets/sounds/*.wav (이슈 #121)

**파형을 직접 합성한다.** 받아온 음원을 쓰면 라이선스가 조금이라도 어긋났을 때
AdMob 계정과 앱이 함께 위험해지는데, 계산으로 만든 소리에는 그 위험이 없다.
이 스크립트가 레포에 남아 있는 한 출처가 영원히 증명된다.

`gen_alert_sound.py` 는 기본음(`alert.wav`) 전용이고 그대로 둔다 —
기존 사용자의 소리가 바뀌면 안 되기 때문이다. 이 스크립트는 **추가되는
프리셋만** 만든다.

실행:
    python tool/gen_preset_sounds.py

설계 원칙:
- **루프해도 자연스러워야 한다.** 알림음은 해제할 때까지 반복 재생되므로
  끝에 여백을 두어 연달아 붙지 않게 한다.
- **이어폰으로 듣는다.** 스피커로 나갈 일이 없으므로 저음을 과하게 넣지 않고
  귀에 가까운 대역(600~2000Hz)에 힘을 둔다.
- 피크를 -3dB 근처로 맞춰 클리핑을 피한다. 실제 크기는 앱의 볼륨 설정이 정한다.
"""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
PEAK = 0.72  # 클리핑 여유

OUT_DIR = Path("assets/sounds")


def _write(name: str, buffer: list[float]) -> None:
    peak = max(abs(v) for v in buffer) or 1.0
    scale = PEAK / peak

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    target = OUT_DIR / name

    with wave.open(str(target), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(
            b"".join(
                struct.pack("<h", max(-32768, min(32767, int(v * scale * 32767))))
                for v in buffer
            )
        )

    seconds = len(buffer) / SAMPLE_RATE
    print(f"{target}  {target.stat().st_size:>7} bytes  {seconds:.2f}s")


def _blank(seconds: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * seconds)


def _mix(buffer: list[float], start_sec: float, samples: list[float]) -> None:
    start = int(SAMPLE_RATE * start_sec)
    for i, value in enumerate(samples):
        pos = start + i
        if pos >= len(buffer):
            break
        buffer[pos] += value


# ---------------------------------------------------------------- 종소리

def bell_strike(freq: float, duration: float) -> list[float]:
    """한 번의 타종.

    **종은 배음이 정수배가 아니다.** 2배·3배로 쌓으면 오르간처럼 들린다.
    실제 종에 가까운 비조화 비율(2.0 / 3.01 / 4.17)을 쓴다.
    """
    partials = [(1.0, 1.00), (0.45, 2.00), (0.28, 3.01), (0.15, 4.17)]
    length = int(SAMPLE_RATE * duration)
    out = [0.0] * length

    for n in range(length):
        t = n / SAMPLE_RATE
        # 아주 빠른 어택 — 금속을 때리는 순간
        attack = min(1.0, t / 0.003)
        value = 0.0
        for amp, ratio in partials:
            # 높은 배음일수록 빨리 사라진다 (실제 금속의 감쇠)
            decay = math.exp(-(2.6 + ratio * 0.9) * t / duration)
            value += amp * decay * math.sin(2 * math.pi * freq * ratio * t)
        out[n] = attack * value

    return out


def make_bell() -> None:
    """반복적인 종소리. 두 번 울리고 여운을 남긴다."""
    total = 2.4
    buffer = _blank(total)

    _mix(buffer, 0.00, bell_strike(784.0, 1.5))   # G5
    _mix(buffer, 0.62, bell_strike(784.0, 1.5))

    _write("bell.wav", buffer)


# ---------------------------------------------------------------- 전자음

def square(freq: float, duration: float, harmonics: int = 9) -> list[float]:
    """구형파에 가까운 소리.

    홀수 배음만 더한다. 무한히 더하면 진짜 구형파지만 그러면 고역이
    거칠어 이어폰으로 듣기 힘들다 — 9개에서 끊는다.
    """
    length = int(SAMPLE_RATE * duration)
    out = [0.0] * length

    for n in range(length):
        t = n / SAMPLE_RATE
        # 앞뒤로 짧은 페이드 — 딸깍 소리를 없앤다
        fade = min(1.0, t / 0.004, (duration - t) / 0.004)
        value = 0.0
        for k in range(1, harmonics + 1, 2):
            value += math.sin(2 * math.pi * freq * k * t) / k
        out[n] = max(0.0, fade) * value

    return out


def make_electronic() -> None:
    """강한 전자음. 짧게 세 번 — 놓치기 어렵게."""
    total = 1.5
    buffer = _blank(total)

    for i in range(3):
        _mix(buffer, i * 0.19, square(1046.5, 0.11))  # C6

    _write("electronic.wav", buffer)


# ---------------------------------------------------------------- 사이렌

def sweep(low: float, high: float, duration: float) -> list[float]:
    """주파수를 오르내린다.

    **위상을 누적한다.** 매 샘플마다 `sin(2πft)` 를 새로 계산하면 주파수가
    바뀔 때 파형이 끊겨 잡음이 섞인다.
    """
    length = int(SAMPLE_RATE * duration)
    out = [0.0] * length
    phase = 0.0

    for n in range(length):
        t = n / SAMPLE_RATE
        # 0 → 1 → 0 으로 오르내린다
        position = math.sin(math.pi * t / duration)
        freq = low + (high - low) * position
        phase += 2 * math.pi * freq / SAMPLE_RATE
        fade = min(1.0, t / 0.01, (duration - t) / 0.01)
        # 3배음을 살짝 섞어 날카롭게
        out[n] = max(0.0, fade) * (
            math.sin(phase) + 0.22 * math.sin(3 * phase)
        )

    return out


def make_siren() -> None:
    """급함을 알리는 소리. 두 번 오르내린다."""
    total = 1.9
    buffer = _blank(total)

    _mix(buffer, 0.00, sweep(620.0, 1180.0, 0.75))
    _mix(buffer, 0.80, sweep(620.0, 1180.0, 0.75))

    _write("siren.wav", buffer)


# ---------------------------------------------------------------- 차임

def soft_tone(freq: float, duration: float) -> list[float]:
    """부드러운 사인 음. 배음을 거의 넣지 않는다."""
    length = int(SAMPLE_RATE * duration)
    out = [0.0] * length

    for n in range(length):
        t = n / SAMPLE_RATE
        # 느린 어택 — 놀라지 않게
        attack = min(1.0, t / 0.035)
        decay = math.exp(-3.0 * t / duration)
        out[n] = attack * decay * (
            math.sin(2 * math.pi * freq * t)
            + 0.18 * math.sin(2 * math.pi * freq * 2 * t)
        )

    return out


def make_chime() -> None:
    """부드러운 하강 3음. 기본음보다 조용한 자리를 채운다."""
    total = 2.6
    buffer = _blank(total)

    for i, freq in enumerate([1318.51, 1046.50, 783.99]):  # E6 - C6 - G5
        _mix(buffer, i * 0.28, soft_tone(freq, 1.1))

    _write("chime.wav", buffer)


def main() -> None:
    make_bell()
    make_electronic()
    make_siren()
    make_chime()


if __name__ == "__main__":
    main()
