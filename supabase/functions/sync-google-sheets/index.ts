import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GoogleSheetRow {
  Username?: string;
  Name?: string;
  Batch?: string;
  'Mentor Name'?: string;
  qr_token?: string;
  sts?: string;
  in_time?: string;
  last_scan?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get Google Sheet URL from request
    const { sheetUrl, sheetId, range } = await req.json().catch(() => ({}))
    
    if (!sheetUrl && !sheetId) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing sheetUrl or sheetId parameter' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Extract sheet ID from URL if provided
    let finalSheetId = sheetId
    if (sheetUrl) {
      const match = sheetUrl.match(/\/spreadsheets\/d\/([a-zA-Z0-9-_]+)/)
      if (match) {
        finalSheetId = match[1]
      } else {
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: 'Invalid Google Sheet URL format' 
          }),
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }
    }

    // Fetch data from Google Sheets (public sheet)
    // Try using Google Sheets API first, fallback to CSV export for public sheets
    const sheetRange = range || 'A1:Z1000' // Default range
    const apiKey = Deno.env.get('GOOGLE_SHEETS_API_KEY')
    
    let sheetsResponse: Response
    let sheetsData: any
    
    if (apiKey) {
      // Use Google Sheets API v4 (more reliable, requires API key)
      const sheetsApiUrl = `https://sheets.googleapis.com/v4/spreadsheets/${finalSheetId}/values/${sheetRange}?key=${apiKey}`
      sheetsResponse = await fetch(sheetsApiUrl)
      
      if (!sheetsResponse.ok) {
        const errorText = await sheetsResponse.text()
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: `Failed to fetch Google Sheet via API: ${errorText}` 
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }
      
      sheetsData = await sheetsResponse.json()
    } else {
      // Fallback: Use CSV export URL (works for public sheets without API key)
      // Convert range to gid if needed, or use default sheet (gid=0)
      const csvUrl = `https://docs.google.com/spreadsheets/d/${finalSheetId}/export?format=csv&gid=0`
      sheetsResponse = await fetch(csvUrl)
      
      if (!sheetsResponse.ok) {
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: `Failed to fetch Google Sheet via CSV export. Make sure the sheet is public or provide GOOGLE_SHEETS_API_KEY.` 
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }
      
      // Parse CSV to array of arrays
      const csvText = await sheetsResponse.text()
      const lines = csvText.split('\n').filter(line => line.trim())
      sheetsData = {
        values: lines.map(line => {
          // Simple CSV parsing (handles quoted fields)
          const values: string[] = []
          let current = ''
          let inQuotes = false
          
          for (let i = 0; i < line.length; i++) {
            const char = line[i]
            if (char === '"') {
              inQuotes = !inQuotes
            } else if (char === ',' && !inQuotes) {
              values.push(current.trim())
              current = ''
            } else {
              current += char
            }
          }
          values.push(current.trim())
          return values
        })
      }
    }
    const rows = sheetsData.values || []

    if (rows.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'No data found in Google Sheet' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Parse headers (first row)
    const headers = rows[0].map((h: string) => h.trim())
    const usernameCol = headers.indexOf('Username')
    const nameCol = headers.indexOf('Name')
    const batchCol = headers.indexOf('Batch')
    const mentorCol = headers.indexOf('Mentor Name')
    const qrTokenCol = headers.indexOf('qr_token')
    const stsCol = headers.indexOf('sts')
    const inTimeCol = headers.indexOf('in_time')
    const lastScanCol = headers.indexOf('last_scan')

    if (qrTokenCol === -1) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'qr_token column not found in Google Sheet' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Helper function to fix malformed rows where all data is in one column
    const fixMalformedRow = (row: string[], expectedColumnCount: number): string[] => {
      // If row has only 1-2 columns but first column has many comma-separated values, try to split it
      if (row.length <= 2 && row[0] && row[0].includes(',')) {
        const firstCol = row[0]
        // Count commas - if it has many, likely malformed
        const commaCount = (firstCol.match(/,/g) || []).length
        if (commaCount >= 5) {
          // Try to split by comma and create a proper row
          const parts = firstCol.split(',').map(p => p.trim())
          // Try to map parts to expected columns
          // Expected order: Username, Name, Phone Number, Batch, Mentor Name, qr_token, url, sts, in_time, last_scan
          if (parts.length >= 6) {
            const fixedRow: string[] = new Array(expectedColumnCount).fill('')
            // Map known parts
            if (parts[0]) fixedRow[usernameCol] = parts[0]
            if (parts[1]) fixedRow[nameCol] = parts[1]
            if (parts[3]) fixedRow[batchCol] = parts[3]
            if (parts[4]) fixedRow[mentorCol] = parts[4]
            if (parts[5]) fixedRow[qrTokenCol] = parts[5]
            if (parts.length > 7 && parts[7]) fixedRow[stsCol] = parts[7]
            return fixedRow
          }
        }
      }
      return row
    }

    // Process rows in batches for better performance
    const batchSize = 50 // Process 50 rows at a time
    let skipped = 0
    let errors = 0
    const studentDataArray: any[] = []
    
    // Track skip reasons for debugging
    const skipReasons: { [key: string]: number } = {
      empty_row: 0,
      empty_qr_token: 0,
      existing_in_db: 0,
      duplicate_in_sheet: 0,
      missing_required_fields: 0
    }
    
    // Track detailed information about skipped rows (limit to 100 to avoid huge responses)
    const skippedRows: any[] = []
    const MAX_SKIPPED_ROWS_DETAILS = 100

    // First, get existing qr_tokens to filter out existing records
    const { data: existingStudents } = await supabaseClient
      .from('students')
      .select('qr_token')
    
    const existingTokens = new Set(
      (existingStudents || []).map((s: any) => s.qr_token)
    )

    // Track qr_tokens within this sync to avoid duplicates in the sheet itself
    const seenTokensInSheet = new Set<string>()
    
    // Prepare all student data (only new records)
    const expectedColumnCount = headers.length
    for (let i = 1; i < rows.length; i++) {
      let row = rows[i]
      const rowNumber = i + 1 // Excel row number (1-indexed, accounting for header)
      
      // Try to fix malformed rows where all data is in one column
      if (row && row.length > 0) {
        const fixedRow = fixMalformedRow(row, expectedColumnCount)
        // If fixMalformedRow returned a different array (not the same reference), use it
        if (fixedRow !== row && fixedRow.length >= expectedColumnCount) {
          row = fixedRow
        }
      }
      
      // Helper function to capture skipped row details
      const addSkippedRow = (reason: string, data?: any) => {
        skipped++
        skipReasons[reason as keyof typeof skipReasons]++
        if (skippedRows.length < MAX_SKIPPED_ROWS_DETAILS) {
          skippedRows.push({
            row_number: rowNumber,
            reason,
            username: usernameCol !== -1 ? (row[usernameCol] || '').toString().trim() : null,
            name: nameCol !== -1 ? (row[nameCol] || '').toString().trim() : null,
            qr_token: qrTokenCol !== -1 ? (row[qrTokenCol] || '').toString().trim() : null,
            batch: batchCol !== -1 ? (row[batchCol] || '').toString().trim() : null,
            ...data
          })
        }
      }
      
      // Skip empty rows - but check if first column has data that might be malformed
      if (!row || row.length === 0) {
        addSkippedRow('empty_row')
        continue
      }
      
      // Check if qr_token column is empty, but first column might have the data
      let qrToken = row[qrTokenCol]?.toString().trim()
      if (!qrToken && row[0]) {
        // Try to extract qr_token from first column if it contains comma-separated data
        const firstCol = row[0].toString()
        if (firstCol.includes(',')) {
          const parts = firstCol.split(',').map(p => p.trim())
          // qr_token is typically in position 5 (index 5) based on the pattern: Username, Name, Phone, Batch, Mentor, qr_token, url, sts, ...
          if (parts.length > 5 && parts[5]) {
            qrToken = parts[5]
            // Also try to populate other fields from this collapsed data
            // Ensure row array has enough elements
            while (row.length < expectedColumnCount) {
              row.push('')
            }
            if (usernameCol !== -1 && (!row[usernameCol] || !row[usernameCol].trim()) && parts[0]) {
              row[usernameCol] = parts[0]
            }
            if (nameCol !== -1 && (!row[nameCol] || !row[nameCol].trim()) && parts[1]) {
              row[nameCol] = parts[1]
            }
            if (batchCol !== -1 && (!row[batchCol] || !row[batchCol].trim()) && parts[3]) {
              row[batchCol] = parts[3]
            }
            if (mentorCol !== -1 && (!row[mentorCol] || !row[mentorCol].trim()) && parts[4]) {
              row[mentorCol] = parts[4]
            }
            if (stsCol !== -1 && (!row[stsCol] || !row[stsCol].trim()) && parts.length > 7 && parts[7]) {
              row[stsCol] = parts[7]
            }
          }
        }
      }
      
      if (!qrToken) {
        addSkippedRow('empty_qr_token')
        continue
      }

      // Skip if this qr_token already exists in the database
      if (existingTokens.has(qrToken)) {
        addSkippedRow('existing_in_db')
        continue
      }

      // Skip if this qr_token was already seen in this sheet (duplicate within sheet)
      if (seenTokensInSheet.has(qrToken)) {
        addSkippedRow('duplicate_in_sheet')
        continue
      }
      
      seenTokensInSheet.add(qrToken)

      // Parse timestamps
      let inTime: string | null = null
      let lastScan: string | null = null
      
      if (inTimeCol !== -1 && row[inTimeCol]) {
        try {
          const dateValue = row[inTimeCol]
          if (typeof dateValue === 'string' && dateValue.includes('/')) {
            // Handle Google Sheets date format (MM/DD/YYYY HH:MM:SS)
            const parts = dateValue.split(' ')
            if (parts.length === 2) {
              const datePart = parts[0].split('/')
              const timePart = parts[1].split(':')
              if (datePart.length === 3 && timePart.length >= 2) {
                const year = parseInt(datePart[2])
                const month = parseInt(datePart[0]) - 1
                const day = parseInt(datePart[1])
                const hour = parseInt(timePart[0])
                const minute = parseInt(timePart[1])
                const second = timePart[2] ? parseInt(timePart[2]) : 0
                inTime = new Date(year, month, day, hour, minute, second).toISOString()
              }
            }
          } else {
            inTime = new Date(dateValue).toISOString()
          }
        } catch (e) {
          // Try to parse as time string
          inTime = row[inTimeCol]?.toString() || null
        }
      }
      
      if (lastScanCol !== -1 && row[lastScanCol]) {
        try {
          const dateValue = row[lastScanCol]
          if (typeof dateValue === 'string' && dateValue.includes('/')) {
            // Handle Google Sheets date format (MM/DD/YYYY HH:MM:SS)
            const parts = dateValue.split(' ')
            if (parts.length === 2) {
              const datePart = parts[0].split('/')
              const timePart = parts[1].split(':')
              if (datePart.length === 3 && timePart.length >= 2) {
                const year = parseInt(datePart[2])
                const month = parseInt(datePart[0]) - 1
                const day = parseInt(datePart[1])
                const hour = parseInt(timePart[0])
                const minute = parseInt(timePart[1])
                const second = timePart[2] ? parseInt(timePart[2]) : 0
                lastScan = new Date(year, month, day, hour, minute, second).toISOString()
              }
            }
          } else {
            lastScan = new Date(dateValue).toISOString()
          }
        } catch (e) {
          // Try to parse as timestamp string
          lastScan = row[lastScanCol]?.toString() || null
        }
      }

      // Ensure required fields are not empty (username and name are NOT NULL)
      const username = usernameCol !== -1 ? (row[usernameCol] || '').toString().trim() : ''
      const name = nameCol !== -1 ? (row[nameCol] || '').toString().trim() : ''
      
      // Skip rows with missing required fields
      if (!username || !name) {
        skipped++
        skipReasons.missing_required_fields++
        if (skippedRows.length < MAX_SKIPPED_ROWS_DETAILS) {
          skippedRows.push({
            row_number: rowNumber,
            reason: 'missing_required_fields',
            username: username || null,
            name: name || null,
            qr_token: qrToken,
            batch: batchCol !== -1 ? (row[batchCol] || '').toString().trim() : null,
            missing_fields: [
              ...(!username ? ['username'] : []),
              ...(!name ? ['name'] : [])
            ]
          })
        }
        continue
      }

      const studentData = {
        username,
        name,
        batch: batchCol !== -1 ? (row[batchCol] || '').toString().trim() : null,
        mentor: mentorCol !== -1 ? (row[mentorCol] || '').toString().trim() : null,
        qr_token: qrToken,
        sts: stsCol !== -1 ? (row[stsCol] || 'inactive').toString().trim() : 'inactive',
        in_time: inTime,
        last_scan: lastScan,
      }

      studentDataArray.push(studentData)
    }

    // Batch insert only new students
    const errorDetails: any[] = []
    let successfulInserts = 0
    
    if (studentDataArray.length > 0) {
      // Process in batches to avoid overwhelming the database
      for (let i = 0; i < studentDataArray.length; i += batchSize) {
        const batch = studentDataArray.slice(i, i + batchSize)
        
        const { data, error } = await supabaseClient
          .from('students')
          .insert(batch, { 
            onConflict: 'qr_token',
            ignoreDuplicates: true 
          })
          .select()

        if (error) {
          console.error(`Error inserting batch ${i / batchSize + 1}:`, JSON.stringify(error, null, 2))
          errorDetails.push({
            batch: i / batchSize + 1,
            error: error.message,
            code: error.code,
            details: error.details,
            hint: error.hint,
            batch_size: batch.length
          })
          errors += batch.length
        } else {
          // Count actual inserted records (data will be null or empty if all were duplicates)
          const insertedCount = data?.length || 0
          successfulInserts += insertedCount
          
          // If we expected to insert but got fewer, some might have been duplicates
          if (insertedCount < batch.length) {
            const duplicateCount = batch.length - insertedCount
            skipped += duplicateCount
            console.log(`Batch ${i / batchSize + 1}: Inserted ${insertedCount}, skipped ${duplicateCount} duplicates`)
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: errors === 0,
        message: errors === 0 ? 'Sync completed' : 'Sync completed with errors',
        stats: {
          total_rows: rows.length - 1,
          processed: studentDataArray.length,
          inserted: successfulInserts,
          skipped,
          errors,
          skip_reasons: skipReasons
        },
        ...(skippedRows.length > 0 && {
          skipped_rows: skippedRows,
          skipped_rows_count: skippedRows.length,
          ...(skipped > MAX_SKIPPED_ROWS_DETAILS && {
            note: `Showing first ${MAX_SKIPPED_ROWS_DETAILS} of ${skipped} skipped rows`
          })
        }),
        ...(errorDetails.length > 0 && { 
          error_details: errorDetails.slice(0, 10), // Include first 10 errors for debugging
          total_error_batches: errorDetails.length
        })
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error syncing Google Sheets:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || 'Unknown error occurred' 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

