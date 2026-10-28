const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawn, execFile } = require('child_process');
const token = crypto.randomBytes(24).toString('hex');
const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
let pinned = false;
const server = http.createServer((req, res) => {
  if (req.method === 'GET' && new URL(req.url, 'http://localhost').pathname === '/') {
    res.writeHead(200, {'Content-Type':'text/html; charset=utf-8', 'Cache-Control':'no-store'});
    fs.createReadStream(path.join(__dirname,'index.html')).pipe(res); return;
  }
  const match = /^\/window\/(minimize|maximize|pin)$/.exec(req.url);
  if (req.method !== 'POST' || !match || req.headers['x-notebook-token'] !== token || req.headers.origin !== `http://127.0.0.1:${server.address().port}`) {res.writeHead(403);res.end();return;}
  const nextPin = !pinned;
  execFile('powershell.exe', ['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'window.ps1'),match[1],nextPin ? 'true' : 'false'], {windowsHide:true}, (err, stdout, stderr) => {
    if (!err && match[1] === 'pin') pinned = nextPin;
    res.writeHead(200, {'Content-Type':'application/json'});res.end(JSON.stringify({ok:!err,pinned,error:err?(stderr||err.message):undefined}));
  });
});
server.listen(0, '127.0.0.1', () => {
  const url = `http://127.0.0.1:${server.address().port}/?token=${token}`;
  const browser = spawn(edge, [`--app=${url}`, '--new-window', `--user-data-dir=${path.join(__dirname,'.browser-data')}`], {detached:false, stdio:'ignore'});
  browser.on('error', err => {console.error('无法启动 Edge:',err.message);server.close()});
  browser.on('exit', () => server.close());
});
