import * as T from './three.module.min.js';
const $ = id => document.getElementById(id);
const tau = Math.PI * 2, nu = 160, nv = 48, hidden = 12;
const programs = [
  {name:'Origin', values:[0,0,0]}, {name:'Pleat study', values:[.76,-.18,.31]},
  {name:'Crossweave', values:[-.46,.85,.68]}, {name:'Deep rift', values:[.24,-.96,-.81]}
];
const edits = [
  {name:'Pleat', desc:'Fold the inner lip', vector:[.85,.35,-.30,.54], icon:'M1 19 8 5 14 19 21 5 27 19 M1 23 8 9 14 23 21 9 27 23'},
  {name:'Shear', desc:'Shift the two axes', vector:[-.42,.88,.72,-.28], icon:'M2 8 23 4 M4 14 25 10 M6 20 27 16'},
  {name:'Bloom', desc:'Open the outer rim', vector:[.37,-.6,.82,.4], icon:'M14 23V3 M14 18Q2 19 2 8Q13 8 14 18 M14 15Q25 15 26 5Q16 4 14 15'}
];
let seed = 94861;
const random = () => ((seed = (Math.imul(seed,1664525)+1013904223)>>>0) / 4294967296);
const W = Float64Array.from({length:hidden*4},()=> (random()-.5)*3.8);
const bias = Float64Array.from({length:hidden},()=> (random()-.5)*3);
const out = Float64Array.from({length:hidden*3},()=> (random()-.5)*1.12);
const directions = edits.map((_,k)=>Float64Array.from({length:hidden},(_,i)=>2.7*Math.sin((i+1)*(k+1.3))));
const weights = W.slice();
let coeff = programs[1].values.slice(), programIndex = 1, playing=false, origin=false;
let pathTime=1, yaw=.29, pitch=.57, probeU=.14, probeV=.06, dirty=true, renderNeeded=true;
const clamp=(v,a,b)=>Math.min(b,Math.max(a,v));
function loadWeights(c) {
 for(let i=0;i<hidden;i++)for(let j=0;j<4;j++){
  const n=4*i+j;
  weights[n]=W[n]+edits.reduce((sum,e,k)=>sum+c[k]*directions[k][i]*e.vector[j],0);
 }
}
function coords(cu,su,cv,sv,w,d,k) {
 let a=0,b=0,c=0;
 for(let i=0;i<hidden;i++){
  const j=i*4;
  const h=Math.sin(w[j]*cu+w[j+1]*su+w[j+2]*cv+w[j+3]*sv+bias[i]);
  a+=out[i]*h; b+=out[hidden+i]*h; c+=out[2*hidden+i]*h;
 }
 const thick=.56+.14*Math.tanh(c);
 const radius=1.23+thick*cv+.23*Math.tanh(a);
 d[k]=cu*radius*1.19+.18*Math.tanh(b);
 d[k+1]=sv*thick*.86+.40*Math.tanh(b)+.25*(2*su*cu)+.13*Math.tanh(c);
 d[k+2]=su*radius+.18*Math.tanh(a);
}
const count=(nu+1)*(nv+1), pos=new Float32Array(count*3), base=pos.slice(), uv=new Float32Array(count*2);
const tableU=Array.from({length:nu+1},(_,i)=>[Math.cos(tau*i/nu),Math.sin(tau*i/nu)]);
const tableV=Array.from({length:nv+1},(_,i)=>[Math.cos(tau*i/nv),Math.sin(tau*i/nv)]);
const idx=[];
function populate(w,p){for(let i=0;i<=nu;i++)for(let j=0;j<=nv;j++){
 const k=i*(nv+1)+j; coords(tableU[i][0],tableU[i][1],tableV[j][0],tableV[j][1],w,p,k*3);
}}
for(let i=0;i<=nu;i++)for(let j=0;j<=nv;j++){
 const k=i*(nv+1)+j;uv[k*2]=i/nu;uv[k*2+1]=j/nv;
 if(i<nu&&j<nv)idx.push(k,k+1,k+nv+1,k+1,k+nv+2,k+nv+1);
}
populate(W,base);
const geo=new T.BufferGeometry();
geo.setAttribute('position',new T.BufferAttribute(pos,3).setUsage(T.DynamicDrawUsage));
geo.setAttribute('uv',new T.BufferAttribute(uv,2));geo.setIndex(idx);
const canvas=$('scene'), parent=canvas.parentElement;
const scene=new T.Scene(), cam=new T.PerspectiveCamera(33,1,.1,50);
const surface=new T.Mesh(geo,new T.ShaderMaterial({
 side:T.DoubleSide,vertexShader:`varying vec3 n; varying vec3 view; varying vec2 st;
 void main(){st=uv;n=normalMatrix*normal;vec4 p=modelViewMatrix*vec4(position,1.);view=-p.xyz;gl_Position=projectionMatrix*p;}`,
 fragmentShader:`varying vec3 n; varying vec3 view; varying vec2 st;
 void main(){vec3 N=normalize(n)*(gl_FrontFacing?1.:-1.);vec3 V=normalize(view);
 float l=dot(N,normalize(vec3(-.48,.78,.82)));float facing=abs(dot(N,V));
 float line=abs(fract(st.x*145.)-.5);float fw=min(.45,fwidth(st.x*145.));
 float grooves=1.-smoothstep(.08,.18+fw,line);
 vec3 dark=vec3(.095,.045,.18),mid=vec3(.84,.285,.18),gold=vec3(1.,.79,.48);
 vec3 col=mix(dark,mid,smoothstep(-.75,.48,l));col=mix(col,gold,smoothstep(.26,1.,l)*.88);
 float comb=.5+.5*sin(st.x*6.28318*7.+st.y*6.28318);
 col*=1.-grooves*(.38+.18*comb);col+=pow(1.-facing,3.)*vec3(.28,.19,.28);
 col+=pow(max(0.,dot(reflect(-normalize(vec3(-.3,.6,1.)),N),V)),22.)*vec3(.48,.32,.19);
 gl_FragColor=vec4(col,1.);}`
}));
scene.add(surface);
const pin=new T.Mesh(new T.SphereGeometry(.031,12,10),new T.MeshBasicMaterial({color:0xfff3ca}));scene.add(pin);
const grid=new T.GridHelper(16,40,0x645260,0x59424f);grid.position.y=-1.38;grid.material.transparent=true;grid.material.opacity=.24;scene.add(grid);
scene.fog=new T.FogExp2(0x171621,.12);
const shadow=document.createElement('canvas');shadow.width=shadow.height=128;const shadowCtx=shadow.getContext('2d');const g=shadowCtx.createRadialGradient(64,64,0,64,64,64);g.addColorStop(0,'rgba(0,0,0,.85)');g.addColorStop(.52,'rgba(0,0,0,.46)');g.addColorStop(1,'transparent');shadowCtx.fillStyle=g;shadowCtx.fillRect(0,0,128,128);
const floor=new T.Mesh(new T.PlaneGeometry(5.2,4),new T.MeshBasicMaterial({map:new T.CanvasTexture(shadow),transparent:true,depthWrite:false}));floor.rotation.x=-Math.PI/2;floor.position.y=-1.37;scene.add(floor);
parent.style.background='radial-gradient(ellipse at 50% 50%,#322835 0%,#211e2c 51%,#13131c 92%)';
let renderer,stage=canvas,ctx;
try{renderer=new T.WebGLRenderer({canvas,antialias:true,alpha:true,powerPreference:'low-power'});renderer.setClearColor(0,0);}
catch{stage=canvas.cloneNode(false);canvas.replaceWith(stage);ctx=stage.getContext('2d');$('mode').textContent='Canvas contour view';}
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
let w=1,h=1;
function resize(){w=parent.clientWidth;h=parent.clientHeight;
 if(renderer){renderer.setPixelRatio(Math.min(devicePixelRatio,1.75));renderer.setSize(w,h,false)}
 else{stage.width=w*1.5;stage.height=h*1.5;ctx.setTransform(1.5,0,0,1.5,0,0)}
 cam.aspect=w/h;cam.updateProjectionMatrix();renderNeeded=true;
}
new ResizeObserver(resize).observe(parent);resize();
function pointAt(u,v,weights,d){coords(Math.cos(tau*u),Math.sin(tau*u),Math.cos(tau*v),Math.sin(tau*v),weights,d,0)}
const tmp=[0,0,0],ref=[0,0,0],pvec=new T.Vector3(), ray=new T.Raycaster();
function drawProfile(){
 const graph=$('probe'),ctx=graph.getContext('2d'),w=graph.clientWidth,h=graph.clientHeight;
 if(!w)return;
 const dpr=Math.min(devicePixelRatio,2);graph.width=Math.round(w*dpr);graph.height=Math.round(h*dpr);ctx.scale(dpr,dpr);
 ctx.strokeStyle='#c9c5b6';ctx.lineWidth=.75;
 for(let j=0;j<3;j++){const y=4+j*(h-8)/2;ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke()}
 const profile=[];let max=.2;
 for(let i=0;i<=100;i++){pointAt(i/100,probeV,weights,tmp);pointAt(i/100,probeV,W,ref);const d=Math.hypot(tmp[0]-ref[0],tmp[1]-ref[1],tmp[2]-ref[2]);max=Math.max(d,max);profile.push(d)}
 const yAt=d=>h-4-d/max*(h-10);
 ctx.strokeStyle='#ac4329';ctx.lineWidth=1.6;ctx.beginPath();profile.forEach((d,i)=>i?ctx.lineTo(i*w/100,yAt(d)):ctx.moveTo(0,yAt(d)));ctx.stroke();
 pointAt(probeU,probeV,weights,tmp);pointAt(probeU,probeV,W,ref);
 const delta=Math.hypot(tmp[0]-ref[0],tmp[1]-ref[1],tmp[2]-ref[2]);
 ctx.strokeStyle='#494536';ctx.beginPath();ctx.moveTo(probeU*w,0);ctx.lineTo(probeU*w,h);ctx.stroke();
 ctx.fillStyle='#9d371e';ctx.beginPath();ctx.arc(probeU*w,yAt(delta),3,0,tau);ctx.fill();
 $('reading').textContent='Δ '+delta.toFixed(3);$('probeText').textContent='Probe  u '+probeU.toFixed(2)+'  /  v '+probeV.toFixed(2);
 (origin?ref:tmp).forEach((n,i)=>pin.position.setComponent(i,n));
}
function drawMatrix(){
 if(!$('inspect').open)return;
 const matrix=$('matrix'),cx=matrix.getContext('2d'),w=matrix.clientWidth,h=matrix.clientHeight;
 const dpr=Math.min(devicePixelRatio,2);matrix.width=Math.round(w*dpr);matrix.height=Math.round(h*dpr);cx.scale(dpr,dpr);
 const cell=(w-34)/hidden, row=(h-18)/4;
 cx.font='10px monospace';cx.textBaseline='middle';
 let max=0;
 for(let i=0;i<hidden;i++){
  cx.fillStyle='#676355';cx.textAlign='center';cx.fillText(String(i+1),34+cell*(i+.5),9);
  for(let j=0;j<4;j++){
   if(i===0){cx.textAlign='left';cx.fillText(['cos u','sin u','cos v','sin v'][j],0,18+row*(j+.5))}
   const d=weights[i*4+j]-W[i*4+j];max=Math.max(max,Math.abs(d));
   cx.fillStyle='#e3dfd2';cx.fillRect(34+i*cell,18+j*row,cell-2,row-2);
   cx.fillStyle=d>0?'#bb4827':'#64569e';cx.globalAlpha=Math.min(1,Math.abs(d)/4);cx.fillRect(34+i*cell,18+j*row,cell-2,row-2);cx.globalAlpha=1;cx.fillStyle='#676355';
  }
 }
 $('scale').value='Max |Δw|  '+max.toFixed(3);
}
$('inspect').ontoggle=drawMatrix;
new ResizeObserver(drawMatrix).observe($('matrix'));
function rebuild(){
 loadWeights(coeff);if(origin)pos.set(base);else populate(weights,pos);
 geo.attributes.position.needsUpdate=true;geo.computeVertexNormals();geo.computeBoundingSphere();drawProfile();drawMatrix();dirty=false;
}
function cameraPose(){const r=Math.max(5.9,7.6/cam.aspect);cam.position.set(Math.sin(yaw)*Math.cos(pitch)*r,Math.sin(pitch)*r,Math.cos(yaw)*Math.cos(pitch)*r);cam.lookAt(0,-.05,0);cam.updateMatrixWorld();}
function wire(){ctx.clearRect(0,0,w,h);const rings=[];
 for(let i=0;i<nu;i+=2){const path=new Path2D();let z=0;
 for(let j=0;j<=nv;j++){const k=(i*(nv+1)+j)*3;pvec.fromArray(pos,k).project(cam);z+=pvec.z;const x=(pvec.x+1)*w/2,y=(1-pvec.y)*h/2;j?path.lineTo(x,y):path.moveTo(x,y)}
 rings.push({path,z,i})}
 rings.sort((a,b)=>b.z-a.z);for(const [i,r] of rings.entries()){ctx.fillStyle='#38283e';ctx.strokeStyle='hsl('+ (15+18*i/rings.length)+' 78% '+ (44+32*i/rings.length)+'%)';ctx.fill(r.path);ctx.stroke(r.path)}
}
function refreshControls(){
 edits.forEach((_,i)=>{const val=coeff[i];$('s'+i).value=val;$('v'+i).value=(val>=0?'+':'')+val.toFixed(2)});
 $('specimen').textContent=origin?'Origin comparison':playing?'Tracing weights':programIndex>=0?programs[programIndex].name:'Custom fold';
 [...$('steps').children].forEach((b,i)=>b.setAttribute('aria-current',String(i===programIndex)));
 $('play').textContent=playing?'Ⅱ Pause path':'▶ Play path';$('play').setAttribute('aria-pressed',String(playing));
 $('compare').setAttribute('aria-pressed',String(origin));$('compare').textContent=origin?'Return to edit':'Compare origin';
}
function select(i){programIndex=i;pathTime=i;playing=false;origin=false;coeff=programs[i].values.slice();dirty=true;refreshControls()}
edits.forEach((e,i)=>{const row=document.createElement('div');row.className='op';row.innerHTML=`<div class="keytop"><label for="s${i}"><span class="glyph" aria-hidden="true"><svg viewBox="0 0 29 27" fill="none" stroke="currentColor" stroke-width="1.5"><path d="${e.icon}"/></svg></span>${e.name}</label><output id="v${i}" for="s${i}"></output></div><p>${e.desc}</p><input id="s${i}" type="range" min="-1" max="1" step=".01" aria-label="${e.name} strength">`;$('controls').append(row);
 $('s'+i).oninput=e=>{coeff[i]=+e.target.value;programIndex=-1;playing=false;origin=false;dirty=true;refreshControls()}});
