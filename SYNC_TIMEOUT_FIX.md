# Sync Function Timeout Fix

## Issue
The sync function was timing out (504 Gateway Timeout) after 154 seconds when processing large Google Sheets.

## Root Cause
The original implementation was:
- Processing rows one-by-one sequentially
- Making 2-3 database queries per row (upsert + select to check insert/update)
- For 100+ rows, this meant 200-300+ database queries
- Each query adds network latency, causing the function to exceed the timeout limit

## Solution
The function has been optimized to:
1. **Batch Processing**: Process rows in batches of 50
2. **Bulk Upsert**: Upsert multiple rows at once instead of one-by-one
3. **Single Query for Existing Data**: Get all existing qr_tokens in one query upfront
4. **Removed Inefficient Logic**: Removed the timestamp checking that required extra queries

## Performance Improvement
- **Before**: ~154 seconds for 100 rows (timed out)
- **After**: Should complete in ~5-10 seconds for 100 rows

## Changes Made

### 1. Batch Processing
```typescript
// Process in batches of 50
const batchSize = 50
for (let i = 0; i < studentDataArray.length; i += batchSize) {
  const batch = studentDataArray.slice(i, i + batchSize)
  await supabaseClient.from('students').upsert(batch, ...)
}
```

### 2. Pre-fetch Existing Tokens
```typescript
// Get all existing qr_tokens in one query
const { data: existingStudents } = await supabaseClient
  .from('students')
  .select('qr_token')
const existingTokens = new Set(existingStudents.map(s => s.qr_token))
```

### 3. Bulk Upsert
```typescript
// Upsert entire batch at once
await supabaseClient
  .from('students')
  .upsert(batch, { onConflict: 'qr_token' })
```

## Next Steps

1. **Redeploy the Edge Function**:
   ```bash
   supabase functions deploy sync-google-sheets
   ```

2. **Test the Sync Again**:
   ```bash
   curl -X POST \
     'https://YOUR_PROJECT.supabase.co/functions/v1/sync-google-sheets' \
     -H 'Authorization: Bearer YOUR_ANON_KEY' \
     -H 'Content-Type: application/json' \
     -d '{
       "sheetId": "1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY",
       "range": "A1:Z1000"
     }'
   ```

3. **Monitor Execution Time**:
   - Check Supabase Dashboard > Edge Functions > Logs
   - Execution time should now be under 10 seconds

## Additional Optimizations (If Still Needed)

If you still experience timeouts with very large sheets (500+ rows), consider:

1. **Increase Batch Size**: Change `batchSize` from 50 to 100
2. **Process Specific Ranges**: Sync in chunks (e.g., A1:Z100, then A101:Z200)
3. **Use Database Transactions**: Wrap batches in transactions for better performance
4. **Add Progress Reporting**: Return partial results for very large syncs

## Troubleshooting

### Still Getting Timeouts?
- Check Supabase Dashboard > Edge Functions > Logs for actual execution time
- Reduce batch size if database is slow
- Consider syncing in smaller chunks

### Data Not Syncing?
- Check error logs in Supabase Dashboard
- Verify Google Sheet is public
- Ensure column headers match expected format

### Partial Syncs?
- The function now processes in batches, so some batches may succeed while others fail
- Check the `errors` count in the response
- Review logs to see which rows failed


