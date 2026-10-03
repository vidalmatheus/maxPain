#!/usr/bin/env bash
# Converts the music (see assets/music/README.md) to Ogg Vorbis:
# - assets/music/*.ogg: the whole tracks in stereo, streamed on desktop;
# - assets/music/web/*.ogg: a ~100 s mono 22 kHz loop of each, which the
#   browser plays as a Web Audio sample (glitch-free, about 9 MB decoded).
#
# Usage: tools/prepare_music.sh <dir with sad_trio.mp3 and hitman.mp3>
set -euo pipefail

src="${1:?usage: $0 <source dir>}"
out="$(cd "$(dirname "$0")/.." && pwd)/assets/music"
mkdir -p "$out/web"

# convert <source> <name> <loudness LUFS>
convert() {
	ffmpeg -hide_banner -loglevel error -y -i "$src/$1" -af "loudnorm=I=$3:TP=-1.5" -ar 44100 \
		-c:a libvorbis -q:a 2 "$out/$2.ogg"
	# The loop is 2 s .. 102 s; its last 2 s crossfade into the first 2 s, so
	# it wraps around without a click.
	ffmpeg -hide_banner -loglevel error -y -ss 2 -t 100 -i "$src/$1" -t 2 -i "$src/$1" \
		-filter_complex "[0][1]acrossfade=d=2:c1=qsin:c2=qsin,loudnorm=I=$3:TP=-1.5" \
		-ac 1 -ar 22050 -c:a libvorbis -q:a 2 "$out/web/$2.ogg"
	echo "$2"
}

convert sad_trio.mp3 title_sad_trio -18
convert hitman.mp3 gameplay_hitman -20
