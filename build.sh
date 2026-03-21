#!/bin/bash

PUNFF_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="/var/www/html/index.html"

cat "$PUNFF_DIR/template/header.html" > "$OUTPUT"

for f in $(ls "$PUNFF_DIR/months/"*.html 2>/dev/null | sort -r); do
  cat "$f" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
done

cat "$PUNFF_DIR/template/footer.html" >> "$OUTPUT"

echo "  built → $OUTPUT"
