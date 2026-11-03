import pytest

import agent


def test_llm_points_at_ollama_cloud(monkeypatch):
    monkeypatch.setenv("OLLAMA_API_KEY", "test-key")
    llm = agent.build_llm()

    assert llm.model == agent.OLLAMA_MODEL
    assert "ollama.com" in agent.OLLAMA_BASE_URL


def test_llm_needs_an_api_key(monkeypatch):
    monkeypatch.delenv("OLLAMA_API_KEY", raising=False)

    with pytest.raises(RuntimeError, match="OLLAMA_API_KEY"):
        agent.build_llm()


def test_default_model_is_a_free_ollama_cloud_model():
    # Keep in sync with `freeCloudModels` in lib/app_config.dart.
    free = {
        "beam",
        "gemma4:31b",
        "gpt-oss:120b",
        "gpt-oss:20b",
        "nemotron-3-nano:30b",
        "nemotron-3-super",
        "nemotron-3-ultra",
    }
    assert agent.OLLAMA_MODEL in free


def test_instructions_ask_for_speakable_replies():
    text = agent.INSTRUCTIONS.lower()

    assert "never use markdown" in text
    assert "short" in text
    assert "devanagari" in text


def test_agent_name_matches_the_flutter_app():
    assert agent.AGENT_NAME == "cryonis-agent"


@pytest.mark.asyncio
async def test_voice_pipeline_can_be_built(monkeypatch):
    """Wires VAD, turn detection, STT, LLM and TTS together (no network)."""
    from livekit.plugins import silero

    monkeypatch.setenv("OLLAMA_API_KEY", "test-key")
    monkeypatch.setenv("LIVEKIT_URL", "wss://example.livekit.cloud")
    monkeypatch.setenv("LIVEKIT_API_KEY", "devkey")
    monkeypatch.setenv("LIVEKIT_API_SECRET", "x" * 40)

    session = agent.build_session(silero.VAD.load(), agent.SpeechSettings())

    assert session.llm.model == agent.OLLAMA_MODEL
    assert session.stt is not None
    assert session.tts is not None
    assert session.vad is not None


def test_speech_engine_defaults_to_livekit_inference(monkeypatch):
    # LiveKit Inference reads its credentials from the environment.
    monkeypatch.setenv("LIVEKIT_URL", "wss://example.livekit.cloud")
    monkeypatch.setenv("LIVEKIT_API_KEY", "devkey")
    monkeypatch.setenv("LIVEKIT_API_SECRET", "x" * 40)

    settings = agent.SpeechSettings.from_env({})

    assert settings.provider == "livekit"
    assert type(agent.build_stt(settings)).__module__.startswith("livekit.agents.inference")
    assert type(agent.build_tts(settings)).__module__.startswith("livekit.agents.inference")


def test_voicestudio_can_be_selected_through_its_openai_compatible_api():
    settings = agent.SpeechSettings.from_env(
        {
            "SPEECH_PROVIDER": "VoiceStudio",
            "VOICESTUDIO_URL": "http://127.0.0.1:3900/",
            "VOICESTUDIO_TTS_VOICE": "narrator",
        }
    )

    assert settings.provider == "voicestudio"
    assert settings.voicestudio_api_base == "http://127.0.0.1:3900/v1"

    tts = agent.build_tts(settings)
    stt = agent.build_stt(settings)
    assert type(tts).__module__.startswith("livekit.plugins.openai")
    assert type(stt).__module__.startswith("livekit.plugins.openai")
    assert tts.model == "tts-1"


def test_unknown_speech_provider_is_rejected():
    with pytest.raises(ValueError, match="SPEECH_PROVIDER"):
        agent.SpeechSettings.from_env({"SPEECH_PROVIDER": "elevenlabs"})


def test_greeting_is_fixed_speakable_text_not_an_llm_request():
    # The LLM answers nothing to a prompt without a user message, so the greeting
    # must be spoken as-is. It must also read well aloud.
    assert agent.GREETING.strip()
    assert len(agent.GREETING) < 100
    assert not any(ch in agent.GREETING for ch in "*#`_[]")


def _message(role, **metrics):
    from livekit.agents import llm

    return llm.ChatMessage(role=role, content=["hello"], metrics=metrics)


def test_latency_line_for_a_reply_lists_where_the_time_went():
    line = agent.latency_line(
        _message(
            "assistant",
            llm_node_ttft=0.7,
            tts_node_ttfb=0.35,
            e2e_latency=2.1,
        )
    )

    assert line == (
        "assistant turn: llm first token 0.70s, tts first audio 0.35s, total 2.10s"
    )


def test_latency_line_for_the_user_reports_transcript_and_turn_detection():
    line = agent.latency_line(
        _message("user", transcription_delay=0.4, end_of_turn_delay=0.9)
    )

    assert line == "user turn: transcript 0.40s, turn detection 0.90s"


