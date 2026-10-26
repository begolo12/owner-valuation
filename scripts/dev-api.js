// Server API lokal untuk uji coba sebelum deploy.
// Pakai: node --env-file=.env.local scripts/dev-api.js  (atau set env manual)
import { createServer } from 'node:http';
import dispatch from '../server/router.js';

const port = Number(process.env.PORT || 5198);

createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://local');
  const path = pathname.replace(/^\/api\/?/, '').replace(/\/$/, '');
  await dispatch(req, res, path);
}).listen(port, '127.0.0.1', () => {
  console.log(`API lokal: http://127.0.0.1:${port}/api`);
});
