/* Triggers a Flutter hot reload via the Dart VM Service (reloadSources + reassemble). */
const WebSocket = require('ws');
const HTTP = process.argv[2];
const WS = HTTP.replace(/^http/, 'ws').replace(/\/$/, '') + '/ws';
const ws = new WebSocket(WS);
let id = 0; const pending = {};
const call = (method, params) => new Promise((res) => { const i = ++id; pending[i] = res; ws.send(JSON.stringify({ jsonrpc: '2.0', id: i, method, params: params || {} })); });
ws.on('message', (d) => { const m = JSON.parse(d); if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; } });
ws.on('error', (e) => { console.error('WS ERROR', e.message); process.exit(1); });
ws.on('open', async () => {
  const vm = await call('getVM');
  const iso = vm.result.isolates[0].id;
  const r = await call('reloadSources', { isolateId: iso, force: false });
  console.log('reloadSources:', JSON.stringify(r.result || r.error));
  const re = await call('ext.flutter.reassemble', { isolateId: iso });
  console.log('reassemble:', JSON.stringify(re.result || re.error));
  process.exit(0);
});
