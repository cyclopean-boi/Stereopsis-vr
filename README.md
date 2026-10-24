# Stereopsis VR

A stereoacuity test and a small depth-vision training game for PC VR headsets.

I built this for myself. I had a lazy eye as a kid (treated with patching), and I wanted to know how
good my stereopsis really is and whether it can be trained. It started as a test, and turned into
a game with two worlds. This is an English, simplified version of my personal build, shared so that
people with **normal** depth perception can try it too: I don't know yet what "normal" looks like
on this test, and your data would tell me.

> **This is not a medical test.** It has not been validated, and VR headsets have their own limits
> (pixels, lenses, streaming). It can't diagnose anything. If you're worried about your eyes,
> see an orthoptist or an optometrist who does binocular vision.

## What's inside

**The stereopsis test** (about 20 minutes). Two tasks, with an adaptive staircase (Psi) that looks
for the smallest depth difference you can see:
- **Rings** (local stereopsis): two rings, above and below a cross. One is in front, one behind.
  Which one is in front?
- **Random dots** (global stereopsis): four discs hidden in a field of random dots, visible *only*
  through depth. One is in front of the others. Each eye on its own sees just noise, so there are no
  monocular cues by construction.
- A quick **eye check** at the start (two little lines, one per eye) and some control trials.

**The Firefly Forest** (training, local stereopsis). Two fireflies appear within arm's reach: touch
the nearer one with the tip of your wand. Difficulty adapts so you catch about 4 out of 5. Early on
there are "training wheels" (the near one is brighter, bigger, moves more with your head) that fade
away. A session is made of 12-minute "nights", alternating instinct nights (touch as soon as you
know) and reflective nights (take your time). There's also a one-minute contrast match between the
two eyes at the start.

**The Ruins** (training, global stereopsis). The random-dot task of the test, turned into a game:
creatures hidden in the stone, one in front. A "mosaic" path starts with big, coarse random-dot
shapes and steps down towards the test's format and beyond.

**The Keeper's Hut** is the menu that connects everything: a journal with charts of your
progress, a bestiary, achievements, settings, and the button for the test.

## What you need

- A Windows PC that runs PC VR, and a headset with two controllers that works through
  **SteamVR** (Index, Vive, Quest via Link/Air Link/Steam Link/Virtual Desktop, Pico via
  PICO Connect, and so on). Other OpenXR runtimes may work but are untested.
- About 1 GB of disk space.
- It has only been tested on a **Pico 4** so far. If something looks wrong on your headset, tell me.

## Quick start

1. Download `StereopsisVR-windows.zip` from the [Releases](../../releases) page and unzip it
   anywhere (not inside a cloud-synced folder, if you can avoid it).
2. In your headset, **set the lens distance (IPD) correctly**: the depth shown depends on it.
   Leave SteamVR's render resolution at 100% (or higher) and don't change it between sessions.
3. Double-click **`Start Stereopsis VR.cmd`** (not `StereopsisVR.exe`: started directly, the app may
   open on the desktop only), type a short nickname, press Enter. It starts SteamVR if needed, then the
   app opens in the headset, in the Keeper's Hut. If Windows says "Windows protected your PC", click
   *More info → Run anyway*: the app isn't code-signed.
4. Point with the controller ray and pull the trigger to choose.

**Controls.** Trigger (or A/X): select, start, continue. Thumbstick: answer (test and ruins: up,
right, down, left) and scroll lists. Grip: bring the menu panel back in front of you.
**Hold B or Y for two seconds** to stop a session and go back to the hut.

## If you're trying it as a comparison (thank you!)

The most useful order:
1. **Stereopsis test → Standard** (~20 min). Do this first, before any training.
2. **Firefly Forest**, one session: two nights (about 25 minutes, with a short rest in between).
3. **The Ruins**, one session of 10–15 minutes.

Breaks are fine at any point; take the headset off whenever you like (the game pauses).
If you get a headache or eye strain, stop.

Then send me your results: zip the folder `results\<your nickname>` (it's next to the app) and send
it to me, e.g. via Reddit DM or a GitHub issue. The files contain your nickname, dates and times,
the headset's eye separation, head orientation during trials, and your answers. Nothing is sent
anywhere by the app itself. Please also tell me which headset you used.

## Stop and see an eye doctor if…

- you see double outside the headset, in everyday life;
- headaches or eye strain don't go away after a session;
- anything about your vision changes.

Inside the headset, two objects very far apart in depth can look double: that's normal. Double vision
that is new, persistent or annoying is a reason to stop.

## Results files

Everything stays in `results/<nickname>/`:
- `sessione_*.csv` (one row per test trial), `sessione_*_riepilogo.json` (the test summary), and
  `postura/` (head roll and pitch per trial);
- `training/bosco_*.csv` (forest, one row per trial), `training/contrasto_*.csv` (contrast match),
  `training/rovine_*.csv` (ruins), `training/profilo.json` (progress, settings, achievements).

File names and column names are in Italian on purpose: they match my own data, so the analyses run
on both. The disparity unit everywhere is arcseconds (″).

**Reading the numbers.** Clinical stereo tests (TNO, Randot) usually give adults with normal binocular
vision a few tens of arcseconds. Headsets tend to give higher thresholds than printed tests, so the
numbers here are best compared with other people on the same app, not with clinical norms.
For the rings, the target and distractor sit at +d and −d around the background, and d is the
reported value.

## Running from source

The project is a Godot 4.7.2 project (Mobile renderer, OpenXR).
```
godot --path . --xr-mode on -- --vr --partecipante=yourname      # VR, starts in the hut
godot --path . --xr-mode off -- --partecipante=yourname          # desktop preview (not a measurement)
GODOT=/path/to/godot tools/verify.sh                             # headless test suite (~10 min)
```
Results go to `results/` inside the project folder. Code comments are in Italian (sorry); everything
the player sees is in English. `export_presets.cfg` has the Windows export used for the release; in an
exported build `assets/` and `musica/` must sit next to the executable (see `scripts/paths.gd`).

## Credits and license

Made by cyclopean-boi. The code was written with Claude (Anthropic) and reviewed with Codex (OpenAI).
The 2D art was generated with an AI image model; the music was made with Suno.

© 2026 cyclopean-boi. Licensed under **Creative Commons Attribution-NonCommercial-ShareAlike 4.0**
(CC BY-NC-SA 4.0, full text in `LICENSE`). In short: you're welcome to share it and to modify it, as long
as you credit this project, **don't sell it or use it commercially**, and release your changes under the
same license. Because of the non-commercial clause this is "source-available", not open source in the
OSI sense. The music was made with Suno and is included for non-commercial use only.

Key references behind the design: Chopin et al. (2019) on stereo tests that can't be passed with
monocular cues; Ding & Levi (2011) and Levi (2022) on perceptual learning of stereopsis in adults;
Vedamurthy et al. (2016) on fading monocular cues; Levitt (1971) on adaptive staircases.
