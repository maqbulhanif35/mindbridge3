import pg from 'pg'
import { readFileSync } from 'fs'
const { Client } = pg

const SQL = readFileSync('../database/supabase_schema.sql', 'utf8')
const PASSWORD = 'Abubakar@31767'
const REF = 'fdkwqzeyrcvxgqlpbjnp'

// Try all known Supabase connection formats
const configs = [
  // Pooler - EU West session mode
  { host: 'aws-0-eu-west-1.pooler.supabase.com', port: 5432, user: `postgres.${REF}` },
  // Pooler - EU West transaction mode  
  { host: 'aws-0-eu-west-1.pooler.supabase.com', port: 6543, user: `postgres.${REF}` },
  // Alternative: just 'postgres' as user
  { host: 'aws-0-eu-west-1.pooler.supabase.com', port: 5432, user: 'postgres' },
  // Direct via IP
  { host: '108.128.216.176', port: 5432, user: `postgres.${REF}` },
  { host: '108.128.216.176', port: 6543, user: `postgres.${REF}` },
]

for (const cfg of configs) {
  const client = new Client({
    ...cfg,
    database: 'postgres',
    password: PASSWORD,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 8000,
  })
  try {
    console.log(`Trying ${cfg.user}@${cfg.host}:${cfg.port}...`)
    await client.connect()
    console.log('CONNECTED!')
    await client.query(SQL)
    console.log('Schema executed successfully!')
    const res = await client.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`)
    console.log('Tables:', res.rows.map(r=>r.table_name).join(', '))
    await client.end()
    process.exit(0)
  } catch(e) {
    console.log(`  -> ${e.message}`)
    await client.end().catch(()=>{})
  }
}
console.log('\nAll connection attempts failed.')
