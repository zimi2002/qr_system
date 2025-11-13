# 🚀 Complete Setup Guide - QR Attendance Scanner

## 🎯 Issue Summary
**Current Error:** `{"success":true,"count":0,"data":[]}`
**Meaning:** Backend is working, but no student found in Google Sheet

---

## ✅ SOLUTION: 3-Step Setup

### 📋 Step 1: Setup Google Sheet

#### 1.1 Create/Open Your Google Sheet
- Make sure you have a Google Sheet ready

#### 1.2 Run Initial Setup
1. In your Google Sheet, click **Extensions** → **Apps Script**
2. Paste the backend code you provided
3. Click **Save** (💾)
4. **Close** the Apps Script tab
5. Go back to your Google Sheet
6. **Refresh** the page (F5)
7. You should see a new menu: **🔗 QR Tools**

#### 1.3 Setup Column Headers
1. Click **🔗 QR Tools** → **0️⃣ Setup Column Headers**
2. Click **Yes** when prompted
3. This creates the correct column structure:

| Username | Name | Batch | Mentor Name | qr_token | url | sts | in_time | last_scan |
|----------|------|-------|-------------|----------|-----|-----|---------|-----------|

#### 1.4 Add Student Data
Add student data starting from **Row 2**:

**Example:**
| Username | Name      | Batch   | Mentor Name | qr_token | url | sts | in_time | last_scan |
|----------|-----------|---------|-------------|----------|-----|-----|---------|-----------|
| john_doe | John Doe  | Batch A | Mr. Smith   |          |     |     |         |           |
| jane_doe | Jane Doe  | Batch B | Ms. Jones   |          |     |     |         |           |

**Important:** Leave `qr_token`, `url`, `sts`, `in_time`, and `last_scan` columns **EMPTY** for now!

#### 1.5 Generate QR Tokens
1. Click **🔗 QR Tools** → **2️⃣ Generate QR Tokens & URLs**
2. Wait for completion message
3. Now your sheet should look like:

| Username | Name      | Batch   | Mentor Name | qr_token              | url                    | sts      | in_time | last_scan |
|----------|-----------|---------|-------------|-----------------------|------------------------|----------|---------|-----------|
| john_doe | John Doe  | Batch A | Mr. Smith   | johndoe-BA-ABC12345  | https://script...     | inactive |         |           |

---

### 🔧 Step 2: Update Apps Script Backend

#### 2.1 Update Deployment URL in generateURL function

**IMPORTANT:** In the Apps Script code, find this function:
```javascript
function generateURL(qrToken) {
  const baseUrl = "https://script.google.com/macros/s/REPLACE_WITH_YOUR_DEPLOYMENT_ID/exec";
  return `${baseUrl}?action=getStudent&qr_token=${qrToken}`;
}
```

**Replace** `REPLACE_WITH_YOUR_DEPLOYMENT_ID` with your actual deployment ID from:
```
https://script.google.com/macros/s/AKfycby2dINhlZviIwcxOIWdvtnBPnhHWaeZ2B1JLxfKcS-7gZEhb_WR1r-hdRqMC26-fXDuDw/exec
```

So it becomes:
```javascript
function generateURL(qrToken) {
  const baseUrl = "https://script.google.com/macros/s/AKfycby2dINhlZviIwcxOIWdvtnBPnhHWaeZ2B1JLxfKcS-7gZEhb_WR1r-hdRqMC26-fXDuDw/exec";
  return `${baseUrl}?action=getStudent&qr_token=${qrToken}`;
}
```

#### 2.2 Re-generate URLs (after fixing generateURL)
1. Click **🔗 QR Tools** → **⚠️ Regenerate ALL Tokens**
2. Click **Yes**
3. This updates all URLs with correct deployment ID

#### 2.3 Deploy the Script
1. In Apps Script editor, click **Deploy** → **New deployment**
2. Type: **Web app**
3. Settings:
   - **Execute as:** Me
   - **Who has access:** Anyone
