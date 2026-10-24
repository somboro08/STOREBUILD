import { createApp } from './app.js';
import { config } from './config.js';
import { initDb } from './db.js';

await initDb();
createApp().listen(config.port, () => {
  console.log(`Whatstore API sur ${config.publicUrl} (base : ${config.dbDriver}, paiements : ${config.paymentProvider})`);
});
