import pg from 'pg'
import { readFileSync } from 'fs'
const { Client } = pg

const SQL = readFileSync('../database/supabase_schema.sql', 'utf8')

// Direct connection via IPv6
const client = new Client({
  host: '2a05:d018:135e:16b5:a791:1133:e944:505f',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Abubakar@31767',
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
})

try {
  console.log('Connecting via IPv6...')
  await client.connect()
  console.log('Connected!')
  await client.query(SQL)
  const res = await client.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`)
  console.log('Tables created:', res.rows.map(r=>r.table_name).join(', '))
  await client.end()
} catch(e) {
  console.log('Error:', e.message)
  await client.end().catch(()=>{})
}
