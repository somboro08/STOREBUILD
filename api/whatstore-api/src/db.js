import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from './config.js';

let impl;
const here = path.dirname(fileURLToPath(import.meta.url));

/** PostgreSQL (pg) en production ; PGlite (Postgres embarqué) pour le dev et les tests. */
export async function initDb() {
  if (impl) return;
  if (config.dbDriver === 'pglite') {
    const { PGlite } = await import('@electric-sql/pglite');
    const db = config.pgliteDir ? new PGlite(config.pgliteDir) : new PGlite();
    await db.waitReady;
    impl = {
      query: (t, p) => db.query(t, p),
      exec: (s) => db.exec(s),
      tx: (fn) => db.transaction((t) => fn({ query: (x, y) => t.query(x, y) })),
      close: () => db.close(),
    };
  } else {
    const pg = (await import('pg')).default;
    pg.types.setTypeParser(20, (v) => Number(v)); // BIGINT -> number
    const pool = new pg.Pool({ connectionString: config.databaseUrl });
    impl = {
      query: (t, p) => pool.query(t, p),
      exec: (s) => pool.query(s),
      tx: async (fn) => {
        const c = await pool.connect();
        try {
          await c.query('BEGIN');
          const r = await fn({ query: (x, y) => c.query(x, y) });
          await c.query('COMMIT');
          return r;
        } catch (e) {
          await c.query('ROLLBACK');
          throw e;
        } finally {
          c.release();
        }
      },
      close: () => pool.end(),
    };
  }
  await impl.exec(fs.readFileSync(path.join(here, '..', 'sql', 'schema.sql'), 'utf8'));
}

export const db = { query: (t, p) => impl.query(t, p) };
export const tx = (fn) => impl.tx(fn);
export const closeDb = async () => {
  if (impl) await impl.close();
  impl = undefined;
};
