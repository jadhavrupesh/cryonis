# Cryonis voice agent

The backend for the voice screen. It is a LiveKit Agent that **runs on LiveKit Cloud**, so nothing has
to run on your own machine:

```
phone mic ─► LiveKit Cloud ─► STT  (LiveKit Inference · Deepgram nova-3, multilingual)
                           ─► LLM  (Ollama Cloud · OpenAI-compatible · default model: gpt-oss:120b)
                           ─► TTS  (LiveKit Inference · Cartesia sonic-3) ─► phone speaker
```

Silero VAD and LiveKit's turn detector decide when you have finished talking and when you interrupt;
the agent stops speaking as soon as you talk over it. STT and TTS run on LiveKit Inference, so the only
secret you provide is your Ollama Cloud key.

## Why `gpt-oss:120b`

Time to the first spoken word matters most for voice, and the language model is the slowest stage (see
the next section). Measured from India against Ollama Cloud's free models with this agent's real
system prompt, requests interleaved so server load is shared:

| Model | First text, median | Notes |
|---|---|---|
| `gpt-oss:120b` | 0.75 s (20 requests) | no failures in 38 requests over three tests |
| `beam` | 1.29 s (20 requests) | 3 of 38 requests streamed reasoning but never any text; in a call that is a long silence |
| `gpt-oss:20b` | about 1.7 s | |
| `nemotron-3-nano:30b` | no text | spent its whole token budget on reasoning; avoid |
| `gemma4:31b` | about 10 s | far too slow |

