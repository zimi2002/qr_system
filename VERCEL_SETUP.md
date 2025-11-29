# Vercel Deployment Setup Guide

## Project Structure

Your Flutter web app is in the `qr_web_view` subdirectory. Vercel needs to be configured correctly to build and deploy it.

## Vercel Dashboard Settings

### 1. Root Directory
In Vercel Dashboard → Settings → General:
- **Root Directory**: Set to `qr_web_view` ✅
- This tells Vercel where your project is located

### 2. Build & Development Settings

**Framework Preset**: Other (or leave blank)

**Build Command** (Option 1 - If Flutter is pre-installed):
```bash
flutter pub get && flutter build web --release
```

**Build Command** (Option 2 - Auto-install Flutter):
```bash
bash build.sh
```

**Output Directory**:
```
build/web
```

**Install Command**: Leave empty (or use build.sh which handles it)

## Alternative: Using vercel.json

If you've set the root directory to `qr_web_view` in Vercel settings, the `vercel.json` file in that directory should work with:

```json
{
  "buildCommand": "flutter pub get && flutter build web --release",
  "outputDirectory": "build/web",
  ...
}
```

## If Root Directory is Set to Repository Root

If Vercel's root directory is set to the repository root (not `qr_web_view`), then you need:

**Build Command**:
```bash
cd qr_web_view && flutter pub get && flutter build web --release
```

**Output Directory**:
```
qr_web_view/build/web
```

## Flutter Installation on Vercel

Vercel doesn't have Flutter installed by default. You have a few options:

### Option 1: Use a Custom Build Image (Recommended)

Create a `Dockerfile` or use Vercel's build settings to install Flutter.

### Option 2: Install Flutter in Build Command

Add Flutter installation to your build command:

```bash
# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor
cd qr_web_view
flutter pub get
flutter build web --release
```

### Option 3: Use a Build Script

Create a `build.sh` script:

```bash
#!/bin/bash
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# Build
cd qr_web_view
flutter pub get
flutter build web --release
```

Then set build command to: `bash build.sh`

## Troubleshooting

### Build Fails: "flutter: command not found"
- Flutter is not installed in the build environment
- Use one of the Flutter installation methods above

### Routes Not Working (/stats returns 404)
- Check that `vercel.json` has the rewrites configuration
- Ensure the rewrites section is correct:
```json
"rewrites": [
  {
    "source": "/(.*)",
    "destination": "/index.html"
  }
]
```

### Build Succeeds but App Doesn't Load
1. Check the output directory is correct
2. Verify `index.html` exists in the output directory
3. Check browser console for errors
4. Check Vercel deployment logs

### Check Deployment Logs
1. Go to Vercel Dashboard → Your Project → Deployments
2. Click on a deployment
3. Check the "Build Logs" tab for errors

## Recommended Setup

1. **Root Directory**: `qr_web_view` (in Vercel settings) ✅
2. **Build Command**: `bash build.sh` (handles Flutter installation automatically)
   - OR: `flutter pub get && flutter build web --release` (if Flutter is pre-installed)
3. **Output Directory**: `build/web`
4. **Framework**: Other

This way, Vercel treats `qr_web_view` as the project root, and the `vercel.json` in that directory will work correctly.

## Quick Fix for Current Issue

If your build passes but routes don't work:

1. **Check vercel.json exists** in `qr_web_view/` directory ✅
2. **Verify rewrites are configured** (they are in vercel.json) ✅
3. **Clear browser cache** or test in incognito mode
4. **Check deployment logs** to ensure files were deployed correctly
5. **Verify index.html exists** in the build output

If routes still don't work after deployment:
- The `vercel.json` rewrites should handle it
- Try accessing: `https://your-domain.vercel.app/stats`
- Check browser console for errors
- Verify the deployment actually includes the `vercel.json` file
