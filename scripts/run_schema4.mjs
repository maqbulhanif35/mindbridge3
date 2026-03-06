import pg from 'pg'
import { readFileSync } from 'fs'
const { Client } = pg

const SQL = readFileSync('../database/supabase_schema.sql', 'utf8')
const REF = 'fdkwqzeyrcvxgqlpbjnp'

// Try all EU and other possible pooler endpoints
const hosts = [
  'aws-0-eu-west-1.pooler.supabase.com',
  'aws-0-eu-west-2.pooler.supabase.com',
  'aws-0-eu-central-1.pooler.supabase.com',
]

for (const host of hosts) {
  for (const port of [5432, 6543]) {
    const client = new Client({
      host, port,
      database: 'postgres',
      user: `postgres.${REF}`,
      password: 'Abubakar@31767',
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 6000,
    })
    try {
      process.stdout.write(`${host}:${port} -> `)
      await client.connect()
      console.log('CONNECTED!')
      await client.query(SQL)
      const res = await client.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`)
      console.log('Tables:', res.rows.map(r=>r.table_name).join(', '))
      await client.end()
      process.exit(0)
    } catch(e) {
      console.log(e.message)
      await client.end().catch(()=>{})
    }
  }
}
