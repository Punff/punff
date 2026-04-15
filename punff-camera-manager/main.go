package main

import (
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"golang.org/x/image/draw"
)

// ─── paths ───────────────────────────────────────────────────────────────────

var (
	cameraPath = "/run/media/punff/disk/DCIM/101OLYMP/"
	siteRoot   = filepath.Join(home(), "punff-site")
	photosDir  = filepath.Join(siteRoot, "assets", "photos")
	editDir    = filepath.Join(siteRoot, "to-edit")
	archiveDir = filepath.Join(home(), "Documents", "kamera-backup")
	trashDir   = filepath.Join(home(), ".local", "share", "Trash", "files")

	deployHost = "punff.port0.org"
	deployUser = "marioantunovic13"
	deployPath = "/var/www/html"
)

func home() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return "/home/punff"
	}
	return h
}

// ─── theme ───────────────────────────────────────────────────────────────────

var (
	colBg     = color.NRGBA{R: 0x0a, G: 0x0a, B: 0x0a, A: 0xff}
	colOrange = color.NRGBA{R: 0xff, G: 0x8c, B: 0x00, A: 0xff}
	colDim    = color.NRGBA{R: 0x55, G: 0x55, B: 0x55, A: 0xff}
	colRed    = color.NRGBA{R: 0xff, G: 0x44, B: 0x44, A: 0xff}
	colGreen  = color.NRGBA{R: 0x44, G: 0xff, B: 0x44, A: 0xff}
	colBlue   = color.NRGBA{R: 0x44, G: 0x88, B: 0xff, A: 0xff}
)

type punffTheme struct{}

func (punffTheme) Color(n fyne.ThemeColorName, _ fyne.ThemeVariant) color.Color {
	switch n {
	case theme.ColorNameBackground:
		return colBg
	case theme.ColorNameForeground:
		return colOrange
	case theme.ColorNamePrimary:
		return colOrange
	case theme.ColorNameButton:
		return color.NRGBA{R: 0x1a, G: 0x1a, B: 0x1a, A: 0xff}
	case theme.ColorNameInputBackground:
		return color.NRGBA{R: 0x1a, G: 0x1a, B: 0x1a, A: 0xff}
	case theme.ColorNameDisabled:
		return colDim
	case theme.ColorNameShadow:
		return color.Transparent
	case theme.ColorNameOverlayBackground:
		return color.NRGBA{R: 0x12, G: 0x12, B: 0x12, A: 0xff}
	}
	return color.NRGBA{R: 0x33, G: 0x33, B: 0x33, A: 0xff}
}

func (punffTheme) Font(s fyne.TextStyle) fyne.Resource     { return theme.DefaultTheme().Font(s) }
func (punffTheme) Icon(n fyne.ThemeIconName) fyne.Resource { return theme.DefaultTheme().Icon(n) }
func (punffTheme) Size(n fyne.ThemeSizeName) float32 {
	switch n {
	case theme.SizeNameText:
		return 13
	case theme.SizeNamePadding:
		return 6
	case theme.SizeNameInnerPadding:
		return 8
	}
	return theme.DefaultTheme().Size(n)
}

// ─── undo entry ──────────────────────────────────────────────────────────────

type undoEntry struct {
	action  string // "trash","archive","post","edit"
	srcJPEG string // original path on camera
	dstJPEG string // where it ended up
	srcORF  string // .ORF path (may be "")
	dstORF  string
}

// ─── app state ───────────────────────────────────────────────────────────────

type camApp struct {
	win fyne.Window

	photos  []string // full paths to JPEGs on camera
	idx     int
	rotStep int // 0..3  (× 90° clockwise)

	undoStack []undoEntry

	// UI widgets
	imgCanvas  *canvas.Image
	infoLabel  *widget.Label // "DSC0042.JPG"
	countLabel *widget.Label // "3 / 17"
	logLabel   *widget.Label // status / log line
}

// ─── main ────────────────────────────────────────────────────────────────────

