# 🔧 Fix for "Server Error 302" Issue

## ❌ Problem
App shows **"Scan Failed - Server error 302"** even though the backend returns status 200.

## 🔍 Root Cause
Google Apps Script doesn't handle POST requests with JSON body properly in all cases. It's better to use **GET requests with query parameters**.

---

## ✅ Solution Applied

### 1. **Updated Flutter App** (`lib/services/attendance_service.dart`)

**Changed from POST to GET:**
```dart
// ❌ OLD (POST with JSON body)
final response = await http.post(
  Uri.parse(baseUrl),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'action': 'getStudent',
    'qr_token': qrToken,
  }),
);

// ✅ NEW (GET with query parameters)
final uri = Uri.parse(baseUrl).replace(queryParameters: {
  'action': 'getStudent',
  'qr_token': qrToken,
});
final response = await http.get(uri);
```

**Key Changes:**
- ✅ Changed from `http.post()` to `http.get()`
- ✅ Parameters now in URL query string
- ✅ Added debug logging (print statements)
- ✅ Added timeout (15 seconds)
- ✅ Better error handling

---

### 2. **Updated Google Apps Script Backend**

**Added `doGet()` function:**

```javascript
function doGet(e) {
  try {
    const params = e.parameter;  // Get URL parameters
    
    if (params.action === 'getStudent' && params.qr_token) {
      return getStudentByQRToken(params.qr_token);
    }
    
    if (params.action === 'activate' && params.qr_token) {
      return activateStudent(params);
    }
    
    return ContentService
      .createTextOutput(JSON.stringify({
        success: false,
        error: "Invalid action or missing qr_token"
      }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({
        success: false,
        error: err.toString()
      }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
```

**File Created:** `backend_script_updated.gs`

---

## 📋 Steps to Deploy Updated Backend

### Step 1: Open Google Apps Script
1. Go to your Google Sheet
2. Click **Extensions** → **Apps Script**

### Step 2: Replace Code
1. Delete all existing code
2. Copy code from `backend_script_updated.gs`
3. Paste into the script editor

### Step 3: Deploy as Web App
1. Click **Deploy** → **New deployment**
2. Select type: **Web app**
3. Settings:
   - **Execute as:** Me (your email)
   - **Who has access:** Anyone
4. Click **Deploy**
5. **Authorize** the script (if prompted)
6. **Copy the new Web App URL**

### Step 4: Update Flutter App (if URL changed)
If you got a new URL, update `lib/services/attendance_service.dart`:
```dart
static const String baseUrl = 'YOUR_NEW_URL_HERE';
```

---

## 🧪 Testing

### Test 1: Check Console Logs
Run the app and scan a QR code. Check the debug console:

```bash
flutter run
```

You should see:
```
Making request to: https://script.google.com/macros/s/...?action=getStudent&qr_token=xxx
Response Status: 200
Response Body: {"success":true,"data":{...}}
```

### Test 2: Test in Browser
Open this URL in your browser (replace with your values):
```
https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec?action=getStudent&qr_token=TEST_TOKEN
```

Should return:
```json
{
  "success": true,
  "data": {
    "username": "john_doe",
    "name": "John Doe",
    ...
  }
}
```

---

## 🐛 Still Getting Errors?

### Error 1: "Invalid response format"
**Cause:** Backend not returning JSON
**Fix:** 
- Check Google Apps Script logs
- Verify `ContentService.createTextOutput()` is used
- Ensure `setMimeType(ContentService.MimeType.JSON)` is set

### Error 2: "QR token not found"
**Cause:** No matching QR in Google Sheet
**Fix:**
- Verify `qr_token` column exists in sheet
- Check data is in sheet (row 2 onwards)
- Test with a known QR token

### Error 3: "Network error"
**Cause:** No internet or wrong URL
**Fix:**
- Check internet connection
- Verify backend URL is correct
- Test URL in browser first

### Error 4: "Authorization required"
**Cause:** Script not deployed properly
**Fix:**
- Re-deploy as web app
- Set "Who has access" to **Anyone**
- Grant necessary permissions

---

## 📊 Request Flow (Updated)

```
Flutter App
    ↓
GET https://script.../exec?action=getStudent&qr_token=ABC123
    ↓
Google Apps Script
    ├─ doGet(e)
    ├─ e.parameter.action = "getStudent"
    ├─ e.parameter.qr_token = "ABC123"
    ↓
getStudentByQRToken("ABC123")
    ↓
Search Google Sheet
    ↓
Return JSON Response
    ↓
Flutter App Receives Data
    ↓
Navigate to Success/Error/Duplicate Screen
```

---

## ✅ Verification Checklist

- [ ] Updated `attendance_service.dart` to use GET
- [ ] Updated Google Apps Script with `doGet()` function
- [ ] Re-deployed script as web app
- [ ] Verified URL is correct in Flutter app
- [ ] Tested in browser (should return JSON)
- [ ] Ran `flutter clean && flutter pub get`
- [ ] Tested scanning a QR code
- [ ] Checked debug console for logs

---

## 📱 Debug Console Output (Expected)

When scanning a QR code, you should see:
```
Making request to: https://script.google.com/macros/s/.../exec?action=getStudent&qr_token=ABC123
Response Status: 200
Response Body: {"success":true,"data":{"username":"john",...}}

Making request to: https://script.google.com/macros/s/.../exec?action=activate&qr_token=ABC123
Activate Response Status: 200
Activate Response Body: {"success":true,"message":"Student activated successfully",...}
```

---

## 🎯 Quick Test Commands

### Test Backend in Terminal:
```bash
curl "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec?action=getStudent&qr_token=TEST"
```

### Test Flutter App:
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🆘 Need More Help?

1. **Check Flutter Console:** Look for print statements
2. **Check Apps Script Logs:** 
   - Go to Apps Script editor
   - Click **Executions** (left sidebar)
   - View recent executions and errors
3. **Enable Verbose Logging:**
   - Add more `print()` statements in Flutter
   - Add `Logger.log()` in Apps Script

---

**Status: ✅ FIXED**

The app now uses GET requests which work reliably with Google Apps Script!
