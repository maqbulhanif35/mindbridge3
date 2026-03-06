import pg from 'pg'
const { Client } = pg

// Get full error details from pooler
const client = new Client({
  host: 'aws-0-eu-west-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.fdkwqzeyrcvxgqlpbjnp',
  password: 'Abubakar@31767',
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
})

client.on('error', (e) => console.log('Client error:', e))

try {
  await client.connect()
} catch(e) {
  console.log('Error code:', e.code)
  console.log('Error message:', e.message)
  console.log('Error detail:', e.detail)
  console.log('Error hint:', e.hint)
  console.log('Full error:', JSON.stringify(e, null, 2))
}
await client.end().catch(()=>{})
