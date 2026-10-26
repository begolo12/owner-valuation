import pg from 'pg';

const url = process.env.DATABASE_URL || process.env.POSTGRES_URL;
if (!url) throw new Error('DATABASE_URL belum diset');

// Cache pool antar-invocation supaya koneksi hangat dipakai ulang.
globalThis.__pgPool ??= new pg.Pool({ connectionString: url, max: 3, idleTimeoutMillis: 10_000 });

export const pool = globalThis.__pgPool;

export async function q(text, params = []) {
  const { rows } = await pool.query(text, params);
  return rows;
}
