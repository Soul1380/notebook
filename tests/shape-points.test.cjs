const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync('app.js','utf8');
const shapePoints=vm.runInNewContext(source.slice(source.indexOf('function shapePoints('),source.indexOf('function positionEditor('))+';shapePoints');
function bounds(points){return {left:Math.min(...points.map(p=>p.x)),right:Math.max(...points.map(p=>p.x)),top:Math.min(...points.map(p=>p.y)),bottom:Math.max(...points.map(p=>p.y))}}
for(const kind of ['square','circle','rect','ellipse','triangle','line'])test(kind+' keeps initial point as center in all drag directions',()=>{
 const start={x:100,y:200};
 for(const [dx,dy] of [[40,10],[-40,10],[40,-10],[-40,-10],[0,40],[40,0],[0,0]]){
  const current={x:start.x+dx,y:start.y+dy},box=bounds(shapePoints(kind,start,current,true));
  assert.ok(Math.abs((box.left+box.right)/2-start.x)<1e-8);
  assert.ok(Math.abs((box.top+box.bottom)/2-start.y)<1e-8);
  if(kind==='square'||kind==='circle')assert.ok(Math.abs(box.right-box.left-2*Math.max(Math.abs(dx),Math.abs(dy)))<1e-8);
  assert.deepEqual(start,{x:100,y:200});assert.deepEqual(current,{x:100+dx,y:200+dy});
 }
});
test('ordinary rectangle and square retain starting corner',()=>{
 for(const kind of ['rect','square']){const box=bounds(shapePoints(kind,{x:100,y:200},{x:140,y:210},false));assert.equal(box.left,100);assert.equal(box.top,200);assert.equal(box.right,140);assert.equal(box.bottom,kind==='square'?240:210)}
});