def test_latency_line_skips_messages_without_timings():
    # The spoken greeting has no user turn, so no end-to-end figure.
    assert agent.latency_line(_message("assistant")) is None
    assert agent.latency_line(_message("system", e2e_latency=1.0)) is None
    assert agent.latency_line(object()) is None


def test_latency_line_uses_only_the_timings_present():
    line = agent.latency_line(_message("assistant", tts_node_ttfb=0.3))

    assert line == "assistant turn: tts first audio 0.30s"


def test_stt_language_defaults_to_multilingual(monkeypatch):
    monkeypatch.setenv("LIVEKIT_URL", "wss://example.livekit.cloud")
    monkeypatch.setenv("LIVEKIT_API_KEY", "devkey")
    monkeypatch.setenv("LIVEKIT_API_SECRET", "x" * 40)

    settings = agent.SpeechSettings.from_env({})

    assert settings.stt_language == "multi"
    assert agent.build_stt(settings)._opts.language == "multi"


def test_tts_defaults_match_the_deployed_bilingual_agent(monkeypatch):
    _livekit_env(monkeypatch)
    settings = agent.SpeechSettings.from_env({})

    assert settings.tts_language == "hi"
    assert settings.tts_voice == "9626c31c-bec5-4cca-baa8-f8ba9e84c8bc"
    assert agent.build_tts(settings)._opts.language == "hi"


def test_tts_language_and_voice_can_be_overridden(monkeypatch):
    _livekit_env(monkeypatch)
    settings = agent.SpeechSettings.from_env(
        {"TTS_LANGUAGE": " en ", "TTS_VOICE": "english-voice"}
    )

    tts = agent.build_tts(settings)
    assert settings.tts_language == "en"
    assert settings.tts_voice == "english-voice"
    assert tts._opts.language == "en"
    assert tts._opts.voice == "english-voice"


async def _speak(chunks):
    async def stream():
        for chunk in chunks:
            yield chunk

    return "".join([piece async for piece in agent.filter_table_pipes(stream())])


@pytest.mark.asyncio
async def test_table_filter_handles_streamed_markdown_and_preserves_plain_speech():
    assert await _speak(["| Na", "me | Ag", "e |\n|-", "--|--", "-|\n| Bob | 5 |"]) == (
        ", Name, Age, Bob, 5, "
    )
    assert await _speak(["Overall - it is fine."]) == "Overall - it is fine."
    assert await _speak(["भारत की राजधानी ", "नई दिल्ली है।"]) == (
        "भारत की राजधानी नई दिल्ली है।"
    )


def test_stt_language_can_be_fixed_from_the_environment(monkeypatch):
    monkeypatch.setenv("LIVEKIT_URL", "wss://example.livekit.cloud")
    monkeypatch.setenv("LIVEKIT_API_KEY", "devkey")
    monkeypatch.setenv("LIVEKIT_API_SECRET", "x" * 40)

    settings = agent.SpeechSettings.from_env({"STT_LANGUAGE": " en-IN "})

    assert settings.stt_language == "en-IN"
    assert agent.build_stt(settings)._opts.language == "en-IN"


def test_blank_stt_language_falls_back_to_the_default():
    # A secret set to an empty string must not leave the speech engine with no language.
    settings = agent.SpeechSettings.from_env({"STT_LANGUAGE": "  "})

    assert settings.stt_language == "multi"


def test_noise_cancellation_defaults_to_the_free_background_filter():
    settings = agent.SpeechSettings.from_env({})

    assert settings.noise_cancellation == "nc"
    assert agent.build_room_options(settings).audio_input.noise_cancellation is not None


def test_noise_cancellation_can_be_switched_off():
    settings = agent.SpeechSettings.from_env({"NOISE_CANCELLATION": "off"})

    assert settings.noise_cancellation == "off"
    # Nothing is filtered: the default room options carry no filter.
    audio_input = agent.build_room_options(settings).audio_input
    assert not getattr(audio_input, "noise_cancellation", None)


@pytest.mark.parametrize("mode", ["nc", "bvc"])
def test_noise_cancellation_can_be_enabled_from_the_environment(mode):
    settings = agent.SpeechSettings.from_env({"NOISE_CANCELLATION": f" {mode.upper()} "})

    assert settings.noise_cancellation == mode
    options = agent.build_room_options(settings)
    assert options.audio_input.noise_cancellation is not None


def test_blank_noise_cancellation_means_the_default():
    assert agent.SpeechSettings.from_env({"NOISE_CANCELLATION": " "}).noise_cancellation == "nc"


def test_unknown_noise_cancellation_mode_is_rejected():
    with pytest.raises(ValueError, match="NOISE_CANCELLATION"):
        agent.SpeechSettings.from_env({"NOISE_CANCELLATION": "krisp-max"})


