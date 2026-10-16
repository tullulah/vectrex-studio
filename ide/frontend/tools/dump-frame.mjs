import { Rp2350System } from './.rp2350emu-built.mjs';
import fs from 'node:fs';
if (process.env.NOCLIP) globalThis.__NOCLIP = 1;
if (process.env.KEEPZ0) globalThis.__KEEPZ0 = 1;
const path = process.argv[2];
const targetFrame = parseInt(process.argv[3] || '60', 10);
const bin = new Uint8Array(fs.readFileSync(path));
const sys = new Rp2350System();
const _log = console.log; console.log = () => {};
sys.initRamGame(bin);
console.log = _log;

let segs = [];
for (let f = 0; f <= targetFrame; f++) segs = sys.runFrame();

// stats
let minx=1e9,maxx=-1e9,miny=1e9,maxy=-1e9; const cols={};
for (const s of segs){
  minx=Math.min(minx,s.x0,s.x1); maxx=Math.max(maxx,s.x0,s.x1);
  miny=Math.min(miny,s.y0,s.y1); maxy=Math.max(maxy,s.y0,s.y1);
  cols[s.color]=(cols[s.color]||0)+1;
}
console.log(`frame ${targetFrame}: ${segs.length} segs  X[${minx|0},${maxx|0}] Y[${miny|0},${maxy|0}]`);
console.log('colors:', JSON.stringify(cols));

// ASCII raster 80x40 over the emulator clip box [0,33000]x[0,41000]
const W=90,H=44; const grid=Array.from({length:H},()=>Array(W).fill(' '));
const CX0=0,CX1=33000,CY0=0,CY1=41000;
function plot(x,y,ch){
  const gx=Math.round((x-CX0)/(CX1-CX0)*(W-1));
  const gy=Math.round((1-(y-CY0)/(CY1-CY0))*(H-1));
  if(gx>=0&&gx<W&&gy>=0&&gy<H) grid[gy][gx]=ch;
}
for(const s of segs){
  const n=Math.max(Math.abs(s.x1-s.x0),Math.abs(s.y1-s.y0))/500|0;
  const steps=Math.max(1,n);
  const ch = s.color>=64?'#':(s.color>=16?'+':'.');
  for(let i=0;i<=steps;i++){ plot(s.x0+(s.x1-s.x0)*i/steps, s.y0+(s.y1-s.y0)*i/steps, ch); }
}
console.log('+'+'-'.repeat(W)+'+');
for(const row of grid) console.log('|'+row.join('')+'|');
console.log('+'+'-'.repeat(W)+'+');
