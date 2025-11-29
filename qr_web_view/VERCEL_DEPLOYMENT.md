# Vercel Deployment Guide

## Configuration

The app is configured for Vercel deployment with proper routing and cache control.

### Files Created:
- `vercel.json` - Vercel configuration with routing and cache headers
- `.vercelignore` - Files to ignore during deployment

## Cache Issues & Updates

### Why the app might not update:

1. **Service Worker Caching**: Flutter web apps use service workers that cache aggressively
2. **Browser Caching**: Your browser may cache the old version
3. **Vercel CDN Caching**: Vercel's CDN may serve cached files

### Solutions:

#### 1. Force a new deployment
```bash
# Make a small change (like updating version in pubspec.yaml)
# Then commit and push
git add .
git commit -m "Force update"
git push
```

#### 2. Clear browser cache
- **Chrome/Edge**: Press `Ctrl+Shift+Delete` (Windows) or `Cmd+Shift+Delete` (Mac)
- Select "Cached images and files"
- Or use Incognito/Private mode to test

#### 3. Unregister Service Worker
Open browser console and run:
```javascript
navigator.serviceWorker.getRegistrations().then(function(registrations) {
  for(let registration of registrations) {
    registration.unregister();
  }
});
// Then hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
```

#### 4. Hard Refresh
- **Windows**: `Ctrl + Shift + R` or `Ctrl + F5`
- **Mac**: `Cmd + Shift + R`

#### 5. Clear Vercel Cache
In Vercel dashboard:
1. Go to your project
2. Settings → Build & Development Settings
3. Clear build cache (if available)
4. Redeploy

## Build Command

The build command is set to:
```bash
flutter build web --release
```

Make sure Flutter is installed on your build environment or use Vercel's build settings to install Flutter.

## Routes

All routes are configured to serve `index.html` for client-side routing:
- `/` - Main page
- `/stats` - Stats page
- Any other route will also serve the app

## Cache Headers

Critical files have `no-cache` headers:
- `index.html`
- `main.dart.js`
- `flutter.js`
- `flutter_service_worker.js`
- `flutter_bootstrap.js`
- `version.json`
- `manifest.json`

Static assets (images, fonts, etc.) are cached for 1 year for performance.

## Troubleshooting

### App still not updating?

1. Check Vercel deployment logs to ensure build succeeded
2. Verify the build output contains new files
3. Check browser console for service worker errors
4. Try accessing the site in an incognito window
5. Check the `version.json` file - it should update on each build

### Build fails?

1. Ensure Flutter is installed: `flutter --version`
2. Check `pubspec.yaml` for dependency issues
3. Run `flutter pub get` locally to verify dependencies
4. Check Vercel build logs for specific errors

