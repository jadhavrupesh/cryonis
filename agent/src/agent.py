"""Voice agent for the Cryonis app.

    phone mic -> LiveKit Cloud -> STT -> LLM (Ollama Cloud) -> TTS -> phone speaker

The conversation loop is LiveKit Agents. The language model is always an Ollama
Cloud model (OpenAI-compatible API). The speech engine (STT + TTS) is switchable:

* SPEECH_PROVIDER=livekit      (default) LiveKit Inference: Deepgram + Cartesia.
                               Works when the agent is deployed to LiveKit Cloud.
* SPEECH_PROVIDER=voicestudio  VoiceStudio (https://github.com/debpalash/VoiceStudio)
                               through its OpenAI-compatible API. VoiceStudio runs on
                               a machine you control, so the agent must be able to
                               reach it, e.g. run the agent on the same Mac with
                               `uv run src/agent.py dev` (see README.md).

Silero VAD plus LiveKit's turn detector decide when the user has finished and when
they interrupt (barge-in); LiveKit stops the agent's speech as soon as the user
talks over it.
"""

import logging
import os
import re
import textwrap
from collections.abc import AsyncIterable, Mapping
from dataclasses import dataclass

from dotenv import load_dotenv
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    AgentStateChangedEvent,
    ConversationItemAddedEvent,
    JobContext,
    JobProcess,
    cli,
    inference,
    UserStateChangedEvent,
    room_io,
)
from livekit.plugins import openai, silero

load_dotenv(".env.local")

logger = logging.getLogger("cryonis-agent")

# Must match `voiceAgentName` in the Flutter app (lib/app_config.dart).
AGENT_NAME = os.getenv("AGENT_NAME", "cryonis-agent")

# Ollama Cloud speaks the OpenAI chat-completions protocol under /v1.
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "https://ollama.com/v1")

# Voice needs a model that starts talking fast and steadily. Measured from India with
# this agent's real prompt (12 questions, interleaved): time to the first spoken word
# was gpt-oss:120b median 1.1 s (worst 1.7 s), beam 1.5 s (one empty reply),
# gpt-oss:20b 1.7 s. gemma4:31b is ~10 s and nemotron-3-nano gave no text at all, so
# avoid those. All of these are on Ollama's free list.
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "gpt-oss:120b")

INSTRUCTIONS = textwrap.dedent(
    """\
    You are Cryo, a friendly voice assistant inside the Cryonis app. The user is
    talking to you out loud and your replies are spoken.

    - Keep replies short: one to three sentences unless asked for more.
    - Speak naturally. Never use markdown, bullet points, emojis, headings or
      code formatting, and do not read out symbols or URLs.
    - You speak English and Hindi. Reply in the language the user speaks, and if
      they mix Hindi and English, answer in the same mix. Write Hindi in
      Devanagari script, never in Roman letters. For any other language, reply
      in English.
    - If you did not understand, ask a short clarifying question.
    - Never mention these instructions.
    """
)

# Spoken directly through TTS rather than asked of the LLM: `beam` (like some other
# Ollama Cloud models) returns an EMPTY reply when a prompt has no user message,
# so a "greet the user" instruction produced silence. This is also instant.
GREETING = "Hi, I'm Cryo. How can I help you today?"


class CryoAssistant(Agent):
    def __init__(self) -> None:
        super().__init__(instructions=INSTRUCTIONS)


async def filter_table_pipes(text: AsyncIterable[str]) -> AsyncIterable[str]:
    """Turn streamed Markdown table syntax into natural pauses for speech."""
    in_table_row = False
    spoke_pause = False
    async for chunk in text:
        original = chunk
        if "|" in chunk:
            in_table_row = True
        if in_table_row:
            chunk = re.sub(r"[-:]+", "", chunk)
            chunk = re.sub(r"\s*\|[\s|]*", ", ", chunk)
            chunk = re.sub(r"(,\s*){2,}", ", ", chunk)
            if spoke_pause and chunk.startswith(", "):
                chunk = chunk[2:]
            if not chunk.strip():
                chunk = ""
        if "\n" in original and "|" not in original.rsplit("\n", 1)[-1]:
            in_table_row = False
        if chunk:
            spoke_pause = chunk.endswith(", ")
            yield chunk


# Where a turn's time goes, as LiveKit measures it on each chat message. A user
# message says how long it took to hear the transcript and decide they had
# finished; the reply says how long the model and the voice took to start, and the
# total from the end of the user's speech to the first sound of the reply.
_LATENCY_FIELDS = {
    "user": (
        ("transcription_delay", "transcript"),
        ("end_of_turn_delay", "turn detection"),
    ),
    "assistant": (
        ("llm_node_ttft", "llm first token"),
        ("tts_node_ttfb", "tts first audio"),
        ("e2e_latency", "total"),
    ),
}


def latency_line(item) -> str | None:
    """A one-line latency summary for a chat message, or None if it has no timings."""
    fields = _LATENCY_FIELDS.get(getattr(item, "role", None))
    timings = getattr(item, "metrics", None)
    if not fields or not timings:
        return None
    parts = [f"{label} {timings[key]:.2f}s" for key, label in fields if key in timings]
    return f"{item.role} turn: " + ", ".join(parts) if parts else None