programs.forEach((p,i)=>{const b=document.createElement('button');b.textContent=p.name;b.onclick=()=>select(i);$('steps').append(b)});
$('play').onclick=()=>{if(!playing&&programIndex<0){pathTime=0}playing=!playing;origin=false;dirty=true;refreshControls()};
$('compare').onclick=()=>{origin=!origin;playing=false;dirty=true;refreshControls()};
$('reset').onclick=()=>select(0);$('notes').onclick=()=>{$('guide').showModal()};$('close').onclick=()=>$('guide').close();
let drag=null, moved=false;
stage.onpointerdown=e=>{drag={x:e.clientX,y:e.clientY,a:yaw,b:pitch};moved=false;stage.setPointerCapture(e.pointerId)};
stage.onpointermove=e=>{if(!drag)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(Math.hypot(dx,dy)>4)moved=true;if(moved){yaw=drag.a-dx*.008;pitch=clamp(drag.b+dy*.008,-1.1,1.28);renderNeeded=true}};
stage.onpointerup=e=>{if(drag&&!moved){const box=stage.getBoundingClientRect();ray.setFromCamera(new T.Vector2(2*(e.clientX-box.left)/box.width-1,1-2*(e.clientY-box.top)/box.height),cam);const hit=ray.intersectObject(surface)[0];if(hit){probeU=hit.uv.x;probeV=hit.uv.y;drawProfile();renderNeeded=true}}drag=null};
stage.onpointercancel=()=>{drag=null};
stage.onkeydown=e=>{if(!['ArrowLeft','ArrowRight','ArrowDown','ArrowUp'].includes(e.key))return;e.preventDefault();yaw+=e.key==='ArrowLeft'?-.1:e.key==='ArrowRight'?.1:0;pitch=clamp(pitch+(e.key==='ArrowDown'?-.1:e.key==='ArrowUp'?.1:0),-1.1,1.28);renderNeeded=true};
$('probe').onclick=e=>{const b=e.target.getBoundingClientRect();probeU=clamp((e.clientX-b.left)/b.width,0,1);drawProfile();renderNeeded=true};
$('probe').onkeydown=e=>{if(e.key!=='ArrowLeft'&&e.key!=='ArrowRight')return;e.preventDefault();probeU=clamp(probeU+(e.key==='ArrowLeft'?-.02:.02),0,1);drawProfile();renderNeeded=true};
new ResizeObserver(()=>{if(!dirty)drawProfile()}).observe($('probe'));
refreshControls();
let last=0;
function frame(t){requestAnimationFrame(frame);if(t-last<32||document.hidden)return;
 const dt=Math.min(.09,(t-last)/1000);last=t;
 if(playing&&!$('guide').open){pathTime=(pathTime+dt/3.8)%programs.length;const i=Math.floor(pathTime),f=pathTime-i,s=f*f*(3-2*f);
 coeff=programs[i].values.map((v,k)=>v+(programs[(i+1)%programs.length].values[k]-v)*s);programIndex=i;dirty=true;refreshControls()}
 if(!drag&&!reduced.matches&&!$('guide').open){yaw+=dt*.048;renderNeeded=true}
 if(!dirty&&!renderNeeded)return;
 if(dirty)rebuild();cameraPose();renderer?renderer.render(scene,cam):wire();renderNeeded=false;
}
requestAnimationFrame(frame);
