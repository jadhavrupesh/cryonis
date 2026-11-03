# Cryonis UI spec — Lumix layout with a habit-tracker monochrome palette

Layout reference: https://dribbble.com/shots/26513278-Lumix-AI-Platform-Mobile-App (by Barly Design for Uxerflow).
Palette reference: the grayscale habit-tracker screenshot supplied on 3 November 2026. We take the Lumix **layout,
type scale and motion**, then apply the habit tracker's black, graphite, silver and off-white colour hierarchy. Not
copied: either product's name, logo, content or data.

How it was analysed: the Lumix shot's 14 s, 60 fps, 2880×2160 video was sampled every 0.5 s (28 frames) and the three
screens were read at full resolution. Sizes are px ÷ 1.88 (the phones are drawn at ~1.88 px per dp, i.e. a 390 dp-wide
phone). The replacement palette follows the tonal steps visible in the supplied JPEG and is tuned for readable contrast.

## 1. Look in one line
Pure black canvas, layered warm-charcoal surfaces, soft silver actions, off-white/grey type (Inter), and a graphite→silver
glow that rises from the bottom edge in voice mode. No coloured decorative accents, no blur, and only subtle separators.

## 2. Tokens
| Token | Value | Used for |
|---|---|---|
| canvas | `#000000` | every screen |
| surface | `#1D1D1C` | header pill, chips, input card, user bubble |
| surface-2 | `#30302F` | tool chips, attachment button, fields |
| text | `#F2F2EF` | titles, user text |
| text-ai | `#DEDEDA` | assistant answer |
| text-2 | `#B8B8B4` | list rows and chip labels |
| text-3 | `#8A8A86` | placeholders and secondary labels |
| text-4 | `#767673` | timestamps and tertiary details |
| accent | `#EEEEEA` → `#9C9C98` (top-left → bottom-right) | mic, send and primary buttons |
| accent content | `#101010` | icons and labels on silver actions |
| glow idle | `#20201F` at the bottom edge | voice listening |
| glow active | `#5B5B58` at the bottom-left, fading right | user speaking / generating |
| control fill | white @ ~15 % | keyboard / close circles in voice mode |
| halo | silver @ ~42 % ring + @ ~18 % fill | pulsing ring round the voice mic |

Type (Inter): header pill 15 / 500; section chip 14 / 500; list rows 14 / 400; time 12; chips 14; input 14;
chat text 13.5–14 / 400, line-height 1.45; user bubble 13.5 / 500; voice caption "I'm Listening…" 20 / 600 at
~70 % white; live transcript 18 / 400, line-height 1.7; small "Listening" label 12 / 500.

Shapes: pill/chip radius 8–12; input card radius 18; user bubble radius 8; avatar circle 41; mic button on Home is a
32 dp rounded square (radius 6), in voice mode a 53 dp circle with a 77 dp halo; keyboard/close circles 40 dp.

## 3. Screens
**Home** — header (menu icon · `Name ⌄` pill · avatar) → "Previous conversations" chip + rows (title left, relative
time right) → big empty space → horizontally scrolling quick-action chips (icon + label) → input card
("Ask anything", then `+`, tool chips, silver mic square).

**Voice** — same header → dotted ring (see §5) centred at ~43 % of the height → ear icon + "I'm Listening…" →
bottom controls: keyboard (left), mic with halo (centre), close (right) → glow rising from the bottom.
Once speech arrives the ring shrinks and moves up, the caption becomes a small "Listening", and the live transcript
appears left-aligned: recognised words white, words still arriving grey.

**Chat / generating** — same header → user message as a right-aligned dark bubble (max ~80 % wide) → the answer as plain
text with no bubble → "Generate Loading ✳" (grey text + 8-ray spinner) under the last line while streaming →
voice bar pinned at the bottom: "Voice mode paused while generating", dimmed controls (mic `#7A2A00`).

## 4. Motion timeline (the 14 s loop, frames every 0.5 s)
| t | What happens |
|---|---|
| 0.0–0.5 | Overview: Home, Voice and Chat phones side by side, still. |
| 1.0–1.5 | Home phone centred; the other two leave. |
| 2.0 | Home → voice: rows and chips fade out, the input card collapses into a small pill, mic detaches to the right. |
| 2.5 | Camera pushes in; voice screen fades in; dotted ring grows in from ~80 %; controls appear. |
| 3.0–3.5 | Caption cycles "I'm Listening." → ".." → "…" (dots animate); ring shimmers. |
| 4.0 | First word "Create" appears, caption shrinks to "Listening", ring contracts and moves up, header returns. |
| 4.5–7.0 | Words arrive one by one (grey → white); mic halo pulses; glow brightens from graphite to silver. |
| 7.0–7.5 | Sentence done: ring dims and disappears, transcript fades, small "Voice" label. |
| 8.0–8.5 | The transcript lands as the user bubble (top right); "Generate Loading ✳" appears; voice bar dims. |
| 9.0–11.0 | Camera pushes in; the answer streams line by line; the loading line is pushed down as text grows. |
| 11.5 | Camera pulls back; answer complete ("…"), voice bar still dimmed. |
| 12.0–13.5 | Loop: chat slides out, Home returns, the three-phone overview re-forms. |

Easing is smooth ease-in-out; fades 250–400 ms; the ring grows over ~500 ms; word reveal ~350 ms per word.

## 5. The dotted ring
A grid of square dots (pitch ≈ 7 dp, size 1.5–3.7 dp) lit in a ring: outer radius ≈ 144 dp, hole ≈ 59 dp, densest at
~100 dp. Each dot's brightness = ring profile × patchy noise that drifts over time, so the ring "boils"; white on black, the outer
edge dissolving into scattered single dots.

The shot only shows the listening state, so the other phases are our own, following the agent's loop (observe → orient → decide → act):

| Phase | App state | Motion on top of the boiling ring |
|---|---|---|
| Observe | listening | slow breathing (±2.5 dp); soft ripples travel outward as the caller's voice rises |
| Orient | listening, words arriving | the ring contracts to ~62 % and moves up; ripples travel **inward**, drawing the dots towards the centre |
| Decide | thinking | a bright comet arc orbits (one turn ≈ 1.7 s) with a long tail; the rest of the ring dims to a 40 % ghost |
| Act | speaking | outward ripples driven by the agent's level; the ring swells (+10 dp) and brightens |
| — | connecting | faint, with a slow dim arc going round |
| — | muted / failed | nearly dark and still |

Every parameter is eased towards the new phase (no jumps), the level has a fast attack and a slow release like an audio meter, and
"reduce motion" freezes the animation. Implemented in `widgets/dot_ring.dart`.

## 6. How it maps onto Cryonis (decisions)
* Name in the header pill is the **selected Ollama model** (tap → model picker). Menu icon → server settings.
  Avatar → connection status (green/amber/red dot, tap re-checks), because we have no user profile.
* "Previous conversations" shows our one saved conversation (title = its first message, time = last activity).
* Quick-action chips prefill the input (Analyse, Summaries, Draft, Debug) rather than sending.
* Input card: `+` = attach image, model chip, silver mic (→ voice) that turns into send once there is text.
  The shot's "Deep Search" and "Think" chips are **not** included: nothing behind them in our backend.
* Voice: ring + glow reflect the call's phase and loudness; keyboard = end call and continue in chat; mic = mute;
  close = finish voice and carry completed turns into text chat. Both voice screens (live call and on-device dictation) get the new look.
* Chat: user bubble flat `#1A1A1A`; answers stay Markdown (code blocks, copy, regenerate), recoloured to the new palette.
