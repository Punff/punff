#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const PHOTOS_DIR = path.join(__dirname, '..', 'assets', 'photos');
const TEMPLATE_FILE = path.join(__dirname, '..', 'templates', 'base.html');
const OUTPUT_FILE = path.join(__dirname, '..', 'index.html');
const PHOTOS_DATA_FILE = path.join(__dirname, '..', 'photos-data.json');

function parseDateFromFilename(filename) {
  // Try to extract date from filename patterns like:
  // 2026-03-11_20.09.11.png
  // 20250311_200911.jpg
  // IMG_20250311_200911.jpg
  
  const match = filename.match(/(\d{4})[-_]?(\d{2})[-_]?(\d{2})[_\-\.]?(\d{2})[\.\-_]?(\d{2})[\.\-_]?(\d{2})/);
  if (match) {
    const [_, year, month, day, hour, minute, second] = match;
    return new Date(`${year}-${month}-${day}T${hour}:${minute}:${second}`);
  }
  
  // Fallback: use file modification time
  try {
    const stats = fs.statSync(path.join(PHOTOS_DIR, filename));
    return new Date(stats.mtime);
  } catch {
    return new Date(); // Current date as last resort
  }
}

function formatDateTime(date) {
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).replace(',', '');
}

function formatMonth(date) {
  return date.toLocaleDateString('en-US', {
    month: 'long',
    year: 'numeric'
  });
}

function generatePhotoHTML(photo, index) {
  const dateTime = formatDateTime(photo.date);
  
  // Random offset class (1-6)
  const offsetClass = `offset-${(index % 6) + 1}`;
  
  return `
    <div class="photo-item ${offsetClass}" data-filename="${photo.filename}" data-date="${photo.date.toISOString()}">
      <img src="assets/photos/${photo.filename}" alt="" loading="lazy">
      <div class="photo-time">${dateTime}</div>
    </div>
  `;
}



async function buildSite() {
  console.log('🔨 Building punff from photos...');
  
  // Read template
  const template = fs.readFileSync(TEMPLATE_FILE, 'utf8');
  
  // Get all photo files
  const photoFiles = fs.readdirSync(PHOTOS_DIR)
    .filter(file => /\.(jpg|jpeg|png|gif|webp)$/i.test(file))
    .map(filename => {
      const date = parseDateFromFilename(filename);
      return { filename, date };
    })
    .sort((a, b) => b.date - a.date); // Newest first
  
  console.log(`📸 Found ${photoFiles.length} photos`);
  
  if (photoFiles.length === 0) {
    console.log('❌ No photos found in assets/photos/');
    console.log('   Add some photos and run again');
    process.exit(1);
  }
  
  // Save photo data for JavaScript to use (just filenames and dates)
  const photoDataForJs = photoFiles.map(photo => ({
    filename: photo.filename,
    date: photo.date.toISOString()
  }));
  
  fs.writeFileSync(PHOTOS_DATA_FILE, JSON.stringify(photoDataForJs, null, 2));
  
  // Also embed photo data in HTML for file:// protocol support
  const embeddedPhotoData = JSON.stringify(photoDataForJs);
  
  // Initial load batch size
  const INITIAL_LOAD = 20;
  const LOAD_MORE_BATCH = 10;
  
  const initialPhotos = photoFiles.slice(0, INITIAL_LOAD);
  const remainingPhotos = photoFiles.slice(INITIAL_LOAD);
  
  console.log(`📱 Initial load: ${initialPhotos.length} photos`);
  console.log(`   ${remainingPhotos.length} more photos available for lazy loading`);
  
  // Generate initial HTML
  let allContent = '';
  initialPhotos.forEach((photo, index) => {
    allContent += generatePhotoHTML(photo, index);
  });
  
  // Add load more placeholder if there are more photos
  if (remainingPhotos.length > 0) {
    allContent += `
      <div id="load-more-trigger" style="height: 1px;"></div>
      <div id="loading-indicator" style="display: none; text-align: center; padding: 20px; color: #ff8c00; font-size: 12px; font-family: 'Courier New', monospace; text-shadow: 0 0 2px rgba(255, 140, 0, 0.2);">
        <span class="dot">.</span><span class="dot">.</span><span class="dot">.</span>
      </div>
      <div id="manual-load-more" style="text-align: center; padding: 20px;">
        <button onclick="loadMorePhotos()" style="background: rgba(40, 20, 0, 0.6); border: 1px solid rgba(255, 140, 0, 0.15); color: #ff8c00; padding: 8px 16px; font-size: 12px; font-family: 'Courier New', monospace; cursor: pointer; text-shadow: 0 0 2px rgba(255, 140, 0, 0.2); transition: all 0.2s ease; border-radius: 3px;">load more</button>
      </div>
    `;
  }
  
  // Insert content into template
  let finalHTML = template.replace('{{CONTENT}}', allContent);
  
  // Replace all occurrences of each placeholder
  const replacements = {
    '{{PHOTO_COUNT}}': initialPhotos.length,
    '{{TOTAL_PHOTOS}}': photoFiles.length,
    '{{INITIAL_LOAD}}': INITIAL_LOAD,
    '{{LOAD_MORE_BATCH}}': LOAD_MORE_BATCH,
    '{{REMAINING_COUNT}}': remainingPhotos.length,
    '{{EMBEDDED_PHOTO_DATA}}': embeddedPhotoData
  };
  
  Object.entries(replacements).forEach(([placeholder, value]) => {
    // Replace all occurrences globally
    const regex = new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');
    finalHTML = finalHTML.replace(regex, value);
  });
  
  // Remove the old hidden count placeholder
  finalHTML = finalHTML.replace('{{#HIDDEN_COUNT}}<span class="more-photos" title="{{HIDDEN_COUNT}} older photos hidden">+{{HIDDEN_COUNT}}</span>{{/HIDDEN_COUNT}}', '');
  
  // Write output
  fs.writeFileSync(OUTPUT_FILE, finalHTML);
  
  console.log(`✅ Built ${OUTPUT_FILE}`);
  console.log(`📊 Photos: ${initialPhotos.length} loaded, ${remainingPhotos.length} available for lazy load`);
  console.log(`💾 Photo data saved to ${PHOTOS_DATA_FILE}`);
}

// Run build
buildSite().catch(error => {
  console.error('❌ Build failed:', error);
  process.exit(1);
});