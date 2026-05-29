<p align="center">
  <img src="Resources/AppIcon-Source.png" width="128" height="128" alt="Bolo icon">
</p>

<h1 align="center">Bolo</h1>

<p align="center">
  <b>A free, two-way voice app for macOS — talk and listen.</b><br>
  Dictate into any text field with your voice, or select any text and have it
  read aloud in a natural voice. No subscription. Open source. MIT.
</p>

<p align="center">
  <a href="#quick-start"><b>Quick Start</b></a> ·
  <a href="#features"><b>Features</b></a> ·
  <a href="#read-aloud-listen"><b>Read Aloud</b></a> ·
  <a href="#privacy"><b>Privacy</b></a> ·
  <a href="#credits--thanks"><b>Credits</b></a>
</p>

---

<p align="center">
  <img src="Resources/demo.gif" alt="Bolo demo" width="600">
</p>

## Download

**[⬇︎ Download Bolo.dmg](https://github.com/v-khanna/bolo/releases/latest/download/Bolo.dmg)** — Apple Silicon, macOS 13+.

Bolo isn't notarized by Apple yet, so macOS will warn you the first time. To open it:

1. Open the `.dmg` and drag **Bolo** into **Applications**.
2. **Right-click** Bolo in Applications → **Open** → **Open** (only needed once).

Then walk through the ~1-minute in-app setup (you'll paste a free Groq API key — there's a button that takes you straight to it).

## What is Bolo?

**Bolo** does two things, both from a global hotkey, anywhere on your Mac:

- **Talk** — hold (or tap) a shortcut, speak, and your words are transcribed,
  cleaned up, and typed into whatever app you're in. This is dictation.
- **Listen** — select any text, press a shortcut, and Bolo reads it back to you
  in a natural-sounding voice. This is read-aloud (text-to-speech).

Same app, same Groq API key, both directions — speech to text *and* text to
speech.

> **Why "Bolo"?** *Bolo* (बोलो) is Hindi for **"speak"** — the imperative form,
> like saying *"go on, say it."* It felt right for an app that's all about
> turning speech into text and text back into speech.

## Want it fully on-device?

Bolo's read-aloud uses cloud TTS (Groq) by default — fast (~1s) and nothing to
download. If you'd rather run **read-aloud entirely on your Mac**, there's a
companion build powered by a **from-scratch MLX-Swift port of Chatterbox-Turbo**
— the genuinely hard part of this project: a full on-device TTS pipeline (a
GPT-2-style T3 transformer → S3Gen token-to-mel decoder → HiFT vocoder),
validated against the reference with six numerical parity gates, running in 4-bit
with a KV cache.

→ **[Bolo Local](https://github.com/v-khanna/bololocal)** — on-device read-aloud
(~3 GB model download, more RAM, slower than cloud, but 100% offline).
The engine port and how it was built: **[writeup](https://github.com/v-khanna/bololocal/blob/main/docs/WRITEUP.md)**.

> **Planned (not yet built):** on-device *dictation* too — via WhisperKit + a
> local LLM. (Speech-to-text is a different model from the TTS engine above;
> none of the Chatterbox code transfers — it'd reuse the out-of-process engine
> pattern, not the model.)

## Quick Start

1. **Build or download** the app (see [Building](#building) below).
2. **Get a free Groq API key** from [groq.com](https://groq.com/) and paste it
   into Bolo's settings (Settings → Voice → API Key). The same key powers both
   dictation and read-aloud.
3. **Talk:** hold `Fn` to talk, or tap `Command-Fn` to start/stop dictation, and
   what you say gets typed into the current text field.
4. **Listen:** set a "Read Selection Aloud" shortcut (Settings → Voice → Read
   Aloud), then select text anywhere and press it to hear it read back.

## Features

- **Two-way voice:** dictation (talk) and read-aloud (listen) in one menu-bar app.
- **Custom shortcuts:** customize the hold-to-talk shortcut, the toggle-dictation
  shortcut, and the read-aloud shortcut. If your toggle shortcut extends your
  hold shortcut, you can start in hold mode and press the extra modifier keys to
  latch into tap mode without stopping the recording.
- **Context-aware cleanup:** Bolo can read nearby app context so names, terms,
  and phrases are spelled correctly when you dictate into email, terminals, docs,
  and other apps.
- **Custom vocabulary:** add names, jargon, and project-specific words that Bolo
  should preserve during cleanup.
- **Multiple voices:** pick from several read-aloud voices, audition them with a
  one-click **Test Voice** button, and adjust the speaking speed.
- **Live waveform overlay:** a tidy notch-aware overlay shows a waveform while
  recording and while reading, with a stop button to cancel mid-read.
- **OpenAI-compatible providers:** use Groq by default, or configure a custom
  model and API URL in settings.

## Read Aloud (Listen)

Bolo's read-aloud half is the mirror of dictation: instead of *speech → text*,
it does *text → speech*.

1. Select any text in any app.
2. Press your **Read Selection Aloud** shortcut.
3. The overlay appears with a moving waveform and Bolo reads the selection aloud.
4. Click the stop button (or press your shortcut again) to cancel.

Options in **Settings → Voice → Read Aloud**:

- **Voice** — choose among the available voices.
- **Test Voice** — hear a sample sentence in the selected voice (cached, so it's
  instant on repeat).
- **Speed** — slow down or speed up playback.
- **Clean up text for speech** *(optional)* — rewrites the selection so it reads
  naturally (expands abbreviations like "Dr." → "Doctor", strips page numbers and
  markdown junk, etc.) before speaking. Falls back to the original text if cleanup
  fails, so it never blocks reading.

Long selections are automatically split at sentence boundaries and played
back-to-back.

## Edit Mode

Edit Mode lets you highlight existing text and transform it with a spoken
instruction, like "make this shorter" or "turn this into bullets." Enable it in
settings, then use your normal dictation shortcut on selected text, or choose
Manual mode to require an extra modifier key.

## Privacy

There is no Bolo server, so Bolo does not store or retain your data. The only
information that leaves your computer are API calls to your configured
transcription, LLM, and text-to-speech provider (Groq by default). Run history
is stored locally on your machine.

## Building

Bolo builds with a plain `swiftc` Makefile — **no SwiftPM dependencies, no
Xcode project required.**

```sh
# Build the app bundle
make

# Build and launch
make run
```

For a stable, signed build (so macOS Accessibility/hotkey permissions survive
rebuilds), sign with a self-signed certificate:

```sh
make run APP_NAME=Bolo BUNDLE_ID=com.virkhanna.bolo CODESIGN_IDENTITY="Bolo Dev"
```

Other targets: `make dmg` (build a DMG), `make clean`.

## Custom Cleanup

If you'd rather keep dictation cleanup more literal and less context-aware, you
can paste this simpler prompt into the custom system prompt setting:

<details>
  <summary>Simple post-processing prompt</summary>

  <pre><code>You are a dictation post-processor. You receive raw speech-to-text output and return clean text ready to be typed into an application.

Your job:
- Remove filler words (um, uh, you know, like) unless they carry meaning.
- Fix spelling, grammar, and punctuation errors.
- When the transcript already contains a word that is a close misspelling of a name or term from the context or custom vocabulary, correct the spelling. Never insert names or terms from context that the speaker did not say.
- Preserve the speaker's intent, tone, and meaning exactly.

Output rules:
- Return ONLY the cleaned transcript text, nothing else. So NEVER output words like "Here is the cleaned transcript text:"
- If the transcription is empty, return exactly: EMPTY
- Do not add words, names, or content that are not in the transcription. The context is only for correcting spelling of words already spoken.
- Do not change the meaning of what was said.

Example:
RAW_TRANSCRIPTION: "hey um so i just wanted to like follow up on the meating from yesterday i think we should definately move the dedline to next friday becuz the desine team still needs more time to finish the mock ups and um yeah let me know if that works for you ok thanks"

Then your response would be ONLY the cleaned up text, so here your response is ONLY:
"Hey, I just wanted to follow up on the meeting from yesterday. I think we should definitely move the deadline to next Friday because the design team still needs more time to finish the mockups. Let me know if that works for you. Thanks."</code></pre>
</details>

## FAQ

**Why does this use Groq instead of local models?**

Cloud transcription and TTS keep the experience fast (≈1s) and keep your laptop
cool. The full pipeline — transcribe, clean up with an LLM, and speak — is hard
to do locally without long delays and battery drain. Because Bolo is
OpenAI-compatible, you can point it at a local model (e.g. Ollama) by configuring
the API URL in settings if you prefer.

## Credits & Thanks

Bolo's **talk** (dictation) half is [**FreeFlow**](https://github.com/zachlatta/freeflow)
by [Zach Latta](https://github.com/zachlatta) — a wonderful free, open-source Mac
dictation app (MIT). Bolo is a fork that adds the **listen** (read-aloud) half.
Huge thanks to the FreeFlow project and to
[@marcbodea](https://github.com/marcbodea) for maintaining it.

FreeFlow itself was inspired by [Wispr Flow](https://wisprflow.ai/),
[Superwhisper](https://superwhisper.com/), and
[Monologue](https://www.monologue.to/).

## License

Licensed under the MIT license. See [LICENSE](LICENSE) — copyright is retained by
Zach Latta (FreeFlow) and Vir Khanna (Bolo's read-aloud additions).
