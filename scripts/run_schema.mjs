import pg from 'pg'
import { readFileSync } from 'fs'
const { Client } = pg

const SQL = readFileSync('../database/supabase_schema.sql', 'utf8')

// Try direct connection first
const client = new Client({
  host: 'db.fdkwqzeyrcvxgqlpbjnp.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Abubakar@31767',
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
})

try {
  console.log('Connecting to Supabase PostgreSQL...')
  await client.connect()
  console.log('Connected! Running schema...')
  await client.query(SQL)
  console.log('SUCCESS: All tables created!')

  // Verify tables exist
  const res = await client.query(`
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name;
  `)
  console.log('Tables in public schema:', res.rows.map(r => r.table_name).join(', '))
  await client.end()
} catch (err) {
  console.log('Direct connection error:', err.message)
  await client.end().catch(() => {})
}
