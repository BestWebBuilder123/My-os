import express from "express";
import { chromium } from "playwright";
import crypto from "node:crypto";
import net from "node:net";

const app = express();
app.use(express.json({ limit: "16kb" }));
const sessions = new Map();
const key = process.env.BROWSER_API_KEY || "";
const port = Number(process.env.PORT || 10000);

app.use((req,res,next) => {
  const origin = req.headers.origin || "";
  if (origin) { res.setHeader("Access-Control-Allow-Origin", origin); res.setHeader("Vary","Origin"); }
  res.setHeader("Access-Control-Allow-Headers","Content-Type, X-Browser-Key");
  res.setHeader("Access-Control-Allow-Methods","GET,POST,DELETE,OPTIONS");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});
app.get("/health",(_req,res)=>res.json({ok:true}));
app.use("/api",(req,res,next)=>{
  if (!key || req.get("X-Browser-Key") !== key) return res.status(401).json({error:"Invalid browser key"});
  next();
});
function publicUrl(raw) {
  const u = new URL(String(raw || ""));
  if (!["http:","https:"].includes(u.protocol) || u.username || u.password) throw Error("Only public HTTP(S) addresses are allowed.");
  const h = u.hostname.toLowerCase();
  if (h==="localhost" || h.endsWith(".localhost") || h.endsWith(".local") || h.endsWith(".internal")) throw Error("Local addresses are blocked.");
  if (net.isIP(h)) {
    const p=h.split(".").map(Number);
    if (h==="::1" || h==="::" || (p.length===4 && (p[0]===10 || p[0]===127 || p[0]===0 || (p[0]===192&&p[1]===168) || (p[0]===172&&p[1]>=16&&p[1]<=31) || (p[0]===169&&p[1]===254)))) throw Error("Private network addresses are blocked.");
  }
  return u.href;
}
let browser;
async function getBrowser(){ if(!browser || !browser.isConnected()) browser=await chromium.launch({headless:true,args:["--no-sandbox","--disable-dev-shm-usage"]}); return browser; }
function find(id){ const s=sessions.get(id); if(s)s.used=Date.now(); return s; }

app.post("/api/sessions",async(_req,res)=>{
 try{
  if(sessions.size>=5)return res.status(429).json({error:"Browser is busy."});
  const context=await (await getBrowser()).newContext({viewport:{width:1280,height:800}});
  const page=await context.newPage();
  const id=crypto.randomBytes(24).toString("hex");
  sessions.set(id,{context,page,used:Date.now()});
  res.json({id});
 }catch(e){res.status(500).json({error:"Could not start Chromium: "+e.message});}
});
app.post("/api/sessions/:id/navigate",async(req,res)=>{
 const s=find(req.params.id); if(!s)return res.status(404).json({error:"Tab expired."});
 try{const url=publicUrl(req.body.url);await s.page.goto(url,{waitUntil:"domcontentloaded",timeout:25000});res.json({url:s.page.url(),title:await s.page.title()});}
 catch(e){res.status(400).json({error:e.message||"Navigation failed."});}
});
app.get("/api/sessions/:id/screenshot",async(req,res)=>{
 const s=find(req.params.id);if(!s)return res.status(404).json({error:"Tab expired."});
 try{res.set("Content-Type","image/jpeg").set("Cache-Control","no-store").send(await s.page.screenshot({type:"jpeg",quality:65}));}
 catch{res.status(500).json({error:"Screenshot unavailable."});}
});
app.post("/api/sessions/:id/action",async(req,res)=>{
 const s=find(req.params.id);if(!s)return res.status(404).json({error:"Tab expired."});
 try{
  const a=req.body||{};
  if(a.type==="click")await s.page.mouse.click(Math.max(0,Math.min(1279,Number(a.x)||0)),Math.max(0,Math.min(799,Number(a.y)||0)));
  else if(a.type==="type")await s.page.keyboard.type(String(a.text||"").slice(0,1000));
  else if(a.type==="key"&&["Enter","Tab","Escape","Backspace","ArrowUp","ArrowDown","ArrowLeft","ArrowRight","PageDown","PageUp"].includes(a.key))await s.page.keyboard.press(a.key);
  else if(a.type==="scroll")await s.page.mouse.wheel(0,Math.max(-1000,Math.min(1000,Number(a.deltaY)||0)));
  else return res.status(400).json({error:"Unsupported action."});
  res.json({ok:true,url:s.page.url(),title:await s.page.title().catch(()=>"")});
 }catch(e){res.status(400).json({error:"Action failed: "+e.message});}
});
app.delete("/api/sessions/:id",async(req,res)=>{const s=sessions.get(req.params.id);if(s){sessions.delete(req.params.id);await s.context.close().catch(()=>{});}res.json({ok:true});});
setInterval(()=>{for(const [id,s] of sessions)if(Date.now()-s.used>15*60*1000){sessions.delete(id);s.context.close().catch(()=>{});}},60000).unref();
app.listen(port,"0.0.0.0",()=>console.log("My OS Browser backend ready on "+port));
