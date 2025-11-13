// ====================================================================
// UPDATED GOOGLE APPS SCRIPT - SUPPORTS BOTH GET AND POST
// ====================================================================

/**
 * Handle GET requests (for URL parameters)
 */
function doGet(e) {
  try {
    const params = e.parameter;

    if (!params.action) {
      throw new Error("Missing 'action' in request");
    }

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

/**
 * Handle POST requests (for JSON body)
 */
function doPost(e) {
  try {
    const params = JSON.parse(e.postData.contents);

    if (!params.action) {
      throw new Error("Missing 'action' in request");
    }

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

/**
 * ✅ FUNCTION 1: Get Student by QR Token
 * Returns student data if found, otherwise returns an error.
 */
function getStudentByQRToken(qrToken) {
  try {
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    const data = sheet.getDataRange().getValues();
    
    if (data.length <= 1) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        error: "No data in sheet"
      })).setMimeType(ContentService.MimeType.JSON);
    }

    const headers = data[0];
    const qrTokenCol = headers.indexOf('qr_token');
    const usernameCol = headers.indexOf('Username');
    const nameCol = headers.indexOf('Name');
    const batchCol = headers.indexOf('Batch');
    const mentorCol = headers.indexOf('Mentor Name');
    const stsCol = headers.indexOf('sts');
    const inTimeCol = headers.indexOf('in_time');
    const lastScanCol = headers.indexOf('last_scan');

    // Check if all required columns exist
    if (qrTokenCol === -1) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        error: "Column 'qr_token' not found in sheet"
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // Search for student by QR token (start from row 2, index 1)
    for (let i = 1; i < data.length; i++) {
      const rowQR = data[i][qrTokenCol];
      
      if (rowQR && rowQR.toString().trim() === qrToken.toString().trim()) {
        const student = {
          username: usernameCol !== -1 ? (data[i][usernameCol] || '') : '',
          name: nameCol !== -1 ? (data[i][nameCol] || '') : '',
          batch: batchCol !== -1 ? (data[i][batchCol] || '') : '',
          mentor: mentorCol !== -1 ? (data[i][mentorCol] || '') : '',
          sts: stsCol !== -1 ? (data[i][stsCol] || '') : '',
          in_time: inTimeCol !== -1 ? (data[i][inTimeCol] || '') : '',
          last_scan: lastScanCol !== -1 ? (data[i][lastScanCol] || '') : '',
          qr_token: qrToken
        };
        
        return ContentService.createTextOutput(JSON.stringify({
          success: true,
          data: student  // Return object, not array
        })).setMimeType(ContentService.MimeType.JSON);
      }
    }

    // QR token not found
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      error: "QR token not found"
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      error: "Error: " + error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * ✅ FUNCTION 2: Activate Student
 * Updates student row with sts='active', in_time, and last_scan.
 */
function activateStudent(params) {
  try {
    const qrToken = params.qr_token;
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    const data = sheet.getDataRange().getValues();
    
    if (data.length <= 1) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        error: "No data in sheet"
      })).setMimeType(ContentService.MimeType.JSON);
    }

    const headers = data[0];
    const qrTokenCol = headers.indexOf('qr_token');
    const stsCol = headers.indexOf('sts');
    const inTimeCol = headers.indexOf('in_time');
    const lastScanCol = headers.indexOf('last_scan');
    const usernameCol = headers.indexOf('Username');
    const nameCol = headers.indexOf('Name');
    const batchCol = headers.indexOf('Batch');
    const mentorCol = headers.indexOf('Mentor Name');

    // Check if required columns exist
    if (qrTokenCol === -1) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        error: "Column 'qr_token' not found"
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // Search for student and update (start from row 2, index 1)
    for (let i = 1; i < data.length; i++) {
      const rowQR = data[i][qrTokenCol];
      
      if (rowQR && rowQR.toString().trim() === qrToken.toString().trim()) {
        const now = new Date();
        const formattedTime = Utilities.formatDate(now, Session.getScriptTimeZone(), "HH:mm:ss");
        const formattedTimestamp = Utilities.formatDate(now, Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss");
        
        // Update Google Sheet (row is i+1 because sheet rows are 1-indexed, but we skip header)
        const rowIndex = i + 1;
        if (stsCol !== -1) sheet.getRange(rowIndex, stsCol + 1).setValue('active');
        if (inTimeCol !== -1) sheet.getRange(rowIndex, inTimeCol + 1).setValue(formattedTime);
        if (lastScanCol !== -1) sheet.getRange(rowIndex, lastScanCol + 1).setValue(formattedTimestamp);

        const result = {
          username: usernameCol !== -1 ? (data[i][usernameCol] || '') : '',
          name: nameCol !== -1 ? (data[i][nameCol] || '') : '',
          batch: batchCol !== -1 ? (data[i][batchCol] || '') : '',
          mentor: mentorCol !== -1 ? (data[i][mentorCol] || '') : '',
          sts: 'active',
          in_time: formattedTime,
          last_scan: formattedTimestamp,
          qr_token: qrToken
        };

        return ContentService.createTextOutput(JSON.stringify({
          success: true,
          message: "Student activated successfully",
          data: result  // Return object, not array
        })).setMimeType(ContentService.MimeType.JSON);
      }
    }

    // QR token not found
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      error: "QR token not found"
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      error: "Error: " + error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