def _prewarm_in_fresh_process(noise_cancellation: str | None) -> list[str]:
    """Run prewarm in a new interpreter so earlier imports in this process don't matter.

    Returns the userdata keys and whether the filter plugin ended up loaded."""
    import json
    import os
    import subprocess
    import sys

    code = (
        "import json, sys\n"
        "from types import SimpleNamespace\n"
        "import agent\n"
        "proc = SimpleNamespace(userdata={})\n"
        "agent.prewarm(proc)\n"
        "print(json.dumps([sorted(proc.userdata), 'livekit.plugins.noise_cancellation' in sys.modules]))\n"
    )
    env = {k: v for k, v in os.environ.items() if k != "NOISE_CANCELLATION"}
    if noise_cancellation is not None:
        env["NOISE_CANCELLATION"] = noise_cancellation
    env["PYTHONPATH"] = os.path.join(os.path.dirname(__file__), "..", "src")
    out = subprocess.run(
        [sys.executable, "-c", code], env=env, capture_output=True, text=True, check=True
    ).stdout.strip().splitlines()[-1]
    return json.loads(out)


def test_prewarm_loads_the_noise_filter_when_enabled():
    keys, plugin_loaded = _prewarm_in_fresh_process("nc")

    assert keys == ["vad"]
    assert plugin_loaded


def test_prewarm_loads_the_noise_filter_by_default():
    keys, plugin_loaded = _prewarm_in_fresh_process(None)

    assert keys == ["vad"]
    assert plugin_loaded


def test_prewarm_leaves_the_noise_filter_alone_when_it_is_off():
    keys, plugin_loaded = _prewarm_in_fresh_process("off")

    assert keys == ["vad"]
    assert not plugin_loaded


def test_agent_supports_english_and_hindi():
    text = agent.INSTRUCTIONS.lower()

    assert "english and hindi" in text
    assert "same mix" in text
    # The optional VoiceStudio speech-to-text detects the language per utterance.
    stt = agent.build_stt(agent.SpeechSettings.from_env({"SPEECH_PROVIDER": "voicestudio"}))
    assert stt._opts.detect_language


def _livekit_env(monkeypatch):
    monkeypatch.setenv("LIVEKIT_URL", "wss://example.livekit.cloud")
    monkeypatch.setenv("LIVEKIT_API_KEY", "devkey")
    monkeypatch.setenv("LIVEKIT_API_SECRET", "x" * 40)


def test_interruptions_need_no_words_unless_asked_for(monkeypatch):
    _livekit_env(monkeypatch)
    settings = agent.SpeechSettings.from_env({})

    assert settings.interruption_min_words == 0
    turn_handling = agent.build_turn_handling(settings)
    assert "interruption" not in turn_handling  # the library defaults apply
    assert turn_handling["preemptive_generation"] == {"enabled": True}


def test_interruptions_can_require_a_recognised_word(monkeypatch):
    _livekit_env(monkeypatch)
    settings = agent.SpeechSettings.from_env({"INTERRUPTION_MIN_WORDS": " 1 "})

    assert settings.interruption_min_words == 1
    assert agent.build_turn_handling(settings)["interruption"] == {"min_words": 1}


@pytest.mark.parametrize("bad", ["-1", "two", "1.5"])
def test_bad_interruption_min_words_is_rejected(bad):
    with pytest.raises(ValueError, match="INTERRUPTION_MIN_WORDS"):
        agent.SpeechSettings.from_env({"INTERRUPTION_MIN_WORDS": bad})


def test_blank_interruption_min_words_means_the_default():
    assert agent.SpeechSettings.from_env({"INTERRUPTION_MIN_WORDS": " "}).interruption_min_words == 0


def _state(old, new, at):
    from types import SimpleNamespace

    return SimpleNamespace(old_state=old, new_state=new, created_at=at)


def test_interruption_timer_reports_how_long_the_agent_kept_talking():
    timer = agent.InterruptionTimer()

    timer.user_state_changed(_state("listening", "speaking", 10.0))
    line = timer.agent_state_changed(_state("speaking", "listening", 11.6))

    assert line == "interruption: agent stopped 1.60s after the user started talking"


def test_interruption_timer_ignores_a_normal_turn():
    timer = agent.InterruptionTimer()

    timer.user_state_changed(_state("listening", "speaking", 5.0))
    assert timer.agent_state_changed(_state("thinking", "speaking", 7.0)) is None  # the reply starts
    assert timer.agent_state_changed(_state("speaking", "listening", 15.0)) is None  # and ends by itself


def test_interruption_timer_ignores_an_agent_that_stops_on_its_own():
    timer = agent.InterruptionTimer()

    assert timer.agent_state_changed(_state("speaking", "listening", 3.0)) is None


def test_interruption_timer_ignores_old_user_speech():
    timer = agent.InterruptionTimer()

    timer.user_state_changed(_state("listening", "speaking", 1.0))

    assert timer.agent_state_changed(_state("speaking", "listening", 40.0)) is None
    # and it does not report the same user speech twice
    assert timer.agent_state_changed(_state("speaking", "listening", 41.0)) is None
