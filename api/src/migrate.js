import { initDb, closeDb } from './db.js';

await initDb();
console.log('Schéma appliqué.');
await closeDb();
