# punff — chaotic photo wall

A raw, chaotic photo grid with old-web aesthetic and modern touches.

🌐 **Live**: [punff.port0.org](https://punff.port0.org)

## Features

- **Chaotic grid**: Random sizes, rotations, no borders
- **Old-web aesthetic**: CRT scanlines, terminal vibe, dark theme
- **Date/time only**: No captions, no metadata, just timestamps
- **Mobile-friendly**: Responsive chaotic organization
- **Lightweight**: 12KB HTML, minimal everything
- **Peaceful**: No social elements, just photos

## Structure

```
punff-site/
├── index.html              # Generated chaotic wall
├── assets/photos/          # Photo files
├── posts/                  # JSON (date + photos only)
├── templates/              # HTML template
├── scripts/
│   ├── build.js           # Static generator
│   └── new-post.js        # Photo adder
├── build.sh               # Build script
└── new.sh                # Interface
```

## Usage

```bash
./new.sh
```

Options:
- **1) add photos** - Interactive photo upload
- **2) rebuild site** - Regenerate HTML from photos
- **3) view locally** - Start local server at http://localhost:8000
- **4) deploy to server** - Deploy to your Google server

### Quick commands:
```bash
# Just rebuild
./build.sh

# Full deployment
./deploy.sh
```

## Data Format

Photos are stored in `posts/YYYY-MM.json`:
```json
{
  "id": "2025-03-15-sunset",
  "date": "2025-03-15T16:30:00Z",
  "photos": ["sunset.jpg"]
}
```

## Design Principles

1. **Chaotic**: Random sizes, rotations, no order
2. **Old-web**: CRT scanlines, terminal aesthetic
3. **Minimal**: No captions, no metadata, no navigation
4. **Mobile**: Works on phones despite chaos
5. **Raw**: No polish, no corporate feel

## Future Enhancements

- [ ] Camera integration (Olympus EPL-2 auto-import)
- [ ] Image optimization pipeline
- [ ] EXIF metadata extraction
- [ ] Backup to cloud storage
- [ ] RSS feed for followers

## Deployment

The site is static HTML. Deploy by copying `index.html` and `assets/` to your web server.

For your Google server:
```bash
./build.sh  # Automatically copies to /var/www/html if available
```

## Credits

Built for peaceful sharing with an Olympus EPL-2 camera.
No algorithms, no pressure, just photos.