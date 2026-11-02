#!/bin/bash
# Remove xps-2026-speakers-linux (per-user). Leaves PipeWire as it was before:
# the raw speaker sink becomes the speaker output again.
#   ./uninstall.sh            remove everything this project installed
#   (a speaker-ID firmware override, if you applied one, is removed separately:
#    sudo ~/.local/bin/xps-speaker-id --remove  -- run that first)
set -euo pipefail
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
spk=$(pw-dump 2>/dev/null | python3 -I -c '
import json,sys
for o in json.load(sys.stdin):
  p=((o.get("info") or {}).get("props") or {})
  if p.get("node.name")=="xps_speaker_tuning_output": print(p.get("target.object","")); break' || true)
vol=$(pactl get-sink-volume xps_speaker_tuning 2>/dev/null | grep -oE '[0-9]+%' | head -1 || true)
configured=$(pw-metadata -n default 0 default.configured.audio.sink 2>/dev/null | grep -oP "value:'\{ *\"name\": *\"\K[^\"]+" || true)

systemctl --user disable --now xps-speaker-tuning.service 2>/dev/null || true
rm -f "$cfg/systemd/user/xps-speaker-tuning.service"
rm -f "$cfg/pipewire/xps-speaker-tuning.conf"
rm -rf "$cfg/pipewire/xps-speaker-tuning.conf.d"
rm -f "$HOME/.local/bin/speaker-balance" "$HOME/.local/bin/speaker-ab"
[[ -e /usr/lib/firmware/updates/cirrus ]] || rm -f "$HOME/.local/bin/xps-speaker-id"
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/xps-2026-speakers/ab-offset-db" "${XDG_STATE_HOME:-$HOME/.local/state}/xps-2026-speakers/ab-mode"
systemctl --user daemon-reload

# The raw sink sat at 100% under the tuning: hand it the volume you were using
# (it plays a few dB louder untuned), and move a pin on the tuned sink back.
if [[ -n $spk ]]; then
  [[ -n $vol ]] && pactl set-sink-volume "$spk" "$vol" || true
  [[ $configured == xps_speaker_tuning ]] && pactl set-default-sink "$spk" || true
fi
echo "Removed. Speakers are on the stock path again."
[[ -e /usr/lib/firmware/updates/cirrus ]] && echo "Note: /usr/lib/firmware/updates/cirrus still exists; remove with: sudo ~/.local/bin/xps-speaker-id --remove (then re-run this)."
exit 0
