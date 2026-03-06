import pg from 'pg'
import { readFileSync } from 'fs'
const { Client } = pg

const SQL = readFileSync('../database/supabase_schema.sql', 'utf8')

// Try Supabase pooler (session mode port 5432)
const configs = [
  { host: 'aws-0-eu-west-1.pooler.supabase.com', port: 5432, user: 'postgres.fdkwqzeyrcvxgqlpbjnp' },
  { host: 'aws-0-eu-west-1.pooler.supabase.com', port: 6543, user: 'postgres.fdkwqzeyrcvxgqlpbjnp' },
]

for (const cfg of configs) {
  const client = new Client({
    ...cfg,
    database: 'postgres',
    password: 'Abubakar@31767',
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
  })
  try {
    console.log(`Trying ${cfg.host}:${cfg.port}...`)
    await client.connect()
    console.log('Connected! Running schema...')
    await client.query(SQL)
    console.log('SUCCESS: Schema executed!')
    const res = await client.query(`
      SELECT table_name FROM information_schema.tables
      WHERE table_schema = 'public' ORDER BY table_name;
    `)
    console.log('Tables created:', res.rows.map(r => r.table_name).join(', '))
    await client.end()
    process.exit(0)
  } catch (err) {
    console.log(`  Error: ${err.message}`)
    await client.end().catch(() => {})
  }
}
