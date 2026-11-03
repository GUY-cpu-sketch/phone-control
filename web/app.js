let ws;
let viewportWidth=390, viewportHeight=844, lastObjectURL;

const $=id=>document.getElementById(id);
const status=$('status');
const pill=$('connectionPill');
const empty=$('empty');
const screen=$('screen');
const loading=$('loading');

function setStatus(text,online=false){
  status.textContent=text;
  pill.className='pill '+(online?'online':'offline');
}
function send(command,extra={}){
  if(ws?.readyState===WebSocket.OPEN) ws.send(JSON.stringify({type:'command',command,...extra}));
}
function connect(){
  const code=$('code').value.trim();
  if(!/^\d{6}$/.test(code)){ $('hint').textContent='Enter the 6-digit code shown in the iPhone app.'; return; }
  if(ws) ws.close();
  setStatus('Connecting…');
  loading.hidden=false;
  ws=new WebSocket((location.protocol==='https:'?'wss://':'ws://')+location.host+'/ws');
  ws.onopen=()=>{ setStatus('Pairing…'); ws.send(JSON.stringify({type:'pair',code})); };
  ws.onerror=()=>{ setStatus('Connection error'); loading.hidden=true; };
  ws.onclose=()=>{ setStatus('Disconnected'); loading.hidden=true; empty.hidden=false; };
  ws.onmessage=e=>{
    if(typeof e.data==='string'){
      let m; try{m=JSON.parse(e.data)}catch{return}
      if(m.type==='paired'){setStatus('iPhone connected',true);empty.hidden=true;loading.hidden=true}
      if(m.type==='error'){setStatus('Pairing failed');loading.hidden=true;$('hint').textContent=m.message}
      if(m.type==='device-offline'){setStatus('iPhone offline');empty.hidden=false;loading.hidden=true}
      if(m.type==='browser-state'){
        if(m.url) $('url').value=m.url;
        viewportWidth=m.viewportWidth||viewportWidth;
        viewportHeight=m.viewportHeight||viewportHeight;
      }
    }else if(e.data instanceof Blob){
      if(lastObjectURL) URL.revokeObjectURL(lastObjectURL);
      lastObjectURL=URL.createObjectURL(e.data);
      screen.src=lastObjectURL;
      screen.hidden=false; empty.hidden=true; loading.hidden=true;
    }
  };
}
$('connect').onclick=connect;
$('code').onkeydown=e=>{if(e.key==='Enter')connect()};
$('back').onclick=()=>send('back');
$('forward').onclick=()=>send('forward');
$('reload').onclick=()=>send('reload');
$('go').onclick=()=>send('navigate',{url:$('url').value});
$('url').onkeydown=e=>{if(e.key==='Enter')send('navigate',{url:e.target.value})};
$('scrollUp').onclick=()=>send('scroll',{deltaY:-500});
$('scrollDown').onclick=()=>send('scroll',{deltaY:500});
$('type').onclick=()=>{const v=$('typeText').value;if(v){send('type',{text:v});$('typeText').value=''}};
$('typeText').onkeydown=e=>{if(e.key==='Enter')$('type').click()};
screen.onclick=e=>{
  const r=screen.getBoundingClientRect();
  send('tap',{x:(e.clientX-r.left)*viewportWidth/r.width,y:(e.clientY-r.top)*viewportHeight/r.height});
};
setStatus('Disconnected');
