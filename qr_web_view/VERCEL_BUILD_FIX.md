# Vercel Build Fix - Flutter Not Found

## Problem
```
sh: line 1: flutter: command not found
Error: Command "flutter pub get && flutter build web --release" exited with 127
```

This means Flutter is not installed in Vercel's build environment.

## Solution

I've updated your configuration to automatically install Flutter during the build.

### Files Updated:
1. ✅ `vercel.json` - Now uses `bash build.sh` instead of direct flutter command
2. ✅ `build.sh` - Automatically installs Flutter if not found

## Vercel Dashboard Settings

### Option 1: Use vercel.json (Recommended)
The `vercel.json` file now has:
```json
{
  "buildCommand": "bash build.sh",
  "outputDirectory": "build/web"
}
```

**In Vercel Dashboard:**
1. Go to your project → Settings → General
2. **Root Directory**: `qr_web_view` ✅
3. Go to Settings → Build & Development Settings
4. **Framework Preset**: Other
5. **Build Command**: Leave empty (uses vercel.json) OR set to `bash build.sh`
6. **Output Directory**: `build/web`
7. **Install Command**: Leave empty

### Option 2: Set in Dashboard (Alternative)
If vercel.json doesn't work, set these in Vercel Dashboard:

**Build Command:**
```bash
bash build.sh
```

**Output Directory:**
```
build/web
```

**Root Directory:**
```
qr_web_view
```

## How build.sh Works

The script:
1. Checks if Flutter is installed
2. If not, clones Flutter stable branch
3. Adds Flutter to PATH
4. Runs `flutter pub get`
5. Builds the web app with `flutter build web --release`

## Build Time

⚠️ **Note**: Installing Flutter during build adds ~2-3 minutes to build time. This is normal for the first build.

## Troubleshooting

### Build Still Fails?

1. **Check build logs** in Vercel Dashboard
   - Look for "Flutter not found, installing..."
   - Verify Flutter installation succeeded

2. **Verify Root Directory**
   - Must be set to `qr_web_view` in Vercel settings
   - This ensures `build.sh` is found

3. **Check File Permissions**
   - `build.sh` should be executable (chmod +x)
   - Already set in the file

4. **Alternative: Use Install Command**
   If build.sh doesn't work, try setting in Vercel Dashboard:
   
   **Install Command:**
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter && export PATH="$PATH:$HOME/flutter/bin" && flutter precache --web
   ```
   
   **Build Command:**
   ```bash
   export PATH="$PATH:$HOME/flutter/bin" && flutter pub get && flutter build web --release
   ```

### Faster Builds (Optional)

If builds are too slow, you can:
1. Use Vercel's build cache (automatic)
2. Consider using a custom Docker image with Flutter pre-installed
3. Use a CI/CD service that supports Flutter better

## Next Steps

1. ✅ Commit and push the updated files:
   ```bash
   git add qr_web_view/vercel.json qr_web_view/build.sh
   git commit -m "Fix Vercel build: Add Flutter installation script"
   git push
   ```

2. ✅ Vercel will auto-deploy (if connected to Git)

3. ✅ Check the deployment logs to verify Flutter installation

4. ✅ Once build succeeds, test your routes:
   - `https://your-domain.vercel.app/`
   - `https://your-domain.vercel.app/stats`

## Expected Build Output

You should see in the logs:
```
🚀 Starting Flutter web build...
📦 Flutter not found, installing...
✅ Flutter installed
Flutter 3.x.x • channel stable
📥 Getting Flutter dependencies...
🔨 Building web app...
✅ Build complete! Output in build/web/
```

