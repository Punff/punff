#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const PHOTOS_DIR = path.join(__dirname, '..', 'assets', 'photos');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function ask(question) {
  return new Promise(resolve => {
    rl.question(question, answer => resolve(answer.trim()));
  });
}

async function main() {
  console.log('\npunff — add photos');
  console.log('─────────────────\n');
  
  // List existing photos
  const existingPhotos = fs.readdirSync(PHOTOS_DIR)
    .filter(file => /\.(jpg|jpeg|png|gif|webp)$/i.test(file));
  
  if (existingPhotos.length > 0) {
    console.log(`existing photos (${existingPhotos.length}):`);
    existingPhotos.slice(0, 10).forEach((photo, i) => {
      console.log(`  ${i + 1}. ${photo}`);
    });
    if (existingPhotos.length > 10) {
      console.log(`  ... and ${existingPhotos.length - 10} more`);
    }
    console.log('');
  }
  
  // Ask for photo filenames (or copy from somewhere)
  console.log('enter photo filenames to add (or full paths to copy):');
  console.log('(empty line to finish)');
  
  const photosToAdd = [];
  while (true) {
    const input = await ask('  > ');
    if (!input) break;
    
    // Check if file exists at given path
    if (fs.existsSync(input)) {
      // Copy file to photos directory
      const filename = path.basename(input);
      const destPath = path.join(PHOTOS_DIR, filename);
      
      // Handle duplicate filenames
      let finalFilename = filename;
      let counter = 1;
      while (fs.existsSync(path.join(PHOTOS_DIR, finalFilename))) {
        const ext = path.extname(filename);
        const name = path.basename(filename, ext);
        finalFilename = `${name}_${counter}${ext}`;
        counter++;
      }
      
      fs.copyFileSync(input, path.join(PHOTOS_DIR, finalFilename));
      photosToAdd.push(finalFilename);
      console.log(`    copied → ${finalFilename}`);
    } else {
      // Assume it's already in photos directory
      if (fs.existsSync(path.join(PHOTOS_DIR, input))) {
        photosToAdd.push(input);
        console.log(`    added → ${input}`);
      } else {
        console.log(`    ❌ not found: ${input}`);
      }
    }
  }
  
  if (photosToAdd.length === 0) {
    console.log('no photos added');
    rl.close();
    return;
  }
  
  console.log(`\nadded ${photosToAdd.length} photos`);
  
  rl.close();
  
  // Ask to rebuild
  const rebuild = await ask('\nrebuild? (y/n): ');
  if (rebuild.toLowerCase() === 'y') {
    console.log('rebuilding...');
    const { execSync } = require('child_process');
    execSync('node scripts/build.js', { stdio: 'inherit' });
    console.log('done');
  }
}

main().catch(error => {
  console.error('error:', error);
  rl.close();
  process.exit(1);
});