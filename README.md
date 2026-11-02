<div align="center">

<img src="docs/icon.svg" alt="" width="104" height="104">

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/xps-logo-light.svg">
  <img src="docs/xps-logo-dark.svg" alt="Dell XPS" width="120">
</picture>

<h1>XPS 2026 Speakers for Linux</h1>

**Better sound from the Dell XPS 14 and XPS 16 (2026) speakers on Linux.** A measured EQ,<br>
a left/right balance fix, and a check for the wrong-tuning firmware bug.

[![CI](https://img.shields.io/github/actions/workflow/status/davidboulay/xps-2026-speakers-linux/ci.yml?branch=main&style=flat-square&label=checks&labelColor=1c1c1e)](https://github.com/davidboulay/xps-2026-speakers-linux/actions/workflows/ci.yml)
[![Models](https://img.shields.io/badge/XPS%2014%20%C2%B7%20XPS%2016%20(2026)-38BDF8?style=flat-square&labelColor=1c1c1e&label=for)](#supported-hardware)
[![Distros](https://img.shields.io/badge/any%20PipeWire%20distro-818CF8?style=flat-square&labelColor=1c1c1e&label=runs%20on)](#install)
[![License](https://img.shields.io/github/license/davidboulay/xps-2026-speakers-linux?style=flat-square&color=6b7280&labelColor=1c1c1e)](LICENSE)

<sub>An independent community project, not affiliated with or endorsed by Dell. XPS and the XPS logo are trademarks of Dell Inc.</sub>

[**Install**](#install) · [What it fixes](#what-it-fixes) · [Balance](#balance) · [A/B test](#compare-by-ear) · [Speaker-ID bug](#the-speaker-id-firmware-bug) · [Troubleshooting](#troubleshooting) · [Project page](https://davidboulay.com/apps/xps-2026-speakers/)

</div>

<br>

The 2026 XPS 14 and XPS 16 have good speakers: four Cirrus CS35L57 smart amps
driving two woofers and two tweeters. On Windows, Dell's Waves layer shapes
them. On Linux that layer doesn't exist, so out of the box they sound **thin,
quiet and boxy**, and on some units **lopsided**.

This project installs a measured speaker tuning as a PipeWire filter, makes
sure it is actually used, adds a **per-unit left/right balance** you set by ear,
and checks whether your amplifiers loaded the **right Dell tuning firmware**,
which a BIOS bug can get wrong.

It is a per-user install: no root, no packages replaced, nothing a system update
can overwrite. Remove it and you're back on the stock sound.

## What it fixes

| Symptom | Cause | What this does |
|---|---|---|
| **Thin, boxy, no body** | Linux has no equivalent of the Windows Waves processing | 13-band EQ + lookahead limiter, fitted to a measured profile of these speakers |
| **Quiet once tuned** | Earlier tunings cut the input to keep bass peaks safe, playing ~11 dB below the raw speakers | +9 dB into the limiter; the peak ceiling is unchanged, so the drivers aren't pushed harder |
| **Tuning installed but no difference** | A filter sink that isn't the default output is silently bypassed | The tuned sink gets a priority one above the speakers: it's used whenever the speakers would be, and docks and headphones keep their place |
| **Sound leans right** | Not fully understood yet. The gap (~6.6 dB on the measured XPS 14) is far beyond normal speaker tolerance, so it looks like a property of the model (speaker layout or Dell's per-amp tuning, which Windows corrects and Linux doesn't), not of one unit. Another owner reports the same lean upstream | The XPS 14 starts with the right side down **6.6 dB**; `speaker-balance` fine-tunes it by ear |
| **Wrong Dell tuning loaded** | The BIOS points the amps at the wrong speaker-ID pin ([sof#5725](https://github.com/thesofproject/linux/issues/5725)) | `xps-speaker-id` checks it, and installs an update-proof override only if your unit needs one |

> **Not fixed here:** no sound at all, or no sound after suspend. Those are
> kernel/driver problems (SDCA class driver, amp resume). See
> [Troubleshooting](#troubleshooting).

## Supported hardware

| Model | SKU (`/sys/class/dmi/id/product_sku`) | Status |
|---|---|---|
| **XPS 14 DA14260** | `0DB9` | ✅ Measured and tested |
| **XPS 16 DA16260** | `0DBA` | ☑️ Same amps and speaker family; the tuning is reported to suit it, not measured |
| XPS 13 DX13260 | other | ❌ Different amps and speakers: this tuning would be wrong. The installer refuses it |

Anything else is refused unless you pass `--force`.

## Install

**Needs:** PipeWire 1.0+ with WirePlumber and `pipewire-pulse`, and the **LSP
LV2 plugins** (for the limiter). Any distro and any desktop: Plasma, GNOME,
Hyprland, COSMIC all work, because it's just a PipeWire sink.

```bash
git clone https://github.com/davidboulay/xps-2026-speakers-linux.git
cd xps-2026-speakers-linux
./install.sh
```

The installer checks the model and the dependencies, prints the right install
command for your distro if something's missing, starts the tuning, and verifies
it's linked to the speakers before reporting success.

| Distro | Dependencies |
|---|---|
| **Arch**, CachyOS, EndeavourOS, Manjaro | `sudo pacman -S --needed pipewire wireplumber pipewire-pulse lsp-plugins-lv2` |
| **Fedora** | `sudo dnf install pipewire wireplumber pipewire-utils pulseaudio-utils lsp-plugins-lv2` |
| **Ubuntu 26.04** / Debian | `sudo apt install pipewire wireplumber pipewire-bin pulseaudio-utils lsp-plugins-lv2` |
| **openSUSE** | `sudo zypper install pipewire wireplumber pipewire-tools pulseaudio-utils lsp-plugins-lv2` |

Tested on **CachyOS (KDE Plasma 6.8, kernel 7.3, PipeWire 1.6.10)**. The other
lines are expected to work and reports are welcome.

**Omarchy** already ships the same EQ (this project's tuning comes from it), so
the installer stops and tells you so. `./install.sh --replace-omarchy` turns
Omarchy's tuning off and installs this one, which adds the loudness fix, the
balance trim and the speaker-ID check. **NixOS:** see
[Jitsusama/core.nix](https://github.com/Jitsusama/core.nix), which carries the
same tuning as a module.

**Updating:** `git pull && ./install.sh`. Your balance setting is kept.
**Removing:** `./uninstall.sh`.

## Balance

**On the XPS 14 the right side starts 6.6 dB down.** That value was set by ear
on one unit (BIOS 1.10.1, `spkid0` speakers, 2026-11-02). The gap is too large
to be ordinary speaker variation, so we expect most XPS 14s to need about the
same, but it rests on one unit so far. The XPS 16 starts neutral until someone
reports a value. Prefer to start from zero? `./install.sh --neutral`.

### Check yours

Play something with **one voice in the middle**: a podcast, a news clip, a mono
recording. Sit centred in front of the laptop. Then:

```bash
speaker-balance          # shows the current setting: "right side down 6.6 dB"
```

The number is **how much the right side is turned down**. Negative numbers turn
the left side down instead.

#### If the voice sits in the middle

Done. Nothing to change.

#### If the voice sits to the LEFT

The right side is now too quiet: **lower the number**, 1 dB at a time.

```bash
speaker-balance 5.5
speaker-balance 4.5      # still left? keep going down
speaker-balance 0        # neutral
speaker-balance -1.5     # past zero, the left side goes down instead
```

#### If the voice still sits to the RIGHT

The right side is still too loud: **raise the number**.

```bash
speaker-balance 7.5
speaker-balance 8.5      # still right? keep going up
```

Once you're close, finish in half steps (`6`, `7`). Each change is live and
saved; reinstalls and updates keep it. `speaker-balance default` goes back to
the model's starting point, and `speaker-balance help` prints this guide.

> **Make sure something is playing.** It's easy to spend five minutes tuning
> silence.

**Please report your value.** One unit is a thin basis for a default. If yours
centres at something else (or at 6.6 too), open a
[balance report](https://github.com/davidboulay/xps-2026-speakers-linux/issues/new?template=balance-report.yml):
it asks for your setting and the output of `xps-speaker-id`, which shows your
speaker build.

## Compare by ear

Louder almost always sounds better, so a fair comparison has to match levels.
`speaker-ab` moves whatever is playing between the raw speakers and the tuning,
turning the raw path down by the measured gap:

```bash
speaker-ab calibrate     # once: measure the gap on your laptop (2 s of quiet noise per path)
speaker-ab raw           # A: stock sound, level-matched
speaker-ab tuned         # B: the tuning
speaker-ab               # toggle
```

Leave the volume keys alone while comparing, and finish on `speaker-ab tuned`.
It never changes your default output, so a dock or headphones still take over
as usual afterwards.

## The speaker-ID firmware bug

Each CS35L57 amp loads a Dell tuning file chosen by a **speaker-ID pin**:
`spkid0` or `spkid1`, matching which speaker build is in your unit. On these
models the BIOS (seen on 1.10.1 and 1.11.0) points the driver at the wrong pin,
`GPP_F_20`, which another driver already owns as *wake*. Cirrus identified the
real line as `GPP_E_20`, pin 46, in
[thesofproject/linux#5725](https://github.com/thesofproject/linux/issues/5725).
Depending on the unit, that means:

- **the amps fail to probe** and there is no sound card at all (`-EBUSY` on
  `spk-id-gpios`), or
- **they load `spkid0` while the speakers are `spkid1`**: the wrong tuning, or
- **nothing visible**, when pin 46 happens to read 0 too: the right tuning by luck.

Check yours (read-only):

```bash
sudo ~/.local/bin/xps-speaker-id
```

```
Model:            Dell XPS SKU 0DB9 (firmware tag 10280db9)
Speaker-ID pin:   GPP_E_20 reads 0  (pin 46 (GPP_E_20) 46:INTC10BC:01 GPIO 0x84000100 …)
Correct tuning:   spkid0
Balance default:  measured on a spkid0 unit like yours (right side down 6.6 dB)

  sdw:0:2:01fa:3557:01:2     cs35l57-b2-dsp1-misc-10280db9-spkid0-l2u2.bin   ok
  …
All amps loaded the tuning that matches the pin. Nothing to fix here.
```

If it reports **WRONG**, `sudo ~/.local/bin/xps-speaker-id --apply` installs
the fix Cirrus suggested: the `spkid0` names point at the `spkid1` files. It
goes in `/usr/lib/firmware/updates/cirrus`, which the kernel searches first and
no package owns, as symlinks, so firmware updates flow through and nothing
in `linux-firmware` is modified. Reboot, run the check again, and every amp
should say `ok`. Undo with `--remove`.

It never reloads drivers on a running system: unbinding audio on these
machines can hang them, so a reboot is the only way the new files load.

> One tester whose unit needed `spkid1` reported the balance still leaning after
> the override. Correct firmware and balance are separate fixes; you may want both.
> On an XPS 14 the check also tells you whether you have the same speaker build
> as the unit the 6.6 dB default was measured on.

## How it works

```
apps ──▶ xps_speaker_tuning  (PipeWire filter-chain sink, priority = speakers + 1)
           │  2 × high-pass 60.9 Hz → 10 × peaking EQ → high-shelf 6 kHz   (per channel)
           │  trim_l / trim_r                                             (speaker-balance)
           │  LSP stereo limiter: input +9 dB vs Omarchy, ceiling 0.891, lookahead
           ▼
         alsa_output…sof_sdw…Speaker__sink  (held at 100%) ──▶ 4 × CS35L57 (Dell firmware)
```

- **Its own PipeWire client** (`xps-speaker-tuning.service`, a user unit), not a
  `pipewire.conf.d` drop-in: it starts and stops without restarting the audio
  daemon, and a broken config breaks only this service.
- **Bass Q is capped at 1.8**: a closer fit with high-Q sections smeared bass
  transients (31 ms group-delay swing at 63–80 Hz).
- **The limiter is one stereo instance**, so a bass hit on one side doesn't shift
  the stereo image.
- **Pinned output**: the filter's output never follows "move all streams", and it
  waits for the speaker sink instead of tuning whatever device exists at boot.

| File | Purpose |
|---|---|
| `~/.config/pipewire/xps-speaker-tuning.conf` | the client's host config |
| `~/.config/pipewire/xps-speaker-tuning.conf.d/90-tuning.conf` | the filter graph (your balance lives here) |
| `~/.config/systemd/user/xps-speaker-tuning.service` | runs it, wanted by `pipewire.service` |
| `~/.local/bin/speaker-balance`, `speaker-ab`, `xps-speaker-id` | the tools |

## Troubleshooting

| Symptom | Look at |
|---|---|
| No "Laptop Speakers (tuned)" output | `systemctl --user status xps-speaker-tuning` and `journalctl --user -u xps-speaker-tuning -n 30` |
| It exists but isn't used | `pactl get-default-sink`. If you pinned another output in your desktop's sound settings, pick *Laptop Speakers (tuned)* there |
| Limiter missing in the log | the LSP LV2 plugins aren't installed (`lsp-plugins-lv2`) |
| No sound card at all (`aplay -l` shows no speakers) | kernel side: run `sudo ~/.local/bin/xps-speaker-id`, check `CONFIG_SND_SOC_SDCA_CLASS`, see [sof#5725](https://github.com/thesofproject/linux/issues/5725) |
| Speakers die after suspend until reboot | kernel amp-resume issue (`cs35l56 … failed to resume`), not this project. Reboot |
| Too quiet / too loud at max | the limiter input is `"g_in"` in `90-tuning.conf`; each ×1.41 is +3 dB. The ceiling `th` protects the drivers, so leave it |

## Credits

- **The EQ** is Omarchy's [`dell-xps-2026`](https://github.com/omacom/omarchy)
  tuning (MIT, David Heinemeier Hansson), fitted to the measured response of the
  *xps-clone* EasyEffects profile from
  [spencerbull/xps-audio-linux](https://github.com/spencerbull/xps-audio-linux) (MIT).
- **The +9 dB limiter input** follows
  [Jitsusama/core.nix#621](https://github.com/Jitsusama/core.nix/pull/621).
- **The speaker-ID diagnosis** is Cirrus Logic's (Charles Keepax) and the testers'
  in [thesofproject/linux#5725](https://github.com/thesofproject/linux/issues/5725).

Want the fuller, Windows-like sound instead? xps-audio-linux runs the complete
profile in EasyEffects, adding a bass enhancer and a multiband compressor. It's
louder and more "produced"; in our level-matched listening this lighter
tuning sounded cleaner.

## License

MIT, see [LICENSE](LICENSE). Third-party notices in [NOTICE](NOTICE).
