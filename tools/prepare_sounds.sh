#!/usr/bin/env bash
# Cuts the game's sound effects out of the CC0 source packs listed in
# assets/sounds/README.md and converts them to small Ogg Vorbis files.
#
# Usage: tools/prepare_sounds.sh <source dir>
# The source dir must contain the downloads, unpacked:
#   kenney_impact-sounds/, kenney_rpg-audio/   (kenney.nl)
#   Prepared SFX Library/                        (The Free Firearm Sound Library)
#   gunreload1.wav, time_stop.mp3                (opengameart.org)
# Requires ffmpeg with libvorbis.
set -euo pipefail

src="${1:?usage: $0 <source dir>}"
out="$(cd "$(dirname "$0")/.." && pwd)/assets/sounds"
mkdir -p "$out"

# encode <output name> <channels> <ffmpeg input/filter args...>
# Converts to 44.1 kHz Vorbis and normalizes the peak to -1 dBFS.
encode() {
	local name="$1" channels="$2"
	shift 2
	local tmp
	tmp="$(mktemp --suffix=.wav)"
	ffmpeg -hide_banner -loglevel error -y "$@" -ac "$channels" -ar 44100 "$tmp"
	local peak
	peak="$(ffmpeg -hide_banner -i "$tmp" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB/\1/p')"
	local gain
	gain="$(awk -v p="$peak" 'BEGIN { printf "%.2f", -1.0 - p }')"
	ffmpeg -hide_banner -loglevel error -y -i "$tmp" -af "volume=${gain}dB" -c:a libvorbis -q:a 4 "$out/$name.ogg"
	rm -f "$tmp"
	echo "$name.ogg (gain ${gain} dB)"
}

kenney_impact="$src/kenney_impact-sounds/Audio"
kenney_rpg="$src/kenney_rpg-audio/Audio"
firearms="$src/Prepared SFX Library"

# Walther PPQ 9 mm, close distance: the first of the three shots.
encode pistol_shot 1 -i "$firearms/Walther PPQ/X_39P.wav" \
	-af "atrim=1.385:2.5,asetpts=N/SR/TB,afade=t=out:st=0.55:d=0.56"

# Brass casings bouncing on the floor (pitched up in game).
encode casing_1 1 -i "$kenney_impact/impactMetal_light_000.ogg"
encode casing_2 1 -i "$kenney_impact/impactMetal_light_002.ogg"
encode casing_3 1 -i "$kenney_impact/impactMetal_light_004.ogg"
encode magazine_drop 1 -i "$kenney_impact/impactMetal_medium_001.ogg"

# Reload, split in three so each part plays when the animation reaches it.
encode reload_magazine_out 1 -i "$src/gunreload1.wav" \
	-af "atrim=0.04:0.34,asetpts=N/SR/TB,afade=t=out:st=0.25:d=0.05"
encode reload_magazine_in 1 -i "$src/gunreload1.wav" \
	-af "atrim=0.66:1.1,asetpts=N/SR/TB,afade=t=out:st=0.39:d=0.05"
encode reload_slide 1 -i "$src/gunreload1.wav" \
	-af "atrim=1.22,asetpts=N/SR/TB,afade=t=out:st=0.28:d=0.08"

encode dry_fire 1 -i "$kenney_rpg/metalClick.ogg"
encode weapon_switch 1 -i "$kenney_rpg/metalLatch.ogg"

# Bullet time: the "time freeze" hit for entering, the same hit sped up for
# leaving, and the droning clock ticks after it as a seamless loop.
encode bullet_time_enter 2 -i "$src/time_stop.mp3" \
	-af "atrim=0:2.6,asetpts=N/SR/TB,afade=t=out:st=1.4:d=1.2:curve=qsin"
encode bullet_time_exit 2 -i "$src/time_stop.mp3" \
	-af "atrim=0:1.3,asetpts=N/SR/TB,asetrate=44100*1.6,aresample=44100,afade=t=out:st=0.3:d=0.5:curve=qsin"
# The loop is 4 s .. 21 s of the drone; its last second crossfades into the
# second right before its start, so the wrap-around is seamless.
encode bullet_time_loop 2 -ss 4 -t 17 -i "$src/time_stop.mp3" -ss 3 -t 1 -i "$src/time_stop.mp3" \
	-filter_complex "[0][1]acrossfade=d=1:c1=qsin:c2=qsin"
