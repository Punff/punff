#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const PHOTOS_DIR    = path.join(__dirname, '..', 'assets', 'photos');
const TEMPLATE_FILE = path.join(__dirname, '..', 'templates', 'base.html');
const OUTPUT_FILE   = path.join(__dirname, '..', 'index.html');
const DATA_FILE     = path.join(__dirname, '..', 'photos-data.json');

const INITIAL_LOAD   = 20;
const LOAD_MORE_BATCH = 10;

// ─── date helpers ────────────────────────────────────────────────────────────

/**
 * Olympus filenames: P<MMDD><seq>.JPG  (no time encoded)
 * Fall back to mtime, which is reliable enough for ordering.
 */
function dateFromFile(filename) {
  try {
    const stats = fs.statSync(path.join(PHOTOS_DIR, filename));
    return new Date(stats.mtime);
  } catch {
    return new Date();
  }
}

/**
 * Returns a compact, unambiguous label: "Apr 13  22:29"
 * Uses UTC+2 (Zagreb / CEST) offset baked in via toLocaleString options.
 * Change timeZone if needed.
 */
function formatLabel(date) {
  return date.toLocaleString('en-GB', {
    timeZone: 'Europe/Zagreb',
    month:    'short',
    day:      'numeric',
    hour:     '2-digit',
    minute:   '2-digit',
    hour12:   false,
  }).replace(',', '');   // "13 Apr  22:29" → keep as-is or reformat below
}

// ─── HTML generation ─────────────────────────────────────────────────────────

function photoHTML(photo, index) {
  const offset = `offset-${(index % 6) + 1}`;
  return `
    <div class="photo-item ${offset}" data-filename="${photo.filename}" data-date="${photo.date}">
      <img src="assets/photos/${photo.filename}" alt="" loading="lazy">
      <div class="photo-time">${photo.label}</div>
    </div>`;
}

// ─── build ───────────────────────────────────────────────────────────────────

async function build() {
  console.log('🔨 Building punff...');

  const template = fs.readFileSync(TEMPLATE_FILE, 'utf8');

  const photos = fs.readdirSync(PHOTOS_DIR)
    .filter(f => /\.(jpg|jpeg|png|gif|webp)$/i.test(f))
    .map(filename => {
      const date  = dateFromFile(filename);
      const label = formatLabel(date);
      return { filename, date: date.toISOString(), label };
    })
    .sort((a, b) => new Date(b.date) - new Date(a.date));

  if (!photos.length) {
    console.error('❌ No photos found in assets/photos/');
    process.exit(1);
  }

  console.log(`📸 Found ${photos.length} photos`);

  // Save JSON data (used by lazy-loader)
  fs.writeFileSync(DATA_FILE, JSON.stringify(
    photos.map(p => ({ filename: p.filename, date: p.date, label: p.label })),
    null, 2
  ));

  const initial   = photos.slice(0, INITIAL_LOAD);
  const remaining = photos.slice(INITIAL_LOAD);

  let content = initial.map((p, i) => photoHTML(p, i)).join('');

  if (remaining.length) {
    content += `
      <div id="load-more-trigger" style="height:1px;"></div>
      <div id="loading-indicator" style="display:none;text-align:center;padding:20px;color:#ff8c00;font-size:12px;font-family:'Courier New',monospace;">
        <span class="dot">.</span><span class="dot">.</span><span class="dot">.</span>
      </div>
      <div id="manual-load-more" style="text-align:center;padding:20px;">
        <button onclick="loadMorePhotos()" style="background:rgba(40,20,0,0.6);border:1px solid rgba(255,140,0,0.15);color:#ff8c00;padding:8px 16px;font-size:12px;font-family:'Courier New',monospace;cursor:pointer;border-radius:3px;">load more</button>
      </div>`;
  }

  const vars = {
    '{{CONTENT}}':            content,
    '{{PHOTO_COUNT}}':        initial.length,
    '{{TOTAL_PHOTOS}}':       photos.length,
    '{{INITIAL_LOAD}}':       INITIAL_LOAD,
    '{{LOAD_MORE_BATCH}}':    LOAD_MORE_BATCH,
    '{{REMAINING_COUNT}}':    remaining.length,
    '{{EMBEDDED_PHOTO_DATA}}': JSON.stringify(
      photos.map(p => ({ filename: p.filename, date: p.date, label: p.label }))
    ),
  };

  let html = template;
  for (const [key, val] of Object.entries(vars)) {
    html = html.replaceAll(key, val);
  }

  // Clean up any leftover template artifacts
  html = html.replace(/\{\{#HIDDEN_COUNT\}\}.*?\{\{\/HIDDEN_COUNT\}\}/gs, '');

  fs.writeFileSync(OUTPUT_FILE, html);

  console.log(`✅ Built index.html  (${initial.length} visible, ${remaining.length} lazy)`);
  console.log(`💾 Data written to photos-data.json`);
}

build().catch(err => { console.error('❌', err); process.exit(1); });
