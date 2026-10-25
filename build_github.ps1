# Build GitHub Pages Ready Deployment
$ErrorActionPreference = "Stop"
$base = "c:\Users\dilshan\Desktop\MOB POS"
$ghPagesDir = "c:\Users\dilshan\Desktop\spice-pos-github"

# Helper to read UTF-8 files safely
function Read-Utf8File($path) {
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

# ============================================================
# STEP 1: Build standalone.html (everything embedded)
# ============================================================
Write-Output "Step 1: Building fully embedded standalone file..."

# 1. Read CSS
$leafletCss = Read-Utf8File "$base\css\leaflet.css"
$stylesCss  = Read-Utf8File "$base\css\styles.css"
$css = $leafletCss + "`n`n" + $stylesCss

# Icon as Base64
$iconBytes = [System.IO.File]::ReadAllBytes("$base\icons\icon.svg")
$iconB64 = [System.Convert]::ToBase64String($iconBytes)
$iconDataUri = "data:image/svg+xml;base64,$iconB64"

# Libraries
$tailwindJs = Read-Utf8File "$base\js\libs\tailwind.js"
$dexieJs    = Read-Utf8File "$base\js\libs\dexie.min.js"
$fbAppJs    = Read-Utf8File "$base\js\libs\firebase-app-compat.js"
$fbFsJs     = Read-Utf8File "$base\js\libs\firebase-firestore-compat.js"
$leafletJs  = Read-Utf8File "$base\js\libs\leaflet.js"
$qrcodeJs   = Read-Utf8File "$base\js\libs\qrcode.min.js"
$jsqrJs     = Read-Utf8File "$base\js\libs\jsqr.min.js"

# App JS files in exact dependency order
$jsFiles = @(
    "sounds.js",
    "db.js",
    "hierarchy.js",
    "auth.js",
    "companyControl.js",
    "state.js",
    "ui.js",
    "dashboard.js",
    "bestShops.js",
    "pos.js",
    "repbills.js",
    "collections.js",
    "gps.js",
    "map.js",
    "routeSession.js",
    "routes.js",
    "shops.js",
    "products.js",
    "production.js",
    "stores.js",
    "lorry.js",
    "print.js",
    "reports.js",
    "settings.js",
    "hr.js",
    "payroll.js",
    "users.js",
    "rep_onboard.js",
    "app.js"
)

$combinedAppJs = $leafletJs + "`n`n" + $qrcodeJs + "`n`n" + $jsqrJs + "`n`n"
foreach ($f in $jsFiles) {
    $content = Read-Utf8File "$base\js\$f"
    $combinedAppJs += "`n// --- $f ---`n" + $content
}

# Read index.html and embed everything
$html = Read-Utf8File "$base\index.html"

# Favicon & App Icons: Keep standard relative paths matching deployed root files
# (Chrome WebAPK requires clean HTTPS/relative URLs, not bloated data: URIs)

# CSS embed
$html = $html.Replace('<link rel="stylesheet" href="css/leaflet.css" />', "")
$html = $html.Replace('<link rel="stylesheet" href="css/styles.css" />', "<style>`n$css`n</style>")

# Tailwind, Dexie & Firebase embed
$html = $html.Replace('<script src="js/libs/tailwind.js"></script>', "<script>`n$tailwindJs`n</script>")
$html = $html.Replace('<script src="js/libs/dexie.min.js"></script>', "<script>`n$dexieJs`n</script>")
$html = $html.Replace('<script src="js/libs/firebase-app-compat.js"></script>', "<script>`n$fbAppJs`n</script>")
$html = $html.Replace('<script src="js/libs/firebase-firestore-compat.js"></script>', "<script>`n$fbFsJs`n</script>")

# App JS embed
$scriptsPattern = '(?s)<script src="js/libs/(?:leaflet\.js.*?|)qrcode\.min\.js"></script>.*?<script src="js/app\.js"></script>'
$embeddedAppScripts = "<script>`n$combinedAppJs`n</script>"
$html = [System.Text.RegularExpressions.Regex]::Replace($html, $scriptsPattern, $embeddedAppScripts)

Write-Output "  Standalone build complete ($(($html.Length / 1024).ToString('0.0')) KB)"

# ============================================================
# STEP 2: Create GitHub Pages deployment folder
# ============================================================
Write-Output "Step 2: Creating GitHub Pages deployment folder..."

if (-not (Test-Path $ghPagesDir)) {
    New-Item -ItemType Directory -Path $ghPagesDir | Out-Null
}

# Write index.html (the fully embedded standalone)
[System.IO.File]::WriteAllText("$ghPagesDir\index.html", $html, [System.Text.Encoding]::UTF8)
Write-Output "  Written: index.html ($([Math]::Round((Get-Item "$ghPagesDir\index.html").Length/1024))KB)"

# Copy manifest.json directly from base
Copy-Item "$base\manifest.json" "$ghPagesDir\manifest.json" -Force
Write-Output "  Written: manifest.json"

# Copy Service Worker directly from base
Copy-Item "$base\sw.js" "$ghPagesDir\sw.js" -Force
Write-Output "  Written: sw.js"

# Write .nojekyll (tells GitHub Pages not to ignore files starting with _)
[System.IO.File]::WriteAllText("$ghPagesDir\.nojekyll", "", [System.Text.Encoding]::UTF8)
Write-Output "  Written: .nojekyll"

# Copy icons BOTH to root ($ghPagesDir) AND to icons/ ($ghPagesDir\icons)
$iconDestDir = "$ghPagesDir\icons"
if (-not (Test-Path $iconDestDir)) { New-Item -ItemType Directory -Path $iconDestDir | Out-Null }
foreach ($file in (Get-ChildItem "$base\icons\*")) {
    try {
        Copy-Item $file.FullName "$ghPagesDir\$($file.Name)" -Force
        Copy-Item $file.FullName "$iconDestDir\$($file.Name)" -Force
    } catch {}
}
Write-Output "  Copied: icons/ and root icon files"

# Write README.md
$readme = @'
# 🌿 Spice & Wholesale Card POS

Offline-First Mobile POS for Spice Card & Sachet Wholesale Business.

## 🚀 GitHub Pages Setup Instructions
1. Open this repository on GitHub.
2. Go to **Settings** -> **Pages**.
3. Under **Branch**, select `main` (or `master`) and folder `/ (root)`.
4. Click **Save**.
5. Your live POS web app will be available at: `https://<your-username>.github.io/<repo-name>/`

## 📱 Mobile Installation (PWA)
- Open the GitHub Pages URL in Google Chrome (Android) or Safari (iOS).
- Tap **Menu (⋮)** or **Share**.
- Tap **"Add to Home screen"** / **"Install App"**.
'@
[System.IO.File]::WriteAllText("$ghPagesDir\README.md", $readme, [System.Text.Encoding]::UTF8)
Write-Output "  Written: README.md"

# Step 3: Ensure no zip files (per user request)
$zipWebPath = "c:\Users\dilshan\Desktop\spice-pos-web.zip"
if (Test-Path $zipWebPath) { Remove-Item -LiteralPath $zipWebPath -Force -ErrorAction SilentlyContinue }

Write-Output ""
Write-Output "============================================"
Write-Output "DONE! GitHub Pages folder ready at:"
Write-Output "  $ghPagesDir"
Write-Output ""
Write-Output "Files to upload to GitHub:"
Get-ChildItem $ghPagesDir -Force | ForEach-Object { Write-Output "  - $($_.Name)" }
Write-Output "============================================"
