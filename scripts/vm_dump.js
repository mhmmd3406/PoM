/* Dumps the live Flutter render tree via the Dart VM Service to inspect sizes. */
const WebSocket = require('ws');
const HTTP = process.argv[2]; // e.g. http://127.0.0.1:36786/l_TOrD_CvmI=/
const WS = HTTP.replace(/^http/, 'ws').replace(/\/$/, '') + '/ws';
const ws = new WebSocket(WS);
let id = 0; const pending = {};
const call = (method, params) => new Promise((res) => { const i = ++id; pending[i] = res; ws.send(JSON.stringify({ jsonrpc: '2.0', id: i, method, params: params || {} })); });
ws.on('message', (d) => { const m = JSON.parse(d); if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; } });
ws.on('error', (e) => { console.error('WS ERROR', e.message); process.exit(1); });
ws.on('open', async () => {
  const vm = await call('getVM');
  const iso = vm.result.isolates[0].id;
  for (const ext of ['ext.flutter.debugDumpRenderTree']) {
    const r = await call(ext, { isolateId: iso });
    const data = r.result && (r.result.data || r.result.tree);
    console.log(data || JSON.stringify(r));
  }
  process.exit(0);
});
