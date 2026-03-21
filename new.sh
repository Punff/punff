#!/bin/bash

PUNFF_DIR="$(cd "$(dirname "$0")" && pwd)"
MONTHS_DIR="$PUNFF_DIR/months"
PHOTOS_INBOX="$HOME/sync/photos"
AUDIO_INBOX="$HOME/sync/audio"
ASSETS_DIR="/var/www/html/assets"
TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)
MONTH_FILE="$MONTHS_DIR/$MONTH.html"

ROTATIONS=("r1" "r2" "r3" "r4" "r5" "r6")
ROT=${ROTATIONS[$((RANDOM % ${#ROTATIONS[@]}))]}

BORDERS=(
  "M2,2.5 C25,1.8 75,2.2 98,2 C98.5,25 98.2,75 98.5,98 C75,98.4 25,97.8 2,98.3 C1.5,75 1.8,25 2,2.5Z|1.8"
  "M2.5,1.8 C30,2.5 70,1.5 97.5,2.5 C98.5,28 97.8,72 98.5,98.5 C72,97.5 28,98.8 2,97.5 C1.2,72 2,28 2.5,1.8Z|2.5"
  "M3,2 C28,1.2 72,2.5 98,1.5 C98.8,30 98.2,68 97.5,98 C70,99 30,98.2 2.5,99 C1.8,70 2.2,28 3,2Z|1.4"
  "M2.2,2 C28,1.8 72,2.5 97.8,1.5 C98.5,30 97.5,68 98.8,97.5 C72,98.8 28,97.5 2.5,98.5 C1.5,68 2.2,30 2.2,2Z|1.2"
  "M1.8,1.5 C30,2.8 70,1.2 98.5,2.5 C97.8,28 98.5,72 98,98.5 C70,97.2 28,98.8 2.2,97.5 C2.5,72 1.5,30 1.8,1.5Z|2"
  "M3,1.8 C28,2.5 72,1.5 97.5,2.8 C98.2,30 99,70 97.8,98.2 C70,99.5 30,97.8 2.5,98.8 C1.8,70 2.5,28 3,1.8Z|1.6"
)
pick_border() {
  local b=${BORDERS[$((RANDOM % ${#BORDERS[@]}))]}
  BORDER_PATH="${b%|*}"
  BORDER_WIDTH="${b#*|}"
}

border_svg() {
  local dash="${1:-}"
  local dashattr=""
  [ -n "$dash" ] && dashattr=' stroke-dasharray="4 3"'
  echo "<svg class=\"b\" viewBox=\"0 0 100 100\" preserveAspectRatio=\"none\"><path d=\"$BORDER_PATH\" fill=\"none\" stroke=\"#1c1c17\" stroke-width=\"$BORDER_WIDTH\"$dashattr vector-effect=\"non-scaling-stroke\"/></svg>"
}

card_open() {
  local extra="${1:-}"
  pick_border
  echo "<div class=\"card $ROT $extra\">"
  border_svg
}

card_open_dashed() {
  pick_border
  echo "<div class=\"card $ROT\">"
  border_svg "dashed"
}

card_close() {
  local date="${1:-$TODAY}"
  echo "  <div class=\"date\">$date</div>"
  echo "</div>"
  echo ""
}

init_month() {
  if [ ! -f "$MONTH_FILE" ]; then
    local rot=${ROTATIONS[$((RANDOM % ${#ROTATIONS[@]}))]}
    pick_border
    cat > "$MONTH_FILE" <<EOF
<div class="card month-card $rot">
  <svg class="b" viewBox="0 0 100 100" preserveAspectRatio="none"><path d="$BORDER_PATH" fill="none" stroke="#1c1c17" stroke-width="$BORDER_WIDTH" vector-effect="non-scaling-stroke"/></svg>
  <div class="month-label">$(date +"%B" | tr '[:upper:]' '[:lower:]')<span class="month-year">$(date +%Y)</span></div>
</div>
EOF
    echo "  → created $MONTH_FILE"
  fi
}

append_card() {
  local card="$1"
  echo "$card" >> "$MONTH_FILE"
}

# ── card builders ─────────────────────────────────────────────────────────────

card_text() {
  echo ""
  read -p "text: " content
  read -p "italic? [y/n, default y]: " ital
  ital=${ital:-y}
  read -p "dark card? [y/n, default n]: " dark
  dark=${dark:-n}
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}

  local extra=""
  [ "$dark" = "y" ] && extra="dark" || extra="filled"
  local cls="text-body"
  [ "$ital" = "y" ] && cls="text-body i"

  local card
  card="$(card_open "$extra")
  <p class=\"$cls\">$content</p>
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
    tracks+="  <div class=\"track\"><span class=\"track-artist\">$artist</span>$title</div>\n"
  done
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open_dashed)
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
    links+="  <a class=\"link-row\" href=\"$url\">$title<span class=\"link-src\">$source</span></a>\n"
  done
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open "filled")
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
  card="$(card_open "filled")
  <div class=\"route\">$from<span class=\"route-arrow\">→</span>$to</div>
  <div class=\"route-meta\">$date — $note</div>
$(card_close "$date")"
  append_card "$card"
}

card_film() {
  echo "films (title | year), mark seen with a * at the end: title | year | *"
  echo "empty line to finish:"
  local items=""
  while true; do
    read -p "  > " line
    [ -z "$line" ] && break
    local title=$(echo "$line" | cut -d'|' -f1 | sed 's/[[:space:]]*$//')
    local year=$(echo "$line" | cut -d'|' -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local seen=$(echo "$line" | cut -d'|' -f3 | sed 's/^[[:space:]]*//')
    local cls="film-row"
    [ "$seen" = "*" ] && cls="film-row seen"
    items+="  <div class=\"$cls\">$title<span class=\"film-year\">$year</span></div>\n"
  done
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open_dashed)
$(echo -e "$items")  <div class=\"suggest\">suggest → mario@punff.port0.org</div>
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
      photo_tags+="  <div class=\"ph-full\"><img src=\"/assets/photos/$fname\" alt=\"\"/></div>\n"
    else
      photo_tags+="    <div class=\"ph sq\"><img src=\"/assets/photos/$fname\" alt=\"\"/></div>\n"
    fi
  done

  local card
  if [ "$ptype" = "dump" ]; then
    card="$(card_open)
  <div class=\"photo-grid\">
$(echo -e "$photo_tags")  </div>
$(card_close "$date")"
  else
    card="$(card_open)
  <div style=\"padding:0;\">
$(echo -e "$photo_tags")  </div>
$(card_close "$date")"
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
    audio_tags+="  <div class=\"audio-row\"><div class=\"play-btn\" data-file=\"$f\"><div class=\"tri\"></div></div><span class=\"audio-title\">$f</span><span class=\"audio-dur\">$dur</span></div>\n"
  done

  local card
  card="$(card_open)
$(echo -e "$audio_tags")$(card_close "$date")"
  append_card "$card"
}

card_video() {
  read -p "youtube url: " url
  read -p "title (optional): " title
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open)
  <a href=\"$url\" target=\"_blank\" style=\"text-decoration:none;\">
    <div class=\"yt-box\"><div class=\"yt-tri\"></div></div>
  </a>
  $([ -n "$title" ] && echo "<div class=\"yt-title\">$title</div>")
$(card_close "$date")"
  append_card "$card"
}

card_gear() {
  read -p "name: " name
  read -p "note: " note
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open "filled")
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
  <div class=\"recipe-name\">$name</div>
$(echo -e "$rows")$(card_close "$date")"
  append_card "$card"
}

card_event() {
  read -p "name: " name
  read -p "meta (place, people, etc): " meta
  read -p "date [$TODAY]: " date
  date=${date:-$TODAY}
  local card
  card="$(card_open "filled")
  <div class=\"event-name\">$name</div>
  <div class=\"event-meta\">$meta</div>
$(card_close "$date")"
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
echo "  8) video"
echo "  9) gear"
echo " 10) recipe"
echo " 11) event"
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
  8|video)   card_video ;;
  9|gear)    card_gear ;;
  10|recipe) card_recipe ;;
  11|event)  card_event ;;
  *) echo "unknown type"; exit 1 ;;
esac

echo ""
echo "  → rebuilding..."
bash "$PUNFF_DIR/build.sh"
echo "  → punff.port0.org updated."
echo ""
