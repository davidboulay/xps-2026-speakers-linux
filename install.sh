#!/bin/bash
# xps-2026-speakers-linux installer -- per-user, no root needed.
#
#   ./install.sh                      install or update
#   ./install.sh --force              install on a model other than XPS 14/16 (2026)
#   ./install.sh --replace-omarchy    switch off Omarchy's own speaker tuning first
#   ./install.sh --neutral            start with no balance correction (default on the
#                                     XPS 14: right side down 6.6 dB)
#
# Installs into ~/.config/pipewire, ~/.config/systemd/user and ~/.local/bin only.
# A reinstall keeps your speaker-balance setting.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

force=0; replace_omarchy=0; neutral=0
for a in "$@"; do
  case $a in
    --force) force=1;;
    --replace-omarchy) replace_omarchy=1;;
    --neutral) neutral=1;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown option: $a" >&2; exit 2;;
  esac
done

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
bin="$HOME/.local/bin"
host="$cfg/pipewire/xps-speaker-tuning.conf"
frag="$cfg/pipewire/xps-speaker-tuning.conf.d/90-tuning.conf"
unit="$cfg/systemd/user/xps-speaker-tuning.service"

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

# --- model ---------------------------------------------------------------
sku=$(tr 'a-z' 'A-Z' </sys/class/dmi/id/product_sku 2>/dev/null || true)
model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case $sku in
  0DB9) say "Dell $model (SKU 0DB9): measured model.";;
  0DBA) say "Dell $model (SKU 0DBA): same speakers and amps as the XPS 14; tuning reported to suit, not measured.";;
  *) ((force)) || die "This tuning is for the Dell XPS 14 DA14260 (0DB9) / XPS 16 DA16260 (0DBA). Found '${model:-?}' (SKU '${sku:-?}'). Use --force to install anyway."
     warn "Installing on an unsupported model (--force).";;
esac

# --- dependencies --------------------------------------------------------
missing=()
for c in pipewire wireplumber pactl pw-dump pw-cli pw-play pw-record python3 systemctl; do
  command -v "$c" >/dev/null || missing+=("$c")