func main() {
	a := app.New()
	a.Settings().SetTheme(punffTheme{})

	w := a.NewWindow("punff camera")
	w.Resize(fyne.NewSize(960, 680))
	w.SetFixedSize(false)

	ca := &camApp{win: w}
	ca.build(w)

	// ensure dirs exist
	for _, d := range []string{photosDir, editDir, archiveDir, trashDir} {
		_ = os.MkdirAll(d, 0o755)
	}

	ca.loadPhotos()

	w.Canvas().SetOnTypedKey(ca.handleKey)
	w.ShowAndRun()
}

// ─── UI build ────────────────────────────────────────────────────────────────

func (ca *camApp) build(w fyne.Window) {
	// top bar: info left, count right
	ca.infoLabel = widget.NewLabel("no photos")
	ca.infoLabel.TextStyle = fyne.TextStyle{Monospace: true}

	ca.countLabel = widget.NewLabel("")
	ca.countLabel.TextStyle = fyne.TextStyle{Monospace: true}
	ca.countLabel.Alignment = fyne.TextAlignTrailing

	topBar := container.NewBorder(nil, nil, ca.infoLabel, ca.countLabel)

	// image
	ca.imgCanvas = canvas.NewImageFromImage(blankImage())
	ca.imgCanvas.FillMode = canvas.ImageFillContain
	ca.imgCanvas.SetMinSize(fyne.NewSize(700, 500))

	// action buttons row
	trashBtn := newActionBtn("← Trash", colRed, ca.doTrash)
	archBtn := newActionBtn("↓ Archive", colGreen, ca.doArchive)
	editBtn := newActionBtn("↑ Edit", colBlue, ca.doEdit)
	postBtn := newActionBtn("→ Post", colOrange, ca.doPost)

	actions := container.New(layout.NewGridLayout(4),
		trashBtn, archBtn, editBtn, postBtn)

	// control row
	undoBtn := widget.NewButton("↶ Undo  Ctrl+Z", ca.doUndo)
	rotBtn := widget.NewButton("↻ Rotate  R", ca.doRotate)
	deployBtn := widget.NewButton("⬆ Deploy", ca.doDeploy)

	controls := container.NewHBox(undoBtn, rotBtn, layout.NewSpacer(), deployBtn)

	// log
	ca.logLabel = widget.NewLabel("ready — connect camera and load photos")
	ca.logLabel.TextStyle = fyne.TextStyle{Monospace: true}
	ca.logLabel.Wrapping = fyne.TextWrap(fyne.TextTruncateClip)

	content := container.NewBorder(
		container.NewVBox(topBar),                         // top
		container.NewVBox(actions, controls, ca.logLabel), // bottom
		nil, nil,
		ca.imgCanvas, // center
	)

	w.SetContent(content)
}

func newActionBtn(label string, col color.Color, fn func()) *widget.Button {
	btn := widget.NewButton(label, fn)
	_ = col // Fyne doesn't support per-button color easily without custom renderer
	btn.Importance = widget.MediumImportance
	return btn
}

// ─── photo loading ───────────────────────────────────────────────────────────

func (ca *camApp) loadPhotos() {
	entries, err := os.ReadDir(cameraPath)
	if err != nil {
		ca.log("camera not found at " + cameraPath)
		return
	}

	ca.photos = nil
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		ext := strings.ToLower(filepath.Ext(name))
		if ext == ".jpg" || ext == ".jpeg" {
			ca.photos = append(ca.photos, filepath.Join(cameraPath, name))
		}
	}

	if len(ca.photos) == 0 {
		ca.log("no JPEG photos found on camera")
		ca.infoLabel.SetText("no photos")
		ca.countLabel.SetText("0 / 0")
		return
	}

	ca.idx = 0
	ca.rotStep = 0
	ca.log(fmt.Sprintf("loaded %d photos", len(ca.photos)))
	ca.showCurrent()
}

// ─── display ─────────────────────────────────────────────────────────────────

func (ca *camApp) showCurrent() {
	if len(ca.photos) == 0 {
		ca.imgCanvas.Image = blankImage()
		ca.imgCanvas.Refresh()
		ca.infoLabel.SetText("done")
		ca.countLabel.SetText("0 / 0")
		return
	}

	path := ca.photos[ca.idx]
	ca.infoLabel.SetText(filepath.Base(path))
	ca.countLabel.SetText(fmt.Sprintf("%d / %d", ca.idx+1, len(ca.photos)))

	img, err := loadJPEG(path)
	if err != nil {
		ca.log("error loading image: " + err.Error())
		return
	}

	if ca.rotStep > 0 {
		img = rotateImage(img, ca.rotStep)
	}

	ca.imgCanvas.Image = img
	ca.imgCanvas.Refresh()
}

