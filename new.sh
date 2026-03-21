#!/bin/bash

PUNFF_DIR="$(cd "$(dirname "$0")" && pwd)"
MONTHS_DIR="$PUNFF_DIR/months"
PHOTOS_INBOX="$HOME/sync/photos"
AUDIO_INBOX="$HOME/sync/audio"
ASSETS_DIR="/var/www/html/assets"
TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)
MONTH_FILE="$MONTHS_DIR/$MONTH.html"

ROTATIONS=("-0.8deg" "1.1deg" "-1.4deg" "0.7deg" "-0.9deg" "0.4deg" "1.3deg" "-0.5deg" "1.8deg" "-1.1deg")
ROT=${ROTATIONS[$((RANDOM % ${#ROTATIONS[@]}))]}

BORDERS=(
  "M2,2.5 C25,1.8 75,2.2 98,1.8 C98.5,25 98.2,75 98.5,98 C75,98.4 25,97.8 2,98.3 C1.5,75 1.8,25 2,2.5Z|1.8"
  "M2.5,1.8 C30,2.5 70,1.5 97.5,2.5 C98.5,28 97.8,72 98.5,98.5 C72,97.5 28,98.8 2,97.5 C1.2,72 2,28 2.5,1.8Z|2.5"
  "M3,2 C28,1.2 72,2.5 98,1.5 C98.8,30 98.2,68 97.5,98 C70,99 30,98.2 2.5,99 C1.8,70 2.2,28 3,2Z|1.4"
  "M2.2,2 C28,1.8 72,2.5 97.8,1.5 C98.5,30 97.5,68 98.8,97.5 C72,98.8 28,97.5 2.5,98.5 C1.5,68 2.2,30 2.2,2Z|1.2"
  "M1.8,1.5 C30,2.8 70,1.2 98.5,2.5 C97.8,28 98.5,72 98,98.5 C70,97.2 28,98.8 2.2,97.5 C2.5,72 1.5,30 1.8,1.5Z|2"
  "M3,1.8 C28,2.5 72,1.5 97.5,2.8 C98.2,30 99,70 97.8,98.2 C70,99.5 30,97.8 2.5,98.8 C1.8,70 2.5,28 3,1.8Z|1.6"
)
BORDER_RAW=${BORDERS[$((RANDOM % ${#BORDERS[@]}))]}
BORDER_PATH="${BORDER_RAW%|*}"
BORDER_WIDTH="${BORDER_RAW#*|}"

border_svg() {
  echo "<svg class=\"border\" viewBox=\"0 0 100 100\" preserveAspectRatio=\"none\"><path d=\"$BORDER_PATH\" fill=\"none\" stroke=\"#111\" stroke-width=\"$BORDER_WIDTH\" vector-effect=\"non-scaling-stroke\"/></svg>"
}

card_open() {
  local extra_class="${1:-}"
  echo "<div class=\"card $extra_class\" style=\"transform:rotate($ROT);\">"
  border_svg
}

card_close() {
  local date="${1:-$TODAY}"
  echo "  <div class=\"date-tag\">$date</div>"
  echo "</div>"
  echo ""
}

init_month() {
  if [ ! -f "$MONTH_FILE" ]; then
    local month_rot=${ROTATIONS[$((RANDOM % ${#ROTATIONS[@]}))]}
    local mb=${BORDERS[$((RANDOM % ${#BORDERS[@]}))]}
    local mp="${mb%|*}"
    local mw="${mb#*|}"
    cat > "$MONTH_FILE" <<EOF
<div class="month-section">
<div class="card month-card" style="transform:rotate($month_rot);">
  <svg class="border" viewBox="0 0 100 100" preserveAspectRatio="none"><path d="$mp" fill="none" stroke="#111" stroke-width="$mw" vector-effect="non-scaling-stroke"/></svg>
  <div class="month-text">$(date +"%B" | tr '[:upper:]' '[:lower:]')<span class="month-year">$(date +%Y)</span></div>
</div>
<div class="grid">
EOF
    echo "  → created $MONTH_FILE"
  fi
}

append_card() {
  local card="$1"
  local tmp=$(mktemp)
  head -n -2 "$MONTH_FILE" > "$tmp"
  echo "$card" >> "$tmp"
  echo "</div>" >> "$tmp"
  echo "</div>" >> "$tmp"
  mv "$tmp" "$MONTH_FILE"
}

card_text() {
  echo ""
  read -p "text: " content
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <span class=\"type-tag\">text</span>
  <p class=\"text-content i\">$content</p>
$(card_close "$date")"
  append_card "$card"
}

card_music() {
  echo "tracks (artist - title), empty line to finish:"
  local tracks=""
  while true; do
    read -p "  > " line
    [ -z "$line" ] && break
    local artist=$(echo "$line" | awk -F' - ' '{print $1}' | sed 's/[[:space:]]*$//')
    local title=$(echo "$line" | awk -F' - ' '{print $2}' | sed 's/^[[:space:]]*//')
    tracks+="  <div class=\"track-line\"><span class=\"track-artist\">$artist</span>$title</div>\n"
  done
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <span class=\"type-tag\">music</span>
$(echo -e "$tracks")$(card_close "$date")"
  append_card "$card"
}

card_link() {
  echo "links (title | source | url), empty line to finish:"
  local links=""
  while true; do
    read -p "  > " line
    [ -z "$line" ] && break
    local title=$(echo "$line" | cut -d'|' -f1 | sed 's/[[:space:]]*$//')
    local source=$(echo "$line" | cut -d'|' -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local url=$(echo "$line" | cut -d'|' -f3 | sed 's/^[[:space:]]*//')
    links+="  <a class=\"link-item\" href=\"$url\">$title<br><span class=\"link-src\">$source</span></a>\n"
  done
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <span class=\"type-tag\">links</span>
$(echo -e "$links")$(card_close "$date")"
  append_card "$card"
}

card_travel() {
  read -p "from: " from
  read -p "to: " to
  read -p "note (e.g. bus — 5h): " note
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <span class=\"type-tag\">travel</span>
  <div class=\"travel-route\">$from<span class=\"travel-arrow\">→</span>$to</div>
  <div class=\"travel-meta\">$date — $note</div>
$(card_close "$date")"
  append_card "$card"
}

card_film() {
  echo "films (title | year), empty line to finish:"
  local items=""
  while true; do
    read -p "  > " line
    [ -z "$line" ] && break
    local title=$(echo "$line" | cut -d'|' -f1 | sed 's/[[:space:]]*$//')
    local year=$(echo "$line" | cut -d'|' -f2 | sed 's/^[[:space:]]*//')
    items+="  <div class=\"li\">$title<span>$year</span></div>\n"
  done
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <span class=\"type-tag\">films</span>
$(echo -e "$items")  <div style=\"font-size:9px;color:#aaa;margin-top:9px;\">suggest → mario@punff.port0.org</div>
$(card_close "$date")"
  append_card "$card"
}

card_photo() {
  echo "photos in $PHOTOS_INBOX:"
  ls "$PHOTOS_INBOX" 2>/dev/null | nl
  echo ""
  read -p "filename(s), space separated (or * for all): " selection
  read -p "dump or single? [dump/single]: " ptype
  ptype=${ptype:-dump}
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}

  mkdir -p "$ASSETS_DIR/photos"
  local photo_tags=""

  if [ "$selection" = "*" ]; then
    files=("$PHOTOS_INBOX"/*)
  else
    files=()
    for f in $selection; do
      files+=("$PHOTOS_INBOX/$f")
    done
  fi

  for f in "${files[@]}"; do
    local fname=$(basename "$f")
    cp "$f" "$ASSETS_DIR/photos/$fname"
    if [ "$ptype" = "single" ]; then
      photo_tags+="  <div class=\"ph full\" style=\"background-image:url('/assets/photos/$fname');background-size:cover;background-position:center;\"></div>\n"
    else
      photo_tags+="  <div class=\"ph sq\" style=\"background-image:url('/assets/photos/$fname');background-size:cover;background-position:center;\"></div>\n"
    fi
  done

  local extra=""
  [ "$ptype" = "dump" ] && extra="wide"

  local card
  if [ "$ptype" = "dump" ]; then
    card="$(card_open "$extra")
  <span class=\"type-tag\">photo dump</span>
  <div class=\"photo-grid\">
$(echo -e "$photo_tags")  </div>
$(card_close "$date")"
  else
    card="$(card_open)
  <span class=\"type-tag\">photo</span>
$(echo -e "$photo_tags")$(card_close "$date")"
  fi

  append_card "$card"
}

card_audio() {
  echo "audio files in $AUDIO_INBOX:"
  ls "$AUDIO_INBOX" 2>/dev/null | nl
  echo ""
  read -p "filename(s), space separated: " selection
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}

  mkdir -p "$ASSETS_DIR/audio"
  local audio_tags=""

  for f in $selection; do
    local fpath="$AUDIO_INBOX/$f"
    cp "$fpath" "$ASSETS_DIR/audio/$f"
    local dur=""
    if command -v ffprobe &>/dev/null; then
      dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$fpath" 2>/dev/null | awk '{m=int($1/60);s=int($1%60);printf "%d:%02d",m,s}')
    fi
    audio_tags+="  <div class=\"audio-row\"><div class=\"audio-play\"><div class=\"audio-tri\"></div></div><span class=\"audio-title\">$f</span><span class=\"audio-dur\">$dur</span></div>\n"
  done

  local card
  card="$(card_open)
  <span class=\"type-tag\">audio</span>
$(echo -e "$audio_tags")$(card_close "$date")"
  append_card "$card"
}

card_gear() {
  read -p "name: " name
  read -p "note: " note
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <span class=\"type-tag\">gear</span>
  <div class=\"gear-name\">$name</div>
  <div class=\"gear-note\">$note</div>
$(card_close "$date")"
  append_card "$card"
}

card_recipe() {
  read -p "name: " name
  echo "ingredients (ingredient | amount), empty line to finish:"
  local rows=""
  while true; do
    read -p "  > " line
    [ -z "$line" ] && break
    local ing=$(echo "$line" | cut -d'|' -f1 | sed 's/[[:space:]]*$//')
    local amt=$(echo "$line" | cut -d'|' -f2 | sed 's/^[[:space:]]*//')
    rows+="  <div class=\"recipe-row\">$ing<span class=\"recipe-amt\">$amt</span></div>\n"
  done
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <span class=\"type-tag\">recipe</span>
  <div class=\"gear-name\" style=\"margin-bottom:8px;\">$name</div>
$(echo -e "$rows")$(card_close "$date")"
  append_card "$card"
}

# ── main ──────────────────────────────────────────────────────────────────────

echo ""
echo "punff / new card"
echo "────────────────"
echo "  1) text"
echo "  2) music"
echo "  3) link"
echo "  4) travel"
echo "  5) film"
echo "  6) photo"
echo "  7) audio"
echo "  8) gear"
echo "  9) recipe"
echo ""
read -p "type: " choice

mkdir -p "$MONTHS_DIR"
init_month

case $choice in
  1|text)    card_text ;;
  2|music)   card_music ;;
  3|link)    card_link ;;
  4|travel)  card_travel ;;
  5|film)    card_film ;;
  6|photo)   card_photo ;;
  7|audio)   card_audio ;;
  8|gear)    card_gear ;;
  9|recipe)  card_recipe ;;
  *) echo "unknown type"; exit 1 ;;
esac

echo ""
echo "  → rebuilding..."
bash "$PUNFF_DIR/build.sh"
echo "  → punff.port0.org updated."
echo ""