done
lsp=""
IFS=: read -ra lv2dirs <<<"${LV2_PATH:-$HOME/.lv2:/usr/local/lib/lv2:/usr/lib/lv2:/usr/lib64/lv2:/usr/lib/x86_64-linux-gnu/lv2}"
for d in "${lv2dirs[@]}"; do [[ -d $d/lsp-plugins.lv2 ]] && { lsp=$d/lsp-plugins.lv2; break; }; done
[[ -n $lsp ]] || missing+=("LSP LV2 plugins")
if ((${#missing[@]})); then
  warn "Missing: ${missing[*]}"
  if   command -v pacman >/dev/null; then echo "    sudo pacman -S --needed pipewire wireplumber pipewire-pulse lsp-plugins-lv2"
  elif command -v dnf    >/dev/null; then echo "    sudo dnf install pipewire wireplumber pipewire-utils pulseaudio-utils lsp-plugins-lv2"
  elif command -v apt-get >/dev/null; then echo "    sudo apt install pipewire wireplumber pipewire-bin pulseaudio-utils lsp-plugins-lv2"
  elif command -v zypper >/dev/null; then echo "    sudo zypper install pipewire wireplumber pipewire-tools pulseaudio-utils lsp-plugins-lv2"
  else echo "    install PipeWire, WirePlumber, pactl and the LSP LV2 plugins with your package manager"; fi
  exit 1
fi
pwv=$(pipewire --version | grep -oE 'libpipewire [0-9.]+' | awk '{print $2}')
python3 -I -c 'import sys; v=tuple(map(int,sys.argv[1].split(".")[:2])); sys.exit(0 if v>=(1,0) else 1)' "$pwv" \
  || die "PipeWire $pwv is too old; 1.0 or newer is needed."
pactl info >/dev/null 2>&1 || die "pactl cannot reach the audio server (is pipewire-pulse running?)."

# --- Omarchy / earlier tunings -------------------------------------------
# Remember the volume of an existing tuned sink before it goes away: the raw
# speaker sink usually sits at 100% underneath one.
prev_tuned_vol=$( { pactl get-sink-volume xps_speaker_tuning 2>/dev/null || pactl get-sink-volume omarchy_speaker_tuning 2>/dev/null; } | grep -oE '[0-9]+%' | head -1 || true)
if systemctl --user is-active --quiet omarchy-speaker-tuning.service 2>/dev/null; then
  ((replace_omarchy)) || die "Omarchy's speaker tuning is active (same EQ, without the balance trim and loudness fix). Re-run with --replace-omarchy to switch it off and use this one."
  if command -v omarchy >/dev/null; then
    say "Switching off Omarchy's speaker tuning (omarchy audio tuning off)."
    omarchy audio tuning off || die "omarchy audio tuning off failed."
  else
    bk="$HOME/.local/state/xps-2026-speakers/omarchy-tuning-backup-$(date +%Y%m%d-%H%M%S)"
    say "Disabling a hand-installed omarchy-speaker-tuning service (backup in $bk)."
    systemctl --user disable --now omarchy-speaker-tuning.service || true
    mkdir -p "$bk"
    for f in "$cfg/systemd/user/omarchy-speaker-tuning.service" "$cfg/pipewire/omarchy-speaker-tuning.conf" "$cfg/pipewire/omarchy-speaker-tuning.conf.d"; do
      [[ -e $f ]] && mv "$f" "$bk/"
    done
    systemctl --user daemon-reload
  fi
fi

# --- speaker sink --------------------------------------------------------
read -r spk prio < <(pw-dump | python3 -I -c '
import json,re,sys
for o in json.load(sys.stdin):
  p=((o.get("info") or {}).get("props") or {})
  if p.get("media.class")=="Audio/Sink" and re.search(r"^alsa_output.*sof_sdw.*Speaker__sink$", p.get("node.name","")):
    print(p["node.name"], p.get("priority.session", 0)); break') || true
[[ -n ${spk:-} ]] || die "No internal speaker sink found (expected alsa_output…sof_sdw…Speaker__sink). Check 'aplay -l', and run 'sudo bin/xps-speaker-id' if the card is missing."
prio=$((prio + 1))
say "Speaker sink: $spk (tuned sink priority $prio)"

# --- balance trim: keep an existing one, else the model default -----------
# XPS 14: the right side measured ~6.6 dB louder by ear (one unit, 2026-11-02;
# another owner reports the same lean upstream). Start there; adjust with
# speaker-balance. XPS 16 / other: no data yet, start neutral.
# --neutral starts at 0 dB instead.
case $sku in
  0DB9) trim_l=1.0; trim_r=0.4677; default_note="XPS 14 default: right side down 6.6 dB";;
  *)    trim_l=1.0; trim_r=1.0;    default_note="neutral (no measured default for this model yet)";;
esac
((neutral)) && { trim_l=1.0; trim_r=1.0; default_note="neutral (--neutral)"; }
if [[ -f $frag ]]; then
  trim_l=$(grep -oP 'name = trim_l label = linear control = \{ "Mult" = \K[0-9.]+' "$frag" || echo 1.0)
  trim_r=$(grep -oP 'name = trim_r label = linear control = \{ "Mult" = \K[0-9.]+' "$frag" || echo 1.0)
  say "Keeping your balance trim (L x$trim_l, R x$trim_r)."
else
  say "Balance: $default_note. Fine-tune by ear with speaker-balance."
fi

# --- install -------------------------------------------------------------
# The default output the user has *chosen* (WirePlumber's configured default),
# not the one in effect. Normally priority decides and we leave it alone.
configured=$(pw-metadata -n default 0 default.configured.audio.sink 2>/dev/null | grep -oP "value:'\{ *\"name\": *\"\K[^\"]+" || true)
raw_vol=${prev_tuned_vol:-$(pactl get-sink-volume "$spk" | grep -oE '[0-9]+%' | head -1)}

install -Dm644 config/xps-speaker-tuning.conf "$host"
mkdir -p "$(dirname "$frag")"
sed -e "s|@SPEAKER_SINK@|$spk|" -e "s|@PRIORITY@|$prio|g" -e "s|@TRIM_L@|$trim_l|" -e "s|@TRIM_R@|$trim_r|" \
  config/90-tuning.conf.in >"$frag.new"
mv "$frag.new" "$frag"
install -Dm644 systemd/xps-speaker-tuning.service "$unit"
install -Dm755 bin/speaker-balance "$bin/speaker-balance"
install -Dm755 bin/speaker-ab "$bin/speaker-ab"
install -Dm755 bin/xps-speaker-id "$bin/xps-speaker-id"

systemctl --user daemon-reload
systemctl --user enable xps-speaker-tuning.service >/dev/null
systemctl --user restart xps-speaker-tuning.service

# --- verify --------------------------------------------------------------
for _ in $(seq 20); do pactl list short sinks | awk '{print $2}' | grep -qx xps_speaker_tuning && break; sleep 0.25; done
pactl list short sinks | awk '{print $2}' | grep -qx xps_speaker_tuning \
  || die "The tuned sink did not appear. See: journalctl --user -u xps-speaker-tuning -n 30"
linked=0
for _ in $(seq 20); do pw-link -l | grep -A1 '^xps_speaker_tuning_output:output_FL' | grep -q "$spk" && { linked=1; break; }; sleep 0.25; done
((linked)) || die "The tuned sink is up but not linked to $spk. See: journalctl --user -u xps-speaker-tuning -n 30"

# Hardware stays at full scale; the volume keys act on the tuned sink.
# Start the tuned sink at the old speaker volume: it plays a few dB quieter, never louder.
pactl set-sink-volume xps_speaker_tuning "$raw_vol"
pactl set-sink-volume "$spk" 100%
# Priority already makes the tuned sink win wherever the speakers would. Only
# when the speakers themselves were pinned as the default (or Omarchy's tuning,
# now gone) does the pin move to the tuned sink -- the user's own choice, kept.
if [[ $configured == "$spk" || $configured == omarchy_speaker_tuning ]]; then
  pactl set-default-sink xps_speaker_tuning
  say "Your default output was pinned to the speakers; it now points at the tuned sink."
fi

say "Installed. Default output: $(pactl get-default-sink)"
case ":$PATH:" in *":$bin:"*) ;; *) warn "$bin is not on your PATH; add it to run the commands below.";; esac
cat <<EOF

  Next:
    speaker-balance            show the balance; fine-tune by ear (see README: Balance)
    speaker-ab calibrate       measure raw vs tuned loudness on this laptop
    speaker-ab raw | tuned     compare by ear at matched volume
    sudo ~/.local/bin/xps-speaker-id   check the amps loaded the right Dell tuning

  Remove with ./uninstall.sh
EOF