// ─── key handler ─────────────────────────────────────────────────────────────

func (ca *camApp) handleKey(ev *fyne.KeyEvent) {
	switch ev.Name {
	case fyne.KeyLeft:
		ca.doTrash()
	case fyne.KeyDown:
		ca.doArchive()
	case fyne.KeyUp:
		ca.doEdit()
	case fyne.KeyRight:
		ca.doPost()
	case fyne.KeyR:
		ca.doRotate()
	case fyne.KeyZ:
		ca.doUndo()
	}
}

// ─── actions ─────────────────────────────────────────────────────────────────

func (ca *camApp) doTrash() {
	ca.act("trash", func(jpeg, orf string) error {
		dst, err := moveFile(jpeg, trashDir)
		if err != nil {
			return err
		}
		ca.undoStack = append(ca.undoStack, undoEntry{
			action: "trash", srcJPEG: jpeg, dstJPEG: dst,
		})
		if orf != "" {
			dstORF, err2 := moveFile(orf, trashDir)
			if err2 == nil {
				ca.undoStack[len(ca.undoStack)-1].srcORF = orf
				ca.undoStack[len(ca.undoStack)-1].dstORF = dstORF
			}
		}
		return nil
	})
}

func (ca *camApp) doArchive() {
	ca.act("archive", func(jpeg, orf string) error {
		dst, err := moveFile(jpeg, archiveDir)
		if err != nil {
			return err
		}
		ca.undoStack = append(ca.undoStack, undoEntry{
			action: "archive", srcJPEG: jpeg, dstJPEG: dst,
		})
		if orf != "" {
			dstORF, err2 := moveFile(orf, trashDir) // trash the raw
			if err2 == nil {
				ca.undoStack[len(ca.undoStack)-1].srcORF = orf
				ca.undoStack[len(ca.undoStack)-1].dstORF = dstORF
			}
		}
		return nil
	})
}

func (ca *camApp) doEdit() {
	ca.act("edit", func(jpeg, orf string) error {
		dst, err := moveFile(jpeg, editDir)
		if err != nil {
			return err
		}
		entry := undoEntry{action: "edit", srcJPEG: jpeg, dstJPEG: dst}
		if orf != "" {
			dstORF, err2 := moveFile(orf, editDir) // keep raw for editing
			if err2 == nil {
				entry.srcORF = orf
				entry.dstORF = dstORF
			}
		}
		ca.undoStack = append(ca.undoStack, entry)
		return nil
	})
}

func (ca *camApp) doPost() {
	ca.act("post", func(jpeg, orf string) error {
		// copy to photos dir for site
		dst, err := copyFile(jpeg, photosDir)
		if err != nil {
			return fmt.Errorf("copy to photos: %w", err)
		}
		// archive copy
		_, _ = copyFile(jpeg, archiveDir)

		// trash the original JPEG from camera
		_, _ = moveFile(jpeg, trashDir)

		// trash the raw
		if orf != "" {
			_, _ = moveFile(orf, trashDir)
		}

		ca.undoStack = append(ca.undoStack, undoEntry{
			action:  "post",
			srcJPEG: jpeg,
			dstJPEG: dst,
		})
		ca.log("posted " + filepath.Base(jpeg) + " → run Deploy when ready")
		return nil
	})
}

func (ca *camApp) doRotate() {
	if len(ca.photos) == 0 {
		return
	}
	ca.rotStep = (ca.rotStep + 1) % 4
	ca.showCurrent()
}