4. Click **Deploy**
5. **Copy the deployment URL** (should match what's in Flutter app)

---

### 📱 Step 3: Test the System

#### 3.1 Test Backend in Browser
Copy a QR token from your sheet (e.g., `johndoe-BA-ABC12345`)

Open this URL in browser:
```
https://script.google.com/macros/s/AKfycby2dINhlZviIwcxOIWdvtnBPnhHWaeZ2B1JLxfKcS-7gZEhb_WR1r-hdRqMC26-fXDuDw/exec?action=getStudent&qr_token=johndoe-BA-ABC12345
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "username": "john_doe",
    "name": "John Doe",
    "batch": "Batch A",
    "mentor": "Mr. Smith",
    "sts": "inactive",
    "in_time": "",
    "last_scan": "",
    "qr_token": "johndoe-BA-ABC12345"
  }
}
```

**If you get:**
```json
{"success": false, "error": "QR token not found"}
```
→ QR token doesn't match. Copy exact token from sheet.

#### 3.2 Generate QR Codes for Testing
1. Go to https://www.qr-code-generator.com/
2. Select **Text** type
3. Paste your QR token (e.g., `johndoe-BA-ABC12345`)
4. Download/print the QR code
5. Or use the **URL** from the sheet's `url` column

#### 3.3 Test Flutter App
```bash
flutter run
```

1. Scan the QR code you generated
2. Check console output:
```
Making request to: ...?action=getStudent&qr_token=johndoe-BA-ABC12345
Response Status: 200
Response Body: {"success":true,"data":{...}}
```

3. Should navigate to **Success Screen** ✅

---

## 🐛 Troubleshooting

### Issue 1: Still Getting Empty Data
**Response:** `{"success":true,"count":0,"data":[]}`

**Causes:**
1. ❌ Different version of backend is deployed
2. ❌ QR token scanned doesn't exist in sheet
3. ❌ Column name is not exactly `qr_token`

**Solutions:**
- Re-deploy the backend as **New version**
- Verify QR token exists in sheet
- Check column name spelling (case-sensitive)

### Issue 2: "QR token not found"
**Cause:** The scanned QR code value doesn't match any value in the `qr_token` column

**Solutions:**
1. Copy exact token from sheet
2. Generate QR code with that exact text
3. Test scanning
4. Check console logs for what was scanned

### Issue 3: Response has "count" field
**Response:** `{"success":true,"count":0,"data":[]}`

**Cause:** Old version of backend is still deployed

**Solution:**
1. Go to Apps Script
2. Click **Deploy** → **Manage deployments**
3. Click ✏️ (Edit)
4. Select **New version**
5. Click **Deploy**

---

## 📊 Expected Data Flow

### First Scan (Success Flow):
```
1. User scans QR: johndoe-BA-ABC12345
2. Flutter sends: GET ?action=getStudent&qr_token=johndoe-BA-ABC12345
3. Backend searches sheet
4. Backend finds: john_doe in row 2
5. Backend returns: {"success":true,"data":{...,"sts":"inactive","last_scan":""}}
6. Flutter checks: last_scan is empty ✅
7. Flutter sends: GET ?action=activate&qr_token=johndoe-BA-ABC12345
8. Backend updates sheet:
   - sts = "active"
   - in_time = "09:30:45"
   - last_scan = "2025-10-24 09:30:45"
9. Flutter shows: Success Screen with student details
```

### Second Scan (Duplicate Flow):
```
1. User scans same QR: johndoe-BA-ABC12345
2. Flutter sends: GET ?action=getStudent&qr_token=johndoe-BA-ABC12345
3. Backend returns: {"success":true,"data":{...,"last_scan":"2025-10-24 09:30:45"}}
4. Flutter checks: last_scan is NOT empty ⚠️
5. Flutter shows: Duplicate Screen with previous scan time
```

### Unknown QR (Error Flow):
```
1. User scans unknown QR: INVALID123
2. Flutter sends: GET ?action=getStudent&qr_token=INVALID123
3. Backend searches sheet
4. Backend finds: nothing
5. Backend returns: {"success":false,"error":"QR token not found"}
6. Flutter shows: Error Screen
```

---

## ✅ Final Checklist

Before testing, verify:

- [ ] Google Sheet has correct column headers (use **🔗 QR Tools** menu)
- [ ] Student data added starting from Row 2
- [ ] QR tokens generated (use **2️⃣ Generate QR Tokens & URLs**)
- [ ] generateURL function has correct deployment ID
- [ ] Backend deployed as **Web app** with **Anyone** access
- [ ] Flutter app has correct backend URL in `attendance_service.dart`
- [ ] Generated QR codes with actual tokens from sheet
- [ ] Tested backend in browser first
- [ ] Ran `flutter run`

---

## 🎓 Understanding the Response

### ✅ Good Response:
```json
{
  "success": true,
  "data": {
    "username": "john_doe",
    "name": "John Doe",
    "batch": "Batch A",
    "mentor": "Mr. Smith",
    "sts": "inactive",
    "in_time": "",
    "last_scan": "",
    "qr_token": "johndoe-BA-ABC12345"
  }
}
```
→ Student found! Will proceed to activation or duplicate check.

### ❌ Not Found:
```json
{
  "success": false,
  "error": "QR token not found"
}
```
→ QR token doesn't exist in sheet. Check spelling/token value.

### ⚠️ Empty Data (Old backend):
```json
{
  "success": true,
  "count": 0,
  "data": []
}
```
→ Old backend version. Re-deploy new version.

---

**Status: Ready to Setup! Follow the 3 steps above.** 🚀
