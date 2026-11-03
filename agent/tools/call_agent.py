"""Call the deployed agent like the app does, ask spoken questions, print what it heard and said.

    uv run --with numpy python tools/call_agent.py <token-server-id> tools/questions.json

questions.json is a list of [macOS voice, question]; each question is spoken with `say`, so this
needs a Mac. It joins a real room (dispatching the agent by name), so every run spends a little of
LiveKit's free inference credit: keep the list short. The token-server ID is the sandbox ID of your
LiveKit project's development token server (the same one the app uses).
"""

import asyncio
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
import wave

import numpy as np
from livekit import rtc

SANDBOX_ID = sys.argv[1]
QUESTIONS = json.load(open(sys.argv[2]))
AGENT_NAME = os.getenv("AGENT_NAME", "cryonis-agent")
SR = 48000
FRAME = SR // 100
WORK = tempfile.mkdtemp(prefix="call_agent_")
T0 = time.perf_counter()


def log(message: str) -> None:
    print(f"{time.perf_counter() - T0:6.2f}s  {message}", flush=True)


def connection():
    body = {
        "room_name": f"cryonis-test-{int(time.time())}",
        "participant_name": "test-client",
        "room_config": {"agents": [{"agent_name": AGENT_NAME}]},
    }
    request = urllib.request.Request(
        "https://cloud-api.livekit.io/api/v2/sandbox/connection-details",
        data=json.dumps(body).encode(),
        headers={
            "X-Sandbox-ID": SANDBOX_ID,
            "Content-Type": "application/json",
            "User-Agent": "cryonis-call-test/1.0",  # the default urllib agent is blocked (HTTP 403)
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        data = json.loads(response.read())
    return data["server_url"], data["participant_token"]


def synthesize(voice: str, text: str) -> np.ndarray:
    aiff, wav = f"{WORK}/q.aiff", f"{WORK}/q.wav"
    subprocess.run(["say", "-v", voice, "-o", aiff, text], check=True)
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", "-c", "1", aiff, wav], check=True
    )
    with wave.open(wav) as w:
        assert w.getframerate() == SR and w.getnchannels() == 1
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)


async def main() -> None:
    # Build every clip first: `say` blocks the event loop, which would starve the live call.
    clips = [(voice, text, synthesize(voice, text)) for voice, text in QUESTIONS]

    url, token = connection()
    room = rtc.Room()
    agent_state = {"now": None}
    heard, said = [], []
    queue: asyncio.Queue = asyncio.Queue()
    ready, greeting_done, answered = asyncio.Event(), asyncio.Event(), asyncio.Event()
    asking = {"on": False}

    @room.on("participant_attributes_changed")
    def _(changed, participant):
        if "lk.agent.state" in changed:
            new = changed["lk.agent.state"]
            was, agent_state["now"] = agent_state["now"], new
            if new == "listening":
                ready.set()
                if asking["on"] and was in ("speaking", "thinking"):
                    answered.set()
                elif not asking["on"] and was == "speaking":
                    greeting_done.set()

    @room.on("track_subscribed")
    def _(track, publication, participant):
        if track.kind == rtc.TrackKind.KIND_AUDIO:

            async def drain():
                async for _ in rtc.AudioStream(track, sample_rate=SR, num_channels=1):
                    pass

            asyncio.create_task(drain())

    async def on_text(reader, identity):
        try:
            text = await reader.read_all()
        except Exception:
            return
        attrs = reader.info.attributes or {}
        mine = identity == room.local_participant.identity
        final = attrs.get("lk.transcription_final") == "true"
        if text.strip() and (final or not attrs.get("lk.transcribed_track_id")):
            (heard if mine else said).append(text.strip())

    room.register_text_stream_handler(
        "lk.transcription",
        lambda reader, identity: asyncio.get_running_loop().create_task(on_text(reader, identity)),
    )
    await room.connect(url, token, options=rtc.RoomOptions(auto_subscribe=True))
    source = rtc.AudioSource(SR, 1)
    track = rtc.LocalAudioTrack.create_audio_track("mic", source)
    await room.local_participant.publish_track(
        track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE)
    )

    async def feeder():
        silence = np.zeros(FRAME, dtype=np.int16)
        while True:
            try:
                chunk = queue.get_nowait()
            except asyncio.QueueEmpty:
                chunk = silence
            await source.capture_frame(rtc.AudioFrame(chunk.tobytes(), SR, 1, FRAME))
            await asyncio.sleep(0.0)

    feed = asyncio.create_task(feeder())

    # A cold agent takes 10-20 s to join. The first "listening" event can arrive
    # before its fixed greeting; wait until that greeting has spoken and returned
    # to listening so it cannot be mistaken for the first answer.
    try:
        await asyncio.wait_for(ready.wait(), timeout=60)
        log("agent is listening")
    except asyncio.TimeoutError:
        log("the agent did not join within 60 s")
        feed.cancel()
        await room.disconnect()
        return
    try:
        await asyncio.wait_for(greeting_done.wait(), timeout=12)
        log("greeting finished")
    except asyncio.TimeoutError:
        # Also supports agents configured without a greeting.
        log("no greeting observed; continuing")

    for voice, question, clip in clips:
        heard0, said0 = len(heard), len(said)
        answered.clear()
        asking["on"] = True
        for i in range(0, len(clip), FRAME):
            part = clip[i : i + FRAME]
            if part.size < FRAME:
                part = np.pad(part, (0, FRAME - part.size))
            queue.put_nowait(part)
        try:
            await asyncio.wait_for(answered.wait(), timeout=60)
        except asyncio.TimeoutError:
            log("TIMEOUT waiting for the answer")
        asking["on"] = False
        await asyncio.sleep(1.5)
        print(f"[{voice}] ASKED: {question}")
        print(f"        HEARD: {' | '.join(heard[heard0:]) or '(nothing)'}")
        print(f"        SAID : {' | '.join(said[said0:])[:200] or '(nothing)'}", flush=True)

    feed.cancel()
    await room.disconnect()


asyncio.run(main())
