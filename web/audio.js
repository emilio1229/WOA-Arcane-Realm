(()=>{"use strict";
const STORE="woa-music-enabled-v1";
let enabled=false,ctx=null,master=null,activeNodes=[],timer=null,mode="menu",step=0;
try{enabled=localStorage.getItem(STORE)==="1"}catch(_){}
const $=id=>document.getElementById(id);
function build(){
 if(ctx)return;
 const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return;
 ctx=new AC();master=ctx.createGain();master.gain.value=0;master.connect(ctx.destination);
}
function tone(freq,start,duration,volume,wave="sine",detune=0){
 if(!ctx||!master)return;
 const osc=ctx.createOscillator(),gain=ctx.createGain(),filter=ctx.createBiquadFilter();
 osc.type=wave;osc.frequency.setValueAtTime(freq,start);osc.detune.value=detune;
 filter.type="lowpass";filter.frequency.setValueAtTime(Math.min(2400,freq*4),start);filter.Q.value=.4;
 gain.gain.setValueAtTime(.0001,start);gain.gain.exponentialRampToValueAtTime(Math.max(.0002,volume),start+.45);gain.gain.setTargetAtTime(.0001,start+duration*.55,Math.max(.12,duration*.18));
 osc.connect(filter);filter.connect(gain);gain.connect(master);osc.start(start);osc.stop(start+duration+1);
 activeNodes.push(osc);osc.onended=()=>{activeNodes=activeNodes.filter(n=>n!==osc)};
}
const scales={menu:[130.81,155.56,196,233.08,261.63,311.13,392],town:[98,130.81,146.83,196,220,261.63,293.66,392],battle:[110,130.81,164.81,196,220,261.63,329.63]};
function tick(){
 if(!enabled||!ctx||ctx.state!=="running")return;
 const now=ctx.currentTime,notes=scales[mode]||scales.menu;
 // A newly composed, slow modal fantasy motif: layered fifths and gentle pentatonic chimes.
 if(step%4===0){const root=mode==="battle"?110:mode==="town"?98:130.81;tone(root,now,5,mode==="battle"?.055:.035,"sine");tone(root*1.5,now+.03,4,.018,"sine",2)}
 if(step%2===0){const idx=(Math.floor(step/2)*3+(mode==="town"?1:0))%notes.length;tone(notes[idx]*2,now+.08,3.1,mode==="battle"?.024:.014,"sine",((step%3)-1)*3)}
 if(mode==="battle"&&step%4===2)tone(notes[(step+2)%notes.length],now+.04,1.2,.018,"triangle");
 step++;timer=setTimeout(tick,mode==="battle"?850:1450);
}
function setMode(next){mode=next||"menu";if(timer){clearTimeout(timer);timer=null}step=0;if(enabled&&ctx&&ctx.state==="running")tick()}
function syncButtons(){
 const title=$("music-toggle-title");if(title){title.textContent=enabled?"♫ Music on":"♫ Music off";title.setAttribute("aria-pressed",String(enabled))}
 const menu=$("music-toggle");if(menu){menu.setAttribute("aria-pressed",String(enabled));const label=menu.querySelector("b"),small=menu.querySelector("small"),status=$("music-status");if(label)label.textContent=enabled?"Soundtrack · On":"Soundtrack · Off";if(small)small.textContent=enabled?"Original ambient score is playing":"Turn the original ambient music on";if(status)status.textContent=enabled?"♪":"›"}
}
async function setEnabled(value){
 enabled=!!value;
 try{localStorage.setItem(STORE,enabled?"1":"0")}catch(_){}
 syncButtons();
 if(!enabled){if(timer){clearTimeout(timer);timer=null}if(ctx&&master)master.gain.setTargetAtTime(.0001,ctx.currentTime,.18);return}
 build();if(!ctx||!master){enabled=false;syncButtons();return}
 try{await ctx.resume();master.gain.cancelScheduledValues(ctx.currentTime);master.gain.setTargetAtTime(.22,ctx.currentTime,.9);setMode(mode)}catch(_){enabled=false;syncButtons()}
}
function toggle(){setEnabled(!enabled)}
window.arcaneMusic={setMode,toggle,setEnabled,isEnabled:()=>enabled};
document.addEventListener("DOMContentLoaded",()=>{
 const title=$("music-toggle-title"),menu=$("music-toggle");
 if(title)title.addEventListener("click",toggle);if(menu)menu.addEventListener("click",toggle);
 syncButtons();
 // Browsers require a user gesture before audio can begin. Start only if previously enabled.
 document.addEventListener("pointerdown",()=>{if(enabled){build();if(ctx&&ctx.state==="suspended")ctx.resume().then(()=>{if(master){master.gain.setTargetAtTime(.22,ctx.currentTime,.9);setMode(mode)}})}},{once:true,passive:true});
 const modal=$("woa-world-modal"),tag=$("woa-world-tag");
 if(modal&&tag){new MutationObserver(()=>{if(modal.style.display==="grid"&&/ENCOUNTER|BATTLE/i.test(tag.textContent))setMode("battle");else if($("town-hud")&&!$("town-hud").classList.contains("hidden"))setMode("town")}).observe(modal,{attributes:true,attributeFilter:["style"],childList:true,subtree:true});}
 const hud=$("town-hud");if(hud)new MutationObserver(()=>{if(!hud.classList.contains("hidden"))setMode("town")}).observe(hud,{attributes:true,attributeFilter:["class"]});
});
window.addEventListener("pagehide",()=>{if(timer)clearTimeout(timer);if(ctx)ctx.close().catch(()=>{})});
})();