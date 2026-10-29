const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawn, execFile } = require('child_process');
const token = crypto.randomBytes(24).toString('hex');
const shutdownKey=crypto.randomBytes(32).toString('hex');
const sessionPath=path.join(__dirname,'.notebook-session.json');
let browser;
const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
let pinned = false;
const server = http.createServer((req, res) => {
  if (req.method === 'GET' && new URL(req.url, 'http://localhost').pathname === '/') {
    res.writeHead(200, {'Content-Type':'text/html; charset=utf-8', 'Cache-Control':'no-store'});
    fs.createReadStream(path.join(__dirname,'index.html')).pipe(res); return;
  }
  const staticFiles = new Set(['/app.js','/preferences.js','/colors.js','/files.js','/interaction.js','/styles.css']);
  if (req.method === 'GET' && staticFiles.has(req.url)) {
    const name=req.url.slice(1);res.writeHead(200, {'Content-Type':name.endsWith('.css')?'text/css; charset=utf-8':'text/javascript; charset=utf-8','Cache-Control':'no-store'});fs.createReadStream(path.join(__dirname,name)).pipe(res);return;
  }
  if (req.url === '/tasks' || req.url === '/tasks/activate') {
    const activate=req.url.endsWith('/activate');
    if(req.headers['x-notebook-token']!==token || (activate && (req.method!=='POST'||req.headers.origin!==`http://127.0.0.1:${server.address().port}`)) || (!activate && req.method!=='GET')){res.writeHead(403);res.end();return;}
    function run(id){const args=['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'tasks.ps1'),activate?'activate':'list'];if(activate)args.push(id);execFile('powershell.exe',args,{windowsHide:true,timeout:12000,maxBuffer:4*1024*1024,encoding:'utf8'},(err,stdout)=>{if(err){res.writeHead(500);res.end();return}try{const data=JSON.parse(stdout);res.writeHead(200,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data))}catch(e){res.writeHead(500);res.end()}})}
    if(!activate){run();return}let body='';req.on('data',chunk=>{body+=chunk;if(body.length>1024)req.destroy()});req.on('end',()=>{try{const data=JSON.parse(body);if(typeof data.id!=='string'||!/^\d{1,18}$/.test(data.id))throw Error();run(data.id)}catch(e){res.writeHead(400);res.end()}});return;
  }
  if(req.url==='/shutdown'){
    if(req.method!=='POST'||req.headers['x-notebook-shutdown']!==shutdownKey){res.writeHead(403);res.end();return}
    // Only the dedicated Edge process started by this notebook is closed.
    const finish=err=>{if(err&&browser&&browser.exitCode===null){res.writeHead(500,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'无法关闭笔记本窗口'}));return}res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:true}));server.close(()=>process.exit(0));setTimeout(()=>process.exit(0),1500).unref()};
    if(browser&&browser.pid&&!browser.killed&&browser.exitCode===null){execFile('taskkill.exe',['/PID',String(browser.pid),'/T','/F'],{windowsHide:true,timeout:5000},finish)}else finish();
    return;
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
server.on('close',()=>{try{const saved=JSON.parse(fs.readFileSync(sessionPath,'utf8'));if(saved.key===shutdownKey)fs.unlinkSync(sessionPath)}catch(e){}});
server.listen(17683, '127.0.0.1', () => {
  fs.writeFileSync(sessionPath,JSON.stringify({key:shutdownKey}),'utf8');
  const url = `http://127.0.0.1:${server.address().port}/?token=${token}`;
  const geometry=process.argv.slice(2).filter(arg=>/^--(?:position|size)=-?\d+,-?\d+$/.test(arg)).map(arg=>arg.replace('--position=','--window-position=').replace('--size=','--window-size='));
  browser = spawn(edge, [`--app=${url}`, '--new-window', ...geometry, `--user-data-dir=${path.join(__dirname,'.browser-data')}`], {detached:false, stdio:'ignore'});
  browser.on('error', err => {console.error('无法启动 Edge:',err.message);server.close()});
  browser.on('exit', () => server.close());
});


