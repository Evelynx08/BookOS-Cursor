#!/bin/bash
# Compila el tema de cursor BookOS a partir de los SVG en Light/ o Dark/,
# usando xcursorgen. Cada SVG conserva su viewBox nativo (no cuadrado en
# varios casos) — el rasterizado escala width/height proporcionalmente al
# viewBox propio de cada archivo (leído en el momento del build, no de una
# tabla fija) para no distorsionar nada. El hotspot se guarda como fracción
# del tamaño (0-1) y se escala a la resolución real de cada SVG.
#
# Uso: ./build-cursors.sh [VARIANT]   (VARIANT por defecto: Light)
set -euo pipefail

VARIANT="${1:-Light}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/$VARIANT"
CFG="$ROOT/build/config"
OUT="$ROOT/build/$VARIANT/cursors"

SIZES=(24 32 48 64)

command -v rsvg-convert >/dev/null || { echo "Falta rsvg-convert" >&2; exit 1; }
command -v xcursorgen >/dev/null || { echo "Falta xcursorgen (sudo pacman -S xorg-xcursorgen)" >&2; exit 1; }

rm -rf "$CFG" "$OUT"
mkdir -p "$CFG" "$OUT"

# svg (sin .svg) -> "nombre_canonico fx fy alias1,alias2,..."
# fx/fy: posición del hotspot como fracción (0-1) del ancho/alto propio del
# SVG — así funciona igual sin importar el tamaño real de cada variante.
declare -A MAP=(
    [normal_cursor]="left_ptr 0.26 0.15 default,arrow,top_left_arrow"
    [wait]="wait 0.5 0.5 watch"
    [bg_progress]="progress 0.20 0.15 left_ptr_watch,half-busy"
    [link_cursor]="pointer 0.45 0.09 hand1,hand2,pointing_hand,link,alias"
    [text_cursor]="text 0.5 0.5 xterm,ibeam,vertical-text"
    [move_cursor]="move 0.5 0.5 fleur,all-scroll,size_all,dnd-move"
    [grab_mouse]="grab 0.5 0.5 hand1,openhand,closedhand,grabbing"
    [cursor_plus]="copy 0.23 0.15 dnd-copy,cell,plus"
    [cursor_not_allowed]="not-allowed 0.23 0.15 no-drop,forbidden,crossed_circle,circle,dnd-no-drop,dnd-none"
    [cursor_question]="help 0.26 0.15 question_arrow,whats_this,left_ptr_help"
    [cross_spectacle]="crosshair 0.5 0.5 cross,tcross,cross_reverse"
    [resize_horizontal]="ew-resize 0.5 0.5 size_hor,sb_h_double_arrow,h_double_arrow"
    [resize_vertical]="ns-resize 0.5 0.5 size_ver,sb_v_double_arrow,v_double_arrow"
    [resize_diagonal_left]="nesw-resize 0.5 0.5 fd_double_arrow"
    [resize_diagonal_right]="nwse-resize 0.5 0.5 bd_double_arrow"
    [col_resize_horizontal]="col-resize 0.5 0.5 "
    [col_resize_vertical]="row-resize 0.5 0.5 "
    [magnifying_glass_zoom_in]="zoom-in 0.467 0.286 "
    [magnifying_glass_zoom_out]="zoom-out 0.467 0.286 "
    [pencil]="pencil 0.105 0.889 "
)

# scale_dim VALUE NATIVE_MAXDIM TARGET_SIZE -> valor escalado (redondeado)
scale_dim() {
    awk -v v="$1" -v maxdim="$2" -v s="$3" 'BEGIN{printf "%d", (v/maxdim)*s + 0.5}'
}

for base in "${!MAP[@]}"; do
    read -r canonical fx fy aliases <<<"${MAP[$base]}"
    svg="$SRC/$base.svg"
    [ -f "$svg" ] || { echo "No existe $svg" >&2; exit 1; }

    vb=$(grep -o 'viewBox="[^"]*"' "$svg" | head -1 | sed 's/viewBox="//;s/"//')
    read _ _ nw nh <<<"$vb"
    maxdim=$(awk -v w="$nw" -v h="$nh" 'BEGIN{print (w>h)?w:h}')

    cursor_cfg="$CFG/$canonical.cursor"
    : > "$cursor_cfg"

    for size in "${SIZES[@]}"; do
        rw=$(scale_dim "$nw" "$maxdim" "$size")
        rh=$(scale_dim "$nh" "$maxdim" "$size")
        sx=$(awk -v fx="$fx" -v rw="$rw" 'BEGIN{printf "%d", fx*rw + 0.5}')
        sy=$(awk -v fy="$fy" -v rh="$rh" 'BEGIN{printf "%d", fy*rh + 0.5}')
        png="$CFG/${canonical}_$size.png"
        rsvg-convert -w "$rw" -h "$rh" "$svg" -o "$png"
        echo "$size $sx $sy $png" >> "$cursor_cfg"
    done

    xcursorgen "$cursor_cfg" "$OUT/$canonical"
    echo "compilado: $canonical"

    if [ -n "${aliases// /}" ]; then
        IFS=',' read -ra alist <<<"$aliases"
        for a in "${alist[@]}"; do
            [ -n "$a" ] || continue
            ln -sf "$canonical" "$OUT/$a"
        done
    fi
done

cat > "$ROOT/build/$VARIANT/index.theme" <<EOF
[Icon Theme]
Name=BookOS $VARIANT
Comment=Tema de cursor BookOS
Inherits=breeze_cursors
EOF

echo "Tema compilado en $ROOT/build/$VARIANT"
