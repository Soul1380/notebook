'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
function setup({busy=false,storageFails=false,installFails=false}={}){
  const nodes=new Map(),saved=new Map(),requests=[];
  const context={console,Date:{now:()=>20000},URLSearchParams,location:{protocol:'http:',search:'?token=test'},strokes:[{points:[{x:1,y:2}]}],objects:[{type:'text',text:'unsaved'}],view:{x:3,y:4,scale:2},action:busy?{}:null,editor:null,finishText(){},setInterval(){},localStorage:{setItem(k,v){if(storageFails)throw Error('quota');saved.set(k,v)},removeItem(k){saved.delete(k)}},document:{body:{inert:false},addEventListener(){},querySelector(id){if(id==='.annotation-name')return null;if(!nodes.has(id))nodes.set(id,{click(){}});return nodes.get(id)}},fetch:async(url)=>{requests.push(url);return {ok:!installFails,json:async()=>url.endsWith('/install')?{message:installFails?'failed':'restarting'}:{phase:'current',message:'current'}}}};
  vm.createContext(context);
  const source=fs.readFileSync('interaction.js','utf8').split('const updateStatus=')[1].split('// Declarative plugins')[0];
  vm.runInContext('const updateStatus='+source,context);
  return {context,saved,requests,run:code=>vm.runInContext(code,context)};
}
test('idle update saves editable canvas and view before installation',async()=>{
  const s=setup();await s.run('installReadyUpdate()');
  assert.deepEqual(JSON.parse(s.saved.get('notebook-update-session-v1')),{strokes:s.context.strokes,objects:s.context.objects,view:s.context.view});
  assert.equal(s.context.document.body.inert,true);assert.ok(s.requests.includes('/updates/install'));
  await s.run('installReadyUpdate()');assert.equal(s.requests.filter(x=>x==='/updates/install').length,1);
});
test('active drawing postpones installation',async()=>{const s=setup({busy:true});await s.run('installReadyUpdate()');assert.equal(s.saved.size,0);assert.ok(!s.requests.includes('/updates/install'))});
test('failed canvas backup prevents shutdown',async()=>{const s=setup({storageFails:true});await s.run('installReadyUpdate()');assert.ok(!s.requests.includes('/updates/install'));assert.equal(s.context.document.body.inert,false)});
test('failed installer request restores editing',async()=>{const s=setup({installFails:true});await s.run('installReadyUpdate()');assert.equal(s.context.document.body.inert,false);assert.ok(s.saved.has('notebook-update-session-v1'))});
test('ready update waits for ten seconds without activity',async()=>{const s=setup();s.run("displayUpdate({phase:'ready',version:'v1.0.2'})");assert.ok(!s.requests.includes('/updates/install'));s.run('lastUpdateActivity=0');s.run("displayUpdate({phase:'ready',version:'v1.0.2'})");await new Promise(resolve=>setImmediate(resolve));assert.ok(s.requests.includes('/updates/install'))});