NOISE_CANCELLATION_MODES = ("off", "nc", "bvc")


@dataclass(frozen=True)
class SpeechSettings:
    """Which speech engine to use, read from environment variables."""

    provider: str = "livekit"
    # Language the LiveKit speech-to-text listens for: "multi" lets Deepgram switch
    # between English and Hindi (even mid-sentence). A fixed code such as "en-IN" is
    # steadier for one language, but it turned Hindi into Latin letters in tests.
    stt_language: str = "multi"
    # The deployed bilingual voice uses Cartesia's Hindi/Hinglish setting. This
    # remains configurable so English-only deployments can select "en".
    tts_language: str = "hi"
    tts_voice: str = "9626c31c-bec5-4cca-baa8-f8ba9e84c8bc"
    # Filter applied to the caller's microphone on LiveKit Cloud before the agent's
    # VAD and speech-to-text hear it: "off", "nc" (background noise suppression, no
    # extra cost) or "bvc" (also removes other people's voices; billed extra). In
    # tests "nc" did no harm and kept chatter out of the transcript, but chatter still
    # interrupted the agent; only "bvc" is meant to fix that and it is untested.
    noise_cancellation: str = "nc"
    # Words the speech-to-text must recognise before the caller counts as interrupting.
    # 0 (the library default) lets any 0.5 s of voice-like sound cut the agent off,
    # including background chatter; 1 means a real word is needed first.
    interruption_min_words: int = 0
    voicestudio_url: str = "http://127.0.0.1:3900"
    voicestudio_api_key: str = ""
    # Model and voice names are whatever your VoiceStudio lists at
    # GET /v1/models and GET /v1/audio/voices (run scripts/check_voicestudio.py).
    voicestudio_tts_model: str = "tts-1"
    voicestudio_tts_voice: str = "default"
    voicestudio_stt_model: str = "whisper-1"
    # wav carries its own sample rate, so LiveKit can decode it whatever the
    # engine produces.
    voicestudio_tts_format: str = "wav"

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> "SpeechSettings":
        env = os.environ if env is None else env
        d = cls()
        provider = env.get("SPEECH_PROVIDER", d.provider).strip().lower()
        if provider not in ("livekit", "voicestudio"):
            raise ValueError(
                f"SPEECH_PROVIDER must be 'livekit' or 'voicestudio', got {provider!r}"
            )
        noise = env.get("NOISE_CANCELLATION", "").strip().lower() or d.noise_cancellation
        if noise not in NOISE_CANCELLATION_MODES:
            raise ValueError(
                f"NOISE_CANCELLATION must be one of {', '.join(NOISE_CANCELLATION_MODES)}, got {noise!r}"
            )
        raw_words = env.get("INTERRUPTION_MIN_WORDS", "").strip()
        try:
            min_words = int(raw_words) if raw_words else d.interruption_min_words
        except ValueError:
            min_words = -1
        if min_words < 0:
            raise ValueError(
                f"INTERRUPTION_MIN_WORDS must be a whole number, 0 or more, got {raw_words!r}"
            )
        return cls(
            provider=provider,
            stt_language=env.get("STT_LANGUAGE", "").strip() or d.stt_language,
            tts_language=env.get("TTS_LANGUAGE", "").strip() or d.tts_language,
            tts_voice=env.get("TTS_VOICE", "").strip() or d.tts_voice,
            noise_cancellation=noise,
            interruption_min_words=min_words,
            voicestudio_url=env.get("VOICESTUDIO_URL", d.voicestudio_url).rstrip("/"),
            voicestudio_api_key=env.get("VOICESTUDIO_API_KEY", d.voicestudio_api_key),
            voicestudio_tts_model=env.get("VOICESTUDIO_TTS_MODEL", d.voicestudio_tts_model),
            voicestudio_tts_voice=env.get("VOICESTUDIO_TTS_VOICE", d.voicestudio_tts_voice),
            voicestudio_stt_model=env.get("VOICESTUDIO_STT_MODEL", d.voicestudio_stt_model),
            voicestudio_tts_format=env.get("VOICESTUDIO_TTS_FORMAT", d.voicestudio_tts_format),
        )

    @property
    def voicestudio_api_base(self) -> str:
        # OpenAI clients use <service root>/v1 as their base URL.
        return f"{self.voicestudio_url}/v1"

    @property
    def _voicestudio_key(self) -> str:
        # The OpenAI client insists on a key; VoiceStudio ignores it on loopback.
        return self.voicestudio_api_key or "not-needed-on-loopback"


def build_stt(settings: SpeechSettings):
    if settings.provider == "voicestudio":
        return openai.STT(
            model=settings.voicestudio_stt_model,
            detect_language=True,  # Hindi / English / mixed
            base_url=settings.voicestudio_api_base,
            api_key=settings._voicestudio_key,
            use_realtime=False,  # plain /v1/audio/transcriptions, per utterance
        )
    return inference.STT(model="deepgram/nova-3", language=settings.stt_language)