func (ca *camApp) doUndo() {
	if len(ca.undoStack) == 0 {
		ca.log("nothing to undo")
		return
	}
	e := ca.undoStack[len(ca.undoStack)-1]
	ca.undoStack = ca.undoStack[:len(ca.undoStack)-1]

	// move files back (cross-device safe)
	if err := moveFileBack(e.dstJPEG, e.srcJPEG); err != nil {
		ca.log("undo failed: " + err.Error())
		return
	}
	if e.srcORF != "" && e.dstORF != "" {
		_ = moveFileBack(e.dstORF, e.srcORF)
	}
	// put it back into the list at current position
	ca.photos = append(ca.photos[:ca.idx], append([]string{e.srcJPEG}, ca.photos[ca.idx:]...)...)
	ca.rotStep = 0
	ca.log("undid " + e.action + " on " + filepath.Base(e.srcJPEG))
	ca.showCurrent()
}

func (ca *camApp) doDeploy() {
	ca.log("deploying…")

	// Run the script
	deployScript := filepath.Join(siteRoot, "deploy-simple.sh")

	go func() {
		cmd := exec.Command("bash", deployScript)
		cmd.Dir = siteRoot

		output, err := cmd.CombinedOutput()
		if err != nil {
			ca.log("deploy failed: " + lastLine(string(output)))
			return
		}
		ca.log("deployed ✓")
	}()
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// act is the common wrapper: get current jpeg+orf, run fn, advance
func (ca *camApp) act(name string, fn func(jpeg, orf string) error) {
	if len(ca.photos) == 0 {
		ca.log("no photos")
		return
	}
	jpeg := ca.photos[ca.idx]
	orf := orfFor(jpeg)

	if err := fn(jpeg, orf); err != nil {
		ca.log(name + " error: " + err.Error())
		return
	}

	// remove from list
	ca.photos = append(ca.photos[:ca.idx], ca.photos[ca.idx+1:]...)
	if ca.idx >= len(ca.photos) && ca.idx > 0 {
		ca.idx--
	}
	ca.rotStep = 0
	if len(ca.photos) == 0 {
		ca.log("all done!")
		ca.showCurrent()
		return
	}
	ca.log(name + "  " + filepath.Base(jpeg))
	ca.showCurrent()
}

func (ca *camApp) log(msg string) {
	ca.logLabel.SetText(msg)
}

// orfFor returns the .ORF sibling path if it exists, else ""
func orfFor(jpegPath string) string {
	base := strings.TrimSuffix(jpegPath, filepath.Ext(jpegPath))
	for _, ext := range []string{".ORF", ".orf"} {
		p := base + ext
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

// moveFile copies then removes src — safe across different filesystems
func moveFile(src, dstDir string) (string, error) {
	dst, err := copyFile(src, dstDir)
	if err != nil {
		return "", err
	}
	return dst, os.Remove(src)
}

// moveFileBack moves a file back to an exact destination path (for undo)
func moveFileBack(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	// try rename first (same filesystem), fall back to copy+delete
	if err := os.Rename(src, dst); err == nil {
		return nil
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	if _, err = io.Copy(out, in); err != nil {
		return err
	}
	return os.Remove(src)
}

func copyFile(src, dstDir string) (string, error) {
	dst := filepath.Join(dstDir, filepath.Base(src))
	if err := os.MkdirAll(dstDir, 0o755); err != nil {
		return "", err
	}
	in, err := os.Open(src)
	if err != nil {
		return "", err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return "", err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return dst, err
}

func loadJPEG(path string) (image.Image, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return jpeg.Decode(f)
}

func blankImage() image.Image {
	img := image.NewNRGBA(image.Rect(0, 0, 1, 1))
	img.Set(0, 0, colBg)
	return img
}

// rotateImage rotates 90° clockwise per step
func rotateImage(src image.Image, steps int) image.Image {
	for i := 0; i < steps; i++ {
		src = rotate90(src)
	}
	return src
}

func rotate90(src image.Image) image.Image {
	b := src.Bounds()
	w, h := b.Max.X-b.Min.X, b.Max.Y-b.Min.Y
	out := image.NewNRGBA(image.Rect(0, 0, h, w))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			out.Set(h-1-y, x, src.At(b.Min.X+x, b.Min.Y+y))
		}
	}
	return out
}

func lastLine(s string) string {
	s = strings.TrimRight(s, "\n")
	idx := strings.LastIndex(s, "\n")
	if idx < 0 {
		return s
	}
	return s[idx+1:]
}

// satisfy golang.org/x/image/draw import
var _ = draw.Over
