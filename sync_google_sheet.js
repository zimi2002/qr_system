// Sync Google Sheet to Supabase
// Usage: node sync_google_sheet.js [SUPABASE_URL] [SUPABASE_ANON_KEY]

const https = require('https');

// Google Sheet ID extracted from the URL
const SHEET_ID = '1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY';

// Get Supabase URL and key from arguments or environment
const SUPABASE_URL = process.argv[2] || process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.argv[3] || process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Error: SUPABASE_URL and SUPABASE_ANON_KEY are required');
  console.log('');
  console.log('Usage:');
  console.log('  node sync_google_sheet.js [SUPABASE_URL] [SUPABASE_ANON_KEY]');
  console.log('');
  console.log('Or set environment variables:');
  console.log('  export SUPABASE_URL="https://your-project.supabase.co"');
  console.log('  export SUPABASE_ANON_KEY="your-anon-key"');
  console.log('  node sync_google_sheet.js');
  process.exit(1);
}

const url = new URL(`${SUPABASE_URL}/functions/v1/sync-google-sheets`);
const data = JSON.stringify({
  sheetId: SHEET_ID,
  range: 'A1:Z1000'
});

const options = {
  hostname: url.hostname,
  path: url.pathname,
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('🔄 Syncing Google Sheet to Supabase...');
console.log(`📊 Sheet ID: ${SHEET_ID}`);
console.log(`🔗 Supabase URL: ${SUPABASE_URL}`);
console.log('');

const req = https.request(options, (res) => {
  let responseData = '';

  res.on('data', (chunk) => {
    responseData += chunk;
  });

  res.on('end', () => {
    try {
      const json = JSON.parse(responseData);
      if (json.success) {
        console.log('✅ Sync completed successfully!');
        console.log('');
        console.log(JSON.stringify(json, null, 2));
        if (json.stats) {
          console.log('');
          console.log('📈 Statistics:');
          console.log(`   Total rows processed: ${json.stats.total_rows}`);
          console.log(`   Inserted: ${json.stats.inserted}`);
          console.log(`   Updated: ${json.stats.updated}`);
          console.log(`   Errors: ${json.stats.errors}`);
        }
      } else {
        console.error('❌ Sync failed!');
        console.error('');
        console.error(JSON.stringify(json, null, 2));
        process.exit(1);
      }
    } catch (e) {
      console.error('❌ Error parsing response:', e);
      console.error('Response:', responseData);
      process.exit(1);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error);
  process.exit(1);
});

req.write(data);
req.end();

