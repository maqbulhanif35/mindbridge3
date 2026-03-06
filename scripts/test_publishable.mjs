import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://fdkwqzeyrcvxgqlpbjnp.supabase.co',
  'sb_publishable_cF53LhI1NOZ10pTj-akHSQ_v6IleBFlR'
)

console.log('Client created, testing auth...')
try {
  const { data, error } = await supabase.auth.getSession()
  console.log('getSession result:', JSON.stringify({ data, error }, null, 2))
} catch(e) {
  console.log('Error:', e.message)
}

try {
  const { data, error } = await supabase.from('profiles').select('count').limit(1)
  console.log('profiles query result:', JSON.stringify({ data, error }, null, 2))
} catch(e) {
  console.log('Query error:', e.message)
}
