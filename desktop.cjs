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
  if (req.method === 'GET' && req.url === '/app.js') {
    res.writeHead(200, {'Content-Type':'text/javascript; charset=utf-8', 'Cache-Control':'no-store'});
    fs.createReadStream(path.join(__dirname,'app.js')).pipe(res); return;
  }
  const quick = /^\/quick\/(baidu|chatgpt)$/.exec(req.url);
  if (quick) {
    if (req.method !== 'POST' || req.headers['x-notebook-token'] !== token || req.headers.origin !== `http://127.0.0.1:${server.address().port}`) { res.writeHead(403);res.end();return; }
    let body='';req.on('data',chunk=>{body+=chunk;if(body.length>20000)req.destroy()});req.on('end',()=>{let data;try{data=JSON.parse(body);if(typeof data.text!=='string'||!data.text.trim()||data.text.length>5000)throw Error('查询内容无效')}catch(e){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'查询内容无效'}));return}
      const respond=(ok,error)=>{res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok,error}))};
      const launch=(program,args)=>{let child;try{child=spawn(program,args,{detached:true,stdio:'ignore',windowsHide:true});child.once('error',()=>respond(false,'无法打开目标程序'));child.once('spawn',()=>{child.unref();respond(true)})}catch(e){respond(false,e.message)}};
      if(quick[1]==='chatgpt'){launch('explorer.exe',['shell:AppsFolder\\OpenAI.Codex_2p2nqsd0c76g0!App']);return}
      const candidates=[path.join(process.env.PROGRAMFILES||'C:\\Program Files','Google/Chrome/Application/chrome.exe'),path.join(process.env['PROGRAMFILES(X86)']||'C:\\Program Files (x86)','Google/Chrome/Application/chrome.exe'),path.join(process.env.LOCALAPPDATA||'','Google/Chrome/Application/chrome.exe')];const chrome=candidates.find(fs.existsSync);if(!chrome){respond(false,'未找到 Chrome，请先安装 Chrome 或检查安装位置');return}launch(chrome,['https://www.baidu.com/s?wd='+encodeURIComponent(data.text)]);
    });return;
  }
  const match = /^\/window\/(minimize|maximize|pin)$/.exec(req.url);
  if (req.method !== 'POST' || !match || req.headers['x-notebook-token'] !== token || req.headers.origin !== `http://127.0.0.1:${server.address().port}`) {res.writeHead(403);res.end();return;}
  const nextPin = !pinned;
  execFile('powershell.exe', ['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'window.ps1'),match[1],nextPin ? 'true' : 'false'], {windowsHide:true}, (err, stdout, stderr) => {
    if (!err && match[1] === 'pin') pinned = nextPin;
    res.writeHead(200, {'Content-Type':'application/json'});res.end(JSON.stringify({ok:!err,pinned,error:err?(stderr||err.message):undefined}));
  });
});
server.listen(17683, '127.0.0.1', () => {
  const url = `http://127.0.0.1:${server.address().port}/?token=${token}`;
  const browser = spawn(edge, [`--app=${url}`, '--new-window', `--user-data-dir=${path.join(__dirname,'.browser-data')}`], {detached:false, stdio:'ignore'});
  browser.on('error', err => {console.error('无法启动 Edge:',err.message);server.close()});
  browser.on('exit', () => server.close());
});