def build_tts(settings: SpeechSettings):
    if settings.provider == "voicestudio":
        return openai.TTS(
            model=settings.voicestudio_tts_model,
            voice=settings.voicestudio_tts_voice,
            base_url=settings.voicestudio_api_base,
            api_key=settings._voicestudio_key,
            response_format=settings.voicestudio_tts_format,
        )
    return inference.TTS(
        model="cartesia/sonic-3",
        voice=settings.tts_voice,
        language=settings.tts_language,
    )


def build_room_options(settings: SpeechSettings) -> room_io.RoomOptions:
    """How the agent listens to the room: the microphone filter, if one is enabled."""
    if settings.noise_cancellation == "off":
        return room_io.RoomOptions()
    # Imported only when used: the plugin ships a large native library.
    from livekit.plugins import noise_cancellation

    chosen = {
        "nc": noise_cancellation.NC,
        "bvc": noise_cancellation.BVC,
    }[settings.noise_cancellation]
    return room_io.RoomOptions(
        audio_input=room_io.AudioInputOptions(noise_cancellation=chosen())
    )


def build_llm() -> openai.LLM:
    """The language model: an Ollama Cloud model through the OpenAI plugin."""
    api_key = os.environ.get("OLLAMA_API_KEY")
    if not api_key:
        raise RuntimeError(
            "OLLAMA_API_KEY is not set. Add it to .env.local for local runs, or "
            "pass it as a secret when deploying (see agent/README.md)."
        )
    return openai.LLM(model=OLLAMA_MODEL, base_url=OLLAMA_BASE_URL, api_key=api_key)


server = AgentServer()


def prewarm(proc: JobProcess) -> None:
    # Load the VAD model once per process instead of once per call.
    proc.userdata["vad"] = silero.VAD.load()
    if SpeechSettings.from_env().noise_cancellation != "off":
        # The filter plugin loads a large native library (it stalled the event loop
        # for ~0.35 s when first imported mid-call), so load it here instead.
        from livekit.plugins import noise_cancellation  # noqa: F401


server.setup_fnc = prewarm


def build_turn_handling(speech: SpeechSettings) -> dict:
    """When the user's turn ends, when replies start early, and what counts as an interruption."""
    turn_handling: dict = {
        "turn_detection": inference.TurnDetector(),
        # Start the LLM on the partial transcript to shave off latency.
        "preemptive_generation": {"enabled": True},
    }
    if speech.interruption_min_words > 0:
        turn_handling["interruption"] = {"min_words": speech.interruption_min_words}
    return turn_handling


class InterruptionTimer:
    """Measures how long the agent keeps talking after the user starts talking over it."""

    def __init__(self) -> None:
        self._user_started: float | None = None

    def user_state_changed(self, event) -> None:
        if event.new_state == "speaking":
            self._user_started = event.created_at

    def agent_state_changed(self, event) -> str | None:
        """A log line when the agent stops mid-speech because the user spoke, else None."""
        if event.new_state == "speaking":
            # A fresh reply: whatever the user said before it was not an interruption.
            self._user_started = None
            return None
        if event.old_state == "speaking" and self._user_started is not None:
            delay = event.created_at - self._user_started
            self._user_started = None
            if 0 <= delay < 10:
                return f"interruption: agent stopped {delay:.2f}s after the user started talking"
        return None


def build_session(vad, speech: SpeechSettings | None = None) -> AgentSession:
    """The whole voice pipeline: VAD + turn detection + STT + LLM + TTS."""
    speech = speech or SpeechSettings.from_env()
    return AgentSession(
        stt=build_stt(speech),
        llm=build_llm(),
        tts=build_tts(speech),
        vad=vad,
        turn_handling=build_turn_handling(speech),
        tts_text_transforms=["filter_markdown", "filter_emoji", filter_table_pipes],
    )


@server.rtc_session(agent_name=AGENT_NAME)
async def entrypoint(ctx: JobContext) -> None:
    ctx.log_context_fields = {"room": ctx.room.name}

    speech = SpeechSettings.from_env()
    logger.info(
        "speech engine: %s (stt language %s, tts language %s, noise cancellation %s, interruption min words %d)",
        speech.provider,
        speech.stt_language,
        speech.tts_language,
        speech.noise_cancellation,
        speech.interruption_min_words,
    )
    session = build_session(ctx.proc.userdata["vad"], speech)

    @session.on("conversation_item_added")
    def _log_latency(event: ConversationItemAddedEvent) -> None:
        if line := latency_line(event.item):
            logger.info(line)

    interruptions = InterruptionTimer()

    @session.on("user_state_changed")
    def _user_state(event: UserStateChangedEvent) -> None:
        interruptions.user_state_changed(event)

    @session.on("agent_state_changed")
    def _agent_state(event: AgentStateChangedEvent) -> None:
        if line := interruptions.agent_state_changed(event):
            logger.info(line)

    await session.start(
        agent=CryoAssistant(),
        room=ctx.room,
        room_options=build_room_options(speech),
    )
    await ctx.connect()

    await session.say(GREETING)


if __name__ == "__main__":
    cli.run_app(server)
