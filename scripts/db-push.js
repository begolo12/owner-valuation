import { readFile } from 'node:fs/promises';
import pg from 'pg';

const url = process.env.DATABASE_URL || process.env.POSTGRES_URL;
if (!url) {
  console.error('DATABASE_URL belum diset. Contoh: DATABASE_URL=postgres://... node scripts/db-push.js');
  process.exit(1);
}

const sql = await readFile(new URL('../db/schema.sql', import.meta.url), 'utf8');
const client = new pg.Client({ connectionString: url });
await client.connect();
try {
  await client.query(sql);
  console.log('Schema terpasang.');
} finally {
  await client.end();
}
