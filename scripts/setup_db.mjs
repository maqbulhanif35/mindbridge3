// MindBridge — Supabase DB Setup Script
import { createClient } from '@supabase/supabase-js';

const URL = 'https://fdkwqzeyrcvxgqlpbjnp.supabase.co';
const KEY = 'sb_publishable_cF53LhI1NOZ10pTj-akHSQ_v6IleBFlR';

const supabase = createClient(URL, KEY);

async function main() {
  console.log('Testing Supabase connection...');
  const { data, error } = await supabase.from('profiles').select('id').limit(1);
  if (error) {
    console.log('Result:', error.code, '-', error.message);
    if (error.message.includes('Invalid API key') || error.code === 'PGRST301') {
      console.log('\n⚠️  Publishable key is not compatible with supabase-js v2 REST API.');
    }
  } else {
    console.log('✅ Connection OK! profiles table has', data.length, 'rows.');
  }
}

main().catch(console.error);
