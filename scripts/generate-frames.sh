#!/bin/bash
# Genera los frames PNG rotados para los cursores animados (wait, bg_progress),
# reproduciendo el spinner de arranque/login de BookOS: arco parcial rotando
# de forma lineal, 1100ms por vuelta.
#
# Uso: ./generate-frames.sh [VARIANT]   (VARIANT por defecto: Light)
set -euo pipefail

VARIANT="${1:-Light}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/$VARIANT"
OUT="$ROOT/build/frames/$VARIANT"

FRAMES=44
DELAY_MS=25        # 44 * 25 = 1100ms por vuelta, igual que el boot splash
SIZES=(24 32 48 64)

command -v rsvg-convert >/dev/null || { echo "Falta rsvg-convert" >&2; exit 1; }
command -v bc >/dev/null || { echo "Falta bc (paquete bc)" >&2; exit 1; }

# name -> (svg file, rotation center x, rotation center y, native viewBox size)
declare -A CURSORS=(
    [wait]="wait.svg 16 16 32"
    [progress]="bg_progress.svg 24 24 32"
)

for name in "${!CURSORS[@]}"; do
    read -r svgfile cx cy native <<<"${CURSORS[$name]}"
    src_svg="$SRC/$svgfile"
    [ -f "$src_svg" ] || { echo "No existe $src_svg" >&2; exit 1; }

    for size in "${SIZES[@]}"; do
        outdir="$OUT/$name/$size"
        mkdir -p "$outdir"
        for ((f = 0; f < FRAMES; f++)); do
            angle=$(echo "scale=4; $f * 360 / $FRAMES" | bc)
            frame_svg="$outdir/frame_$f.svg"
            sed "s/rotate(0,$cx,$cy)/rotate($angle,$cx,$cy)/" "$src_svg" > "$frame_svg"
            rsvg-convert -w "$size" -h "$size" "$frame_svg" -o "$outdir/frame_$f.png"
            rm -f "$frame_svg"
        done
        echo "  $name @ ${size}px: $FRAMES frames"
    done
done

echo "Frames generados en $OUT (delay ${DELAY_MS}ms/frame, ${FRAMES} frames/vuelta)"
