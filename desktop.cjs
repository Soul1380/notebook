const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawn, execFile } = require('child_process');
const token = crypto.randomBytes(24).toString('hex');
const shutdownKey=crypto.randomBytes(32).toString('hex');
const sessionPath=path.join(__dirname,'.notebook-session.json');
let browser;
let installingUpdate=false;
const updater=require('./updater.cjs').createUpdater(__dirname);
updater.check().catch(()=>{});
setInterval(()=>{if(!installingUpdate)updater.check().catch(()=>{});},30*60*1000).unref();
const edge = [process.env['PROGRAMFILES(X86)'],process.env.PROGRAMFILES,process.env.LOCALAPPDATA].filter(Boolean).map(root=>path.join(root,'Microsoft','Edge','Application','msedge.exe')).find(fs.existsSync)||'msedge.exe';
let pinned = false;
const server = http.createServer((req, res) => {
  if (req.method === 'GET' && new URL(req.url, 'http://localhost').pathname === '/') {
    res.writeHead(200, {'Content-Type':'text/html; charset=utf-8', 'Cache-Control':'no-store'});
    fs.createReadStream(path.join(__dirname,'index.html')).pipe(res); return;
  }
  const staticFiles = new Set(['/app.js','/preferences.js','/colors.js','/files.js','/interaction.js','/styles.css','/notebook.ico']);
  if (req.method === 'GET' && staticFiles.has(req.url)) {
    const name=req.url.slice(1);res.writeHead(200, {'Content-Type':name.endsWith('.css')?'text/css; charset=utf-8':name.endsWith('.ico')?'image/x-icon':'text/javascript; charset=utf-8','Cache-Control':'no-store'});fs.createReadStream(path.join(__dirname,name)).pipe(res);return;
  }
  if(req.url==='/report-settings'){
    if(req.headers['x-notebook-token']!==token||(req.method==='POST'&&req.headers.origin!==`http://127.0.0.1:${server.address().port}`)||!['GET','POST'].includes(req.method)){res.writeHead(403);res.end();return}
    const file=path.join(__dirname,'.report-settings.json');
    const reply=data=>{res.writeHead(200,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data))};
    if(req.method==='GET'){try{reply({enabled:JSON.parse(fs.readFileSync(file,'utf8')).enabled===true})}catch(e){reply({enabled:true})}return}
    let body='';req.on('data',chunk=>{body+=chunk;if(body.length>1024)req.destroy()});req.on('end',()=>{try{const data=JSON.parse(body);if(typeof data.enabled!=='boolean')throw Error();fs.writeFileSync(file,JSON.stringify({enabled:data.enabled}),'utf8');reply({enabled:data.enabled})}catch(e){res.writeHead(400);res.end()}});return;
  }
  if(['/plugins','/plugins/open'].includes(req.url)){
    const opening=req.url==='/plugins/open';
    if(req.headers['x-notebook-token']!==token||(opening&&(req.method!=='POST'||req.headers.origin!==`http://127.0.0.1:${server.address().port}`))||(!opening&&req.method!=='GET')){res.writeHead(403);res.end();return}
    try{
      const dir=path.join(__dirname,'plugins');fs.mkdirSync(dir,{recursive:true});
      if(opening){const child=spawn('explorer.exe',[dir],{detached:true,windowsHide:true,stdio:'ignore'});child.on('error',()=>{});child.unref();res.writeHead(200);res.end('{}');return}
      const plugins=[];
      for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
        if(!entry.isDirectory()||entry.isSymbolicLink()||!/^[-\w.]{1,80}$/.test(entry.name))continue;
        try{
          const base=path.join(dir,entry.name),manifest=path.join(base,'manifest.json');
          if(fs.lstatSync(manifest).isSymbolicLink()||fs.statSync(manifest).size>131072)continue;
          const data=JSON.parse(fs.readFileSync(manifest,'utf8'));
          if(!data||typeof data.name!=='string'||typeof data.version!=='string'||typeof data.author!=='string'||typeof data.description!=='string')continue;
          const item={id:entry.name,name:data.name.slice(0,100),version:data.version.slice(0,40),author:data.author.slice(0,100),description:data.description.slice(0,500),type:data.type,config:data.config||{}};
          if(data.type==='font'&&typeof item.config.file==='string'&&/^[\w.-]+\.(woff2?|ttf|otf)$/i.test(item.config.file)){
            const f=path.join(base,item.config.file);if(!fs.lstatSync(f).isSymbolicLink()&&fs.statSync(f).size<=10*1024*1024)item.fontData=fs.readFileSync(f).toString('base64');
          }
          plugins.push(item);
        }catch(e){}
      }
      res.writeHead(200,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(plugins));
    }catch(e){res.writeHead(500);res.end('{}')};return;
  }
  if (req.url === '/tasks' || req.url === '/tasks/activate') {
    const activate=req.url.endsWith('/activate');
    if(req.headers['x-notebook-token']!==token || (activate && (req.method!=='POST'||req.headers.origin!==`http://127.0.0.1:${server.address().port}`)) || (!activate && req.method!=='GET')){res.writeHead(403);res.end();return;}
    function run(id){const args=['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'tasks.ps1'),activate?'activate':'list'];if(activate)args.push(id);execFile('powershell.exe',args,{windowsHide:true,timeout:12000,maxBuffer:4*1024*1024,encoding:'utf8'},(err,stdout)=>{if(err){res.writeHead(500);res.end();return}try{const data=JSON.parse(stdout);res.writeHead(200,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data))}catch(e){res.writeHead(500);res.end()}})}
    if(!activate){run();return}let body='';req.on('data',chunk=>{body+=chunk;if(body.length>1024)req.destroy()});req.on('end',()=>{try{const data=JSON.parse(body);if(typeof data.id!=='string'||!/^\d{1,18}$/.test(data.id))throw Error();run(data.id)}catch(e){res.writeHead(400);res.end()}});return;
  }
  if(['/updates','/updates/check','/updates/install'].includes(req.url)){
    const post=req.url!=='/updates';if(req.headers['x-notebook-token']!==token||(post&&(req.method!=='POST'||req.headers.origin!==`http://127.0.0.1:${server.address().port}`))||(!post&&req.method!=='GET')){res.writeHead(403);res.end();return}
    const reply=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data))};
    if(req.url==='/updates'){reply(200,updater.status());return}
    if(req.url==='/updates/check'){updater.check().then(data=>reply(200,data)).catch(()=>reply(500,{phase:'error',message:'无法检查更新'}));return}
    if(installingUpdate){reply(409,{message:'正在安装更新，请稍候'});return}
    const pending=updater.pending(),launcher=path.join(__dirname,'HandwritingNotebook.exe');if(!pending||!fs.existsSync(launcher)){reply(400,{message:!pending?'没有可安装的更新':'请在安装版中使用自动更新'});return}
    const args=['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'apply-update.ps1'),'-Root',__dirname,'-Archive',pending.file,'-Sha256',pending.sha256,'-ExpectedVersion',pending.version,'-BackendPid',String(process.pid)];
    const readyFile=path.join(__dirname,'.update-cache','helper-ready'),resultFile=path.join(__dirname,'.update-cache','update-result.json');
    try{for(const f of [readyFile,resultFile])if(fs.existsSync(f))fs.unlinkSync(f)}catch(e){reply(500,{message:'无法准备更新日志'});return}
    installingUpdate=true;
    let helper,answered=false;
    const fail=message=>{if(answered)return;answered=true;installingUpdate=false;if(helper&&!helper.killed)helper.kill();reply(500,{message})};
    try{
      helper=spawn('powershell.exe',args,{detached:true,windowsHide:true,stdio:'ignore'});
      helper.once('error',()=>fail('无法启动更新程序'));
      helper.once('exit',()=>{if(!answered)fail('更新程序启动失败，请检查更新日志')});
      const started=Date.now();
      const waitReady=setInterval(()=>{
        if(answered){clearInterval(waitReady);return}
        if(Date.now()-started>15000){clearInterval(waitReady);fail('更新程序准备超时，请重试');return}
        try{
          if(!fs.existsSync(readyFile)||fs.readFileSync(readyFile,'utf8')!==pending.version)return;
          fs.writeFileSync(path.join(__dirname,'.update-exit-request'),shutdownKey,'utf8');
          clearInterval(waitReady);answered=true;helper.unref();reply(200,{message:'正在安装更新并重启'});
          setTimeout(()=>{if(browser&&browser.pid&&browser.exitCode===null)execFile('taskkill.exe',['/PID',String(browser.pid),'/T','/F'],{windowsHide:true,timeout:5000},()=>{server.close(()=>process.exit(0));setTimeout(()=>process.exit(0),1500).unref()});else{server.close(()=>process.exit(0));setTimeout(()=>process.exit(0),1500).unref()}},700);
        }catch(e){clearInterval(waitReady);fail('无法准备重启：'+e.message)}
      },100);
    }catch(e){fail('无法启动更新程序')};return;
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
  const match = /^\/window\/(minimize|maximize|pin|directory)$/.exec(req.url);
  if (req.method !== 'POST' || !match || req.headers['x-notebook-token'] !== token || req.headers.origin !== `http://127.0.0.1:${server.address().port}`) {res.writeHead(403);res.end();return;}
  if(match[1]==='directory'){
    try {const explorer=spawn('explorer.exe',[__dirname],{detached:true,stdio:'ignore'});explorer.once('error',()=>{res.writeHead(500,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'无法打开软件目录'}))});explorer.once('spawn',()=>{explorer.unref();res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:true}))})}catch(e){res.writeHead(500,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'无法打开软件目录'}))}return;
  }
  const nextPin = !pinned;
  execFile('powershell.exe', ['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'window.ps1'),match[1],nextPin ? 'true' : 'false'], {windowsHide:true}, (err, stdout, stderr) => {
    if (!err && match[1] === 'pin') pinned = nextPin;
    res.writeHead(200, {'Content-Type':'application/json'});res.end(JSON.stringify({ok:!err,pinned,error:err?(stderr||err.message):undefined}));
  });
});
server.on('close',()=>{if(installingUpdate)return;try{const saved=JSON.parse(fs.readFileSync(sessionPath,'utf8'));if(saved.key===shutdownKey)fs.unlinkSync(sessionPath)}catch(e){}});
server.listen(17683, '127.0.0.1', () => {
  fs.writeFileSync(sessionPath,JSON.stringify({key:shutdownKey}),'utf8');
  const url = `http://127.0.0.1:${server.address().port}/?token=${token}`;
  const geometry=process.argv.slice(2).filter(arg=>/^--(?:position|size)=-?\d+,-?\d+$/.test(arg)).map(arg=>arg.replace('--position=','--window-position=').replace('--size=','--window-size='));
  browser = spawn(edge, [`--app=${url}`, '--new-window', ...geometry, `--user-data-dir=${path.join(__dirname,'.browser-data')}`], {detached:false, stdio:'ignore'});
  browser.once('spawn',()=>{const iconHelper=spawn('powershell.exe',['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'window.ps1'),'icon','false'],{windowsHide:true,stdio:'ignore'});iconHelper.on('error',()=>{});});
  browser.on('error', err => {console.error('无法启动 Edge:',err.message);server.close()});
  browser.on('exit', () => server.close());
});


