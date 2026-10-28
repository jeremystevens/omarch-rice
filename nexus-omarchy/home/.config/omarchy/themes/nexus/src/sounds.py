#!/usr/bin/env python3
"""Synthesises the two NEXUS UI cues: short, quiet sine blips with soft edges."""
import math, struct, sys, wave

RATE = 44100

def tone(freq, ms, amp):
    n = int(RATE * ms / 1000)
    fade = int(RATE * 0.006)
    out = []
    for i in range(n):
        env = min(1, i / fade, (n - i) / fade)
        out.append(amp * env * math.sin(2 * math.pi * freq * i / RATE))
    return out

def silence(ms):
    return [0.0] * int(RATE * ms / 1000)

def write(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))

out = sys.argv[1]
write(f"{out}/deck-open.wav", tone(1320, 28, .16) + silence(22) + tone(1980, 40, .12))
write(f"{out}/battery-low.wav", tone(880, 90, .18) + silence(40) + tone(660, 140, .18))
