import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    // Parse request body or query parameters
    let params: { action?: string; qr_token?: string } = {}
    
    if (req.method === 'POST') {
      params = await req.json()
    } else {
      const url = new URL(req.url)
      params = {
        action: url.searchParams.get('action') || undefined,
        qr_token: url.searchParams.get('qr_token') || undefined,
      }
    }

    const { action, qr_token } = params

    if (!action || !qr_token) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing action or qr_token parameter' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Handle getStudent action
    if (action === 'getStudent') {
      const { data, error } = await supabaseClient
        .from('students')
        .select('*')
        .eq('qr_token', qr_token.trim())
        .single()

      if (error || !data) {
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: 'QR token not found' 
          }),
          { 
            status: 200, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      // Format response to match Google Apps Script format
      const student = {
        username: data.username || '',
        name: data.name || '',
        batch: data.batch || '',
        mentor: data.mentor || '',
        sts: data.sts || 'inactive',
        in_time: data.in_time ? new Date(data.in_time).toISOString() : '',
        last_scan: data.last_scan ? new Date(data.last_scan).toISOString() : '',
        qr_token: data.qr_token,
      }

      return new Response(
        JSON.stringify({ 
          success: true, 
          data: student 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Handle activate action
    if (action === 'activate') {
      // First, get the current student data
      const { data: currentStudent, error: fetchError } = await supabaseClient
        .from('students')
        .select('*')
        .eq('qr_token', qr_token.trim())
        .single()

      if (fetchError || !currentStudent) {
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: 'QR token not found' 
          }),
          { 
            status: 200, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      const now = new Date()
      const nowISO = now.toISOString()
      
      // Capture previous scan time before updating (for duplicate display)
      const previousScanTime = currentStudent.last_scan 
        ? new Date(currentStudent.last_scan).toISOString() 
        : null
      
      // Check if this is a duplicate scan (last_scan was within the last 5 minutes)
      let isDuplicate = false
      if (currentStudent.last_scan) {
        const lastScanTime = new Date(currentStudent.last_scan)
        const timeDiff = now.getTime() - lastScanTime.getTime()
        const fiveMinutes = 5 * 60 * 1000 // 5 minutes in milliseconds
        
        if (timeDiff < fiveMinutes) {
          isDuplicate = true
        }
      }

      // Prepare update data - ALWAYS update last_scan and sts
      const updateData: any = {
        sts: 'active',
        last_scan: nowISO, // Always update last_scan on every scan
      }

      // Only set in_time if this is the first scan (sts was inactive)
      if (currentStudent.sts === 'inactive' || !currentStudent.in_time) {
        updateData.in_time = nowISO
      }

      // Update student record - ensure last_scan is always updated
      console.log(`Updating student ${qr_token}: last_scan=${nowISO}, sts=active`)
      const { data: updatedStudent, error: updateError } = await supabaseClient
        .from('students')
        .update(updateData)
        .eq('qr_token', qr_token.trim())
        .select()
        .single()

      if (updateError) {
        console.error(`Failed to update student ${qr_token}:`, updateError)
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: `Failed to update student: ${updateError.message}` 
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      // Verify last_scan was updated
      if (updatedStudent && updatedStudent.last_scan) {
        console.log(`Successfully updated last_scan for ${qr_token}: ${updatedStudent.last_scan}`)
      } else {
        console.warn(`Warning: last_scan may not have been updated for ${qr_token}`)
      }

      // Format response to match Google Apps Script format
      const student = {
        username: updatedStudent.username || '',
        name: updatedStudent.name || '',
        batch: updatedStudent.batch || '',
        mentor: updatedStudent.mentor || '',
        sts: updatedStudent.sts || 'active',
        in_time: updatedStudent.in_time ? new Date(updatedStudent.in_time).toISOString() : '',
        last_scan: updatedStudent.last_scan ? new Date(updatedStudent.last_scan).toISOString() : '',
        qr_token: updatedStudent.qr_token,
      }

      // Build response with previous_scan_time if duplicate
      const responseData: any = {
        success: true, 
        message: 'Student activated successfully',
        data: student,
        is_duplicate_scan: isDuplicate
      }
      
      // Include previous scan time if this is a duplicate
      if (isDuplicate && previousScanTime) {
        responseData.previous_scan_time = previousScanTime
      }

      return new Response(
        JSON.stringify(responseData),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Unknown action
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: 'Invalid action. Use "getStudent" or "activate"' 
      }),
      { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in attendance-check:', error)
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