Medians move with server load (`gpt-oss:120b` measured 1.6, 1.1, then 0.75 s in three runs), so treat
gaps under about 0.3 s as noise. In the deployed agent the model's first token took a median 1.44 s
with `gpt-oss:120b` (5 calls) against 1.58 s with `beam` (8 calls). Override with `OLLAMA_MODEL`
(keep it on Ollama's free list).

## Languages: English and Hindi

The agent speaks and understands English and Hindi, including mixes. The instructions tell it to reply in
the language the user speaks, to answer a Hindi/English mix with the same mix, and to write Hindi in
Devanagari. `STT_LANGUAGE` (default `multi`) sets what Deepgram nova-3 listens for; `multi` is the setting
that handles Hindi and English, even mid-sentence. `TTS_LANGUAGE` defaults to `hi`, matching the deployed
Hindi/Hinglish Cartesia voice configuration; set it to `en` for an English-only deployment.

Tested with synthetic macOS voices (27 Oct 2026):

- `multi` mis-heard 5 of 23 English utterances (for example "in a leap year" as "in Alipay", "Romeo and
  Juliet" as "Minh Juliet", or one nonsense string). A fixed `en-IN` mis-heard 1 of 7, the same "Alipia" slip, so no real gain, and it turned
  Hindi into Latin letters. So `multi` stays.
- Hindi under `multi`: all 5 pure-Hindi questions were transcribed exactly; one mixed Hindi/English sentence
  heard "Moon" as "मुंह".
- Spoken Hindi output: Cryo's Hindi answer (12 s of audio) was replayed to the speech-to-text as if a person
  said it and came back as nearly the same sentences, with a few rare words slipping. So the Hindi speech is
  intelligible; how natural it sounds has not been judged by ear.

Change the language on the deployed agent without a rebuild:

```bash
lk agent update-secrets --secrets STT_LANGUAGE=en-IN TTS_LANGUAGE=en
```

Never add `--overwrite`: it asks to remove every other secret, including your Ollama key. The agent logs the
settings it started with (`speech engine: livekit (stt language multi, tts language hi, noise cancellation nc, interruption min words 0)`).
The optional VoiceStudio speech path detects the language per utterance instead.

## Background noise and interruptions

Two settings, both changeable with `lk agent update-secrets --secrets KEY=VALUE` (no rebuild):

- `NOISE_CANCELLATION` (default `nc`): a filter LiveKit Cloud applies to the caller's microphone before the
  agent's voice detector and speech-to-text hear it. `nc` is Krisp background-noise suppression; the docs list
  it at no extra cost and it ran without errors on the free Build plan. `bvc` is voice isolation (also removes
  other people's voices); the docs say it is billed extra and it has **not been tried**. `off` disables the
  filter. The filter plugin is loaded when the agent process starts, so it does not stall the first call.
- `INTERRUPTION_MIN_WORDS` (default `0`): how many recognised words the speech-to-text needs before the
  caller counts as interrupting. LiveKit's own defaults also apply: speech must last 0.5 s, and the agent
  resumes if the interruption turns out to be false.

What was measured (27 Oct to 2 Nov 2026, synthetic voices; times are from the agent's own log, not the caller):

| Situation | Result |
|---|---|
| A clear "Stop." while the agent counts aloud | the agent stopped **0.19 s** after the caller started talking |
| Traffic-like rumble for 4 s | did not interrupt the agent, with the filter on or off |
| Four voices talking over each other for 5 s, filter on | still interrupted the agent (stopped 0.40 s after the chatter began) and it never resumed counting. The speech-to-text transcribed no chatter words; with the filter off, one run transcribed "I have tried" and the agent answered "I didn't catch that". That is one observation, not proof the filter helps |
| `INTERRUPTION_MIN_WORDS=1`, filter on | chatter **still** interrupted (0.81 s), and a real "Stop." took 0.52 s instead of 0.19 s. Calls made from the phone while it was on logged stops of 1.18 s and 2.68 s. So it is left at 0 |

**Not solved:** voice-like background chatter can still cut the agent off mid-answer. The remaining candidate
is `NOISE_CANCELLATION=bvc` (voice isolation), which costs extra and needs your go-ahead before enabling.

**Correction.** An earlier version of these notes said the agent took about 1.6 s to stop when interrupted and
that chatter silenced it at once. Both were artifacts of the test script: it blocked while synthesising audio
mid-call, and its microphone source queued about a second of silence ahead of the speech, which shifts
every client-side offset by roughly a second. Use the server-side log lines
(`interruption: agent stopped X s after the user started talking`), not timings measured by a test client.

## Where the time goes

The agent logs one line per turn (watch them live with `lk agent logs`):

```
user turn: transcript 0.22s, turn detection 0.58s
assistant turn: llm first token 1.44s, tts first audio 0.09s, total 1.86s
interruption: agent stopped 0.19s after the user started talking
```

`total` is the time from the end of your speech to the first sound of the reply. Measured on the
deployed agent: transcript about 0.2 s; turn detection about 0.6 s, which runs alongside the model call
(preemptive generation), so shortening it saves nothing; model first token 0.9 to 3.2 s; voice first
audio about 0.1 s. Totals were 1.4 to 3.5 s with `beam` (median 2.0 s) and 1.4 to 2.0 s with
`gpt-oss:120b` (median 1.9 s). Network and audio playback add to what you hear.

## Deployment

Each contributor or fork owner deploys `cryonis-agent` to their own LiveKit Cloud project. The real
`livekit.toml` is local and ignored because it contains project-specific deployment identifiers.

1. Create a free LiveKit Cloud account and a project at <https://cloud.livekit.io>.
2. Install the CLI and link it to the project (opens a browser to sign in):

   ```bash
   brew install livekit-cli
   lk cloud auth
   ```

3. Put your Ollama key where the CLI can load it as a secret (the file is gitignored):

   ```bash
   cd agent
   cp livekit.toml.example livekit.toml # then set your project subdomain
   cp .env.example .env.local   # then set OLLAMA_API_KEY=...
   ```

4. For a new LiveKit project, create the agent. When the CLI offers to load secrets from `.env.local`, say yes:

   ```bash
   lk agent create
   ```

   The command writes your agent ID to the ignored `livekit.toml`. For later code changes, run
   `lk agent deploy`. Logs: `lk agent logs`. Status: `lk agent status`.

5. In the LiveKit Cloud project's **Settings**, switch on the **Token server** and copy its **sandbox ID**.
   Put it in the Flutter app's `lib/secrets.dart` (`livekitSandboxId`) or paste it into the app's
   settings sheet. The sandbox token server is for development only; production needs your own token
   endpoint.

The agent name (`cryonis-agent`) must match `voiceAgentName` in the Flutter app's `lib/app_config.dart`.

## Develop and test

```bash
uv sync
uv run pytest                      # unit tests, no network needed
uv run src/agent.py download-files # fetch the VAD model once
uv run src/agent.py console        # talk to it from the terminal (needs LiveKit + Ollama keys in .env.local)
```

The production-style scripted call tool is also retained here. On macOS it joins by the same agent name as
the app, speaks the short question list, and prints what the agent heard and answered:

```bash
uv run --with numpy python tools/call_agent.py <token-server-id> tools/questions.json
```

Free plan limits to know: LiveKit Cloud's free tier has a monthly agent-session minutes allowance and a
small number of concurrent sessions; Ollama's free usage allows one request at a time.
