let ws;
let viewportWidth = 390, viewportHeight = 844;
const $ = id => document.getElementById(id);
function send(command, extra = {}) { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify({type:'command', command, ...extra})); }
$('connect').onclick = () => {
  const code = $('code').value.trim();
  if (!code) return;
  ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
  ws.onopen = () => { $('status').textContent = 'Connecting…'; ws.send(JSON.stringify({type:'pair', code})); };
  ws.onclose = () => $('status').textContent = 'Disconnected';
  ws.onerror = () => $('status').textContent = 'Connection error';
  ws.onmessage = e => {
    if (typeof e.data === 'string') {
      const m = JSON.parse(e.data);
      if (m.type === 'paired') $('status').textContent = 'Connected to iPhone';
      if (m.type === 'error') $('status').textContent = m.message;
      if (m.type === 'device-offline') $('status').textContent = 'iPhone disconnected';
      if (m.type === 'browser-state') { if (m.url) $('url').value = m.url; viewportWidth = m.viewportWidth || viewportWidth; viewportHeight = m.viewportHeight || viewportHeight; }
    } else if (e.data instanceof Blob) {
      $('screen').src = URL.createObjectURL(e.data);
    }
  };
};
$('back').onclick = () => send('back');
$('forward').onclick = () => send('forward');
$('reload').onclick = () => send('reload');
$('go').onclick = () => send('navigate', {url:$('url').value});
$('url').onkeydown = e => { if (e.key === 'Enter') send('navigate', {url:e.target.value}); };
$('scrollUp').onclick = () => send('scroll', {deltaY:-500});
$('scrollDown').onclick = () => send('scroll', {deltaY:500});
$('type').onclick = () => send('type', {text:$('typeText').value});
$('screen').onclick = e => {
  const r = e.currentTarget.getBoundingClientRect();
  send('tap', {x:(e.clientX-r.left) * viewportWidth/r.width, y:(e.clientY-r.top) * viewportHeight/r.height});
};
