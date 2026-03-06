import pg from 'pg'
import { readFileSync } from 'fs'
const { Client } = pg

const SQL = readFileSync('../database/supabase_schema.sql', 'utf8')
const REF = 'fdkwqzeyrcvxgqlpbjnp'
const PASS = 'Abubakar@31767'

// Try the main project host on PostgreSQL ports (old Supabase used to expose these)
const configs = [
  { host: `${REF}.supabase.co`, port: 5432, user: 'postgres' },
  { host: `${REF}.supabase.co`, port: 6543, user: 'postgres' },
  { host: `${REF}.supabase.co`, port: 5432, user: `postgres.${REF}` },
  // Try the known Cloudflare IPs of the project
  { host: '104.18.38.10', port: 5432, user: 'postgres' },
]

for (const cfg of configs) {
  const client = new Client({
    ...cfg,
    database: 'postgres',
    password: PASS,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 5000,
  })
  try {
    process.stdout.write(`${cfg.user}@${cfg.host}:${cfg.port} -> `)
    await client.connect()
    console.log('CONNECTED!')
    await client.query(SQL)
    const res = await client.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`)
    console.log('Tables:', res.rows.map(r=>r.table_name).join(', '))
    await client.end()
    process.exit(0)
  } catch(e) {
    console.log(e.message.slice(0,60))
    await client.end().catch(()=>{})
  }
}
