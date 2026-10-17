(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  const style = document.createElement("style");
  style.textContent = "#arcane-controls{position:fixed;z-index:6;inset:auto 14px max(18px,env(safe-area-inset-bottom)) 14px;display:none;align-items:end;justify-content:space-between;pointer-events:none;font:12px system-ui,sans-serif}#arcane-controls button{pointer-events:auto;touch-action:none;user-select:none;-webkit-user-select:none}#arcane-pad{width:132px;height:132px;display:grid;grid-template:1fr 1fr 1fr/1fr 1fr 1fr;gap:3px;padding:6px;border:1px solid #9870b8;border-radius:50%;background:#0b0715c9;box-shadow:0 0 22px #8d45c633}#arcane-pad button{padding:0;border-radius:50%;font-size:20px;background:#251638dc;border-color:#76549a}#arcane-pad button[data-dir=up]{grid-area:1/2}#arcane-pad button[data-dir=left]{grid-area:2/1}#arcane-pad button[data-dir=right]{grid-area:2/3}#arcane-pad button[data-dir=down]{grid-area:3/2}#arcane-actions{display:flex;align-items:end;gap:8px}#arcane-actions button{width:58px;height:58px;padding:4px;border-radius:50%;font-size:10px;background:radial-gradient(circle at 35% 25%,#68448b,#160c27);border-color:#bc8fe0;box-shadow:0 0 18px #8e49c855}#arcane-actions button strong{display:block;font-size:21px;color:#f1d7ff}#arcane-help{position:fixed;z-index:6;left:50%;bottom:calc(max(18px,env(safe-area-inset-bottom)) + 142px);transform:translateX(-50%);display:none;padding:7px 11px;border:1px solid #60427c;border-radius:18px;background:#0b0715dd;color:#e9d6f7;font:11px system-ui,sans-serif;white-space:nowrap}@media(min-width:760px){#arcane-controls{left:24px;right:24px}#arcane-pad{width:118px;height:118px}#arcane-actions button{width:54px;height:54px}}";
  document.head.appendChild(style);
  const controls=document.createElement("div");controls.id="arcane-controls";
  controls.innerHTML='<div id="arcane-pad"><button data-dir="up" aria-label="Move up">▲</button><button data-dir="left" aria-label="Move left">◀</button><button data-dir="right" aria-label="Move right">▶</button><button data-dir="down" aria-label="Move down">▼</button></div><div id="arcane-actions"><button id="arcane-interact"><strong>✦</strong>INTERACT</button><button id="arcane-dodge"><strong>➤</strong>DODGE</button><button id="arcane-spell"><strong>✧</strong>SPELL</button></div>';
  document.body.appendChild(controls);
  const help=document.createElement("div");help.id="arcane-help";help.textContent="WASD / arrows to move · E to interact · Space to cast";document.body.appendChild(help);
  window.arcaneMove={x:0,y:0};
  let keys={};
  function sync(){const visible=$("town-hud")&&!$("town-hud").classList.contains("hidden");controls.style.display=visible?"flex":"none";help.style.display=visible&&!matchMedia("(pointer:coarse)").matches?"block":"none";}
  document.querySelectorAll("#arcane-pad button").forEach(btn=>{
    const direction=btn.dataset.dir;
    const vector={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]}[direction];
    const down=e=>{e.preventDefault();window.arcaneMove.x=vector[0];window.arcaneMove.y=vector[1];btn.setPointerCapture?.(e.pointerId);btn.classList.add("selected");};
    const up=e=>{e.preventDefault();window.arcaneMove.x=0;window.arcaneMove.y=0;btn.classList.remove("selected");};
    btn.addEventListener("pointerdown",down);["pointerup","pointercancel","lostpointercapture"].forEach(ev=>btn.addEventListener(ev,up));
  });
  window.addEventListener("keydown",e=>{if(["ArrowUp","ArrowDown","ArrowLeft","ArrowRight"," "].includes(e.key))e.preventDefault();keys[e.key.toLowerCase()]=true;setKeyboardVector();});
  window.addEventListener("keyup",e=>{keys[e.key.toLowerCase()]=false;setKeyboardVector();});
  window.addEventListener("blur",()=>{keys={};window.arcaneMove.x=0;window.arcaneMove.y=0;});
  function setKeyboardVector(){const x=(keys.a||keys.arrowleft?-1:0)+(keys.d||keys.arrowright?1:0);const y=(keys.w||keys.arrowup?-1:0)+(keys.s||keys.arrowdown?1:0);if(x||y){window.arcaneMove.x=x;window.arcaneMove.y=y;}}
  $("arcane-interact").addEventListener("click",()=>{const target=$("story-talk");if(target)target.click();else if(window.arcaneSceneInteract)window.arcaneSceneInteract();});
  $("arcane-dodge").addEventListener("click",()=>{if(window.arcaneSceneAction)window.arcaneSceneAction("dodge");else pulse("arcane-dodge");});
  $("arcane-spell").addEventListener("click",()=>{if(window.arcaneSceneAction)window.arcaneSceneAction("spell");else pulse("arcane-spell");});
  function pulse(id){const b=$(id);b.animate([{transform:"scale(1)",filter:"brightness(1)"},{transform:"scale(.9)",filter:"brightness(1.8)"},{transform:"scale(1)",filter:"brightness(1)"}],{duration:220});}
  if($("town-hud"))new MutationObserver(sync).observe($("town-hud"),{attributes:true,attributeFilter:["class"]});
  sync();
})();