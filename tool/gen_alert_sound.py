"""알림음 생성 — assets/sounds/alert.wav

내부망이라 음원을 받을 수 없어 파형을 직접 합성한다.
교체할 때는 같은 이름/포맷(44.1kHz 16bit mono WAV)으로 덮어쓰면 된다.

설계:
- 상승 3음 차임(A5 - C#6 - E6). 경보음이 아니라 "도착 알림"이라
  놀라게 하지 않으면서 주의는 끌어야 한다.
- 각 음은 기음 + 2배음(약하게)으로 종소리 느낌을 낸다.
- 마지막에 여백을 둔다. 루프 재생 시 연달아 붙지 않게 하기 위해서다.
"""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
NOTES = [880.00, 1108.73, 1318.51]  # A5, C#6, E6
NOTE_SECONDS = 0.22
NOTE_GAP_SECONDS = 0.10   # 음 시작 간격 = NOTE_GAP + ... (겹치게 둔다)
TAIL_SECONDS = 0.85       # 루프 사이 여백
PEAK = 0.72               # 클리핑 여유


def envelope(t: float, duration: float) -> float:
    """빠른 어택 + 지수 감쇠. 종소리처럼 들리게 한다."""
    attack = 0.006
    if t < attack:
        return t / attack
    return math.exp(-4.2 * (t - attack) / duration)


def main() -> None:
    stride = NOTE_SECONDS * 0.45 + NOTE_GAP_SECONDS
    total = stride * (len(NOTES) - 1) + NOTE_SECONDS + TAIL_SECONDS
    frames = int(SAMPLE_RATE * total)
    buffer = [0.0] * frames

    for index, freq in enumerate(NOTES):
        start = int(SAMPLE_RATE * stride * index)
        length = int(SAMPLE_RATE * NOTE_SECONDS)
        for n in range(length):
            position = start + n
            if position >= frames:
                break
            t = n / SAMPLE_RATE
            env = envelope(t, NOTE_SECONDS)
            sample = math.sin(2 * math.pi * freq * t)
            sample += 0.28 * math.sin(2 * math.pi * freq * 2 * t)  # 2배음
            buffer[position] += env * sample

    peak = max(abs(v) for v in buffer) or 1.0
    scale = PEAK / peak

    # 레포 루트 기준 — `python tool/gen_alert_sound.py` 로 실행한다
    target = Path("assets/sounds/alert.wav")
    target.parent.mkdir(parents=True, exist_ok=True)

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

    print(f"{target} {target.stat().st_size} bytes, {total:.2f}s")


if __name__ == "__main__":
    main()
