import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Built-in coaches (subset of data for preview pages)
const builtInCoaches: Record<string, { name: string; description: string; category: string; orbColors: string[] }> = {
  "marcus-productivity": {
    name: "Marcus",
    description: "Direct, energetic productivity coach who helps you prioritize ruthlessly and build unstoppable work habits.",
    category: "Productivity",
    orbColors: ["4F46E5", "7C3AED"],
  },
  "sage-mindset": {
    name: "Sage",
    description: "Calm, compassionate mindset coach who helps you reframe negative thoughts and find inner clarity through mindfulness.",
    category: "Mindset",
    orbColors: ["059669", "34D399"],
  },
  "james-career": {
    name: "James",
    description: "Strategic career coach with 20 years of experience helping professionals navigate transitions and negotiate with confidence.",
    category: "Career",
    orbColors: ["DC2626", "F97316"],
  },
  "aria-wellness": {
    name: "Aria",
    description: "Warm, evidence-based wellness coach who helps you build sustainable habits around sleep, nutrition, exercise, and stress.",
    category: "Health",
    orbColors: ["0891B2", "06B6D4"],
  },
  "nova-creativity": {
    name: "Nova",
    description: "Playful, boundary-pushing creativity coach who helps you smash through creative blocks and find your unique voice.",
    category: "Creativity",
    orbColors: ["D946EF", "F472B6"],
  },
  "victoria-executive": {
    name: "Victoria",
    description: "Elite executive coach who works with founders and leaders on strategic thinking, tough decisions, and leadership presence.",
    category: "Career",
    orbColors: ["1E293B", "475569"],
  },
};

interface CoachData {
  name: string;
  description: string;
  category: string;
  orbColors: string[];
}

async function getCoach(coachId: string): Promise<CoachData | null> {
  // Check built-in coaches first
  if (builtInCoaches[coachId]) {
    return builtInCoaches[coachId];
  }

  // Fetch from Firestore
  try {
    const doc = await db.collection("coaches").doc(coachId).get();
    if (!doc.exists) return null;
    const data = doc.data();
    if (!data || !data.isPublic) return null;
    return {
      name: data.name || "Coach",
      description: data.description || "",
      category: data.category ? data.category.charAt(0).toUpperCase() + data.category.slice(1) : "Custom",
      orbColors: data.orbColors || ["4F46E5", "7C3AED"],
    };
  } catch (err) {
    logger.error("Error fetching coach", { coachId, error: err });
    return null;
  }
}

function renderPage(coach: CoachData | null, coachId: string): string {
  if (!coach) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Council</title>
<meta property="og:title" content="Council">
<meta property="og:description" content="AI coaching at the right moment.">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',system-ui,sans-serif;background:#0A0A0A;color:#fff;min-height:100vh;display:flex;align-items:center;justify-content:center;text-align:center;padding:24px}
h1{font-size:28px;font-weight:700;margin-bottom:12px}
p{color:#888;font-size:16px;margin-bottom:32px}
a{display:inline-block;padding:14px 32px;background:#fff;color:#000;text-decoration:none;border-radius:12px;font-weight:600;font-size:16px}
</style>
</head>
<body>
<div>
<h1>Coach not found</h1>
<p>This coach may have been removed or is no longer available.</p>
<a href="https://apps.apple.com/app/council">Get Council</a>
</div>
</body>
</html>`;
  }

  const c1 = coach.orbColors[0] || "4F46E5";
  const c2 = coach.orbColors[1] || "7C3AED";
  const universalLink = `https://coachboard-app.web.app/coach/${coachId}`;
  const testFlightLink = "https://testflight.apple.com/join/council"; // TODO: Replace with real TestFlight link
  const escapedName = escapeHtml(coach.name);
  const escapedDesc = escapeHtml(coach.description);
  const escapedCategory = escapeHtml(coach.category);

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapedName} — Council</title>
<meta property="og:type" content="website">
<meta property="og:title" content="${escapedName} on Council">
<meta property="og:description" content="${escapedDesc}">
<meta property="og:url" content="${universalLink}">
<meta property="og:site_name" content="Council">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${escapedName} on Council">
<meta name="twitter:description" content="${escapedDesc}">
<meta name="apple-itunes-app" content="app-clip-bundle-id=athenlabs.Council, app-argument=${universalLink}">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',system-ui,sans-serif;background:#0A0A0A;color:#fff;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px}
.card{max-width:400px;width:100%;text-align:center}
.orb-container{width:180px;height:180px;margin:0 auto 32px;position:relative}
.orb-container canvas{width:100%!important;height:100%!important;border-radius:50%}
.badge{display:inline-block;padding:4px 12px;background:rgba(255,255,255,0.08);border-radius:20px;font-size:13px;color:#999;font-weight:500;margin-bottom:16px;letter-spacing:0.3px}
h1{font-size:32px;font-weight:700;margin-bottom:10px;letter-spacing:-0.5px}
.desc{color:#999;font-size:16px;line-height:1.5;margin-bottom:36px;padding:0 8px}
.btn{display:block;width:100%;padding:16px;background:#fff;color:#000;text-decoration:none;border-radius:14px;font-weight:600;font-size:17px;margin-bottom:12px;transition:transform 0.15s}
.btn:active{transform:scale(0.97)}
.btn-secondary{background:rgba(255,255,255,0.06);color:#fff;border:1px solid rgba(255,255,255,0.1)}
.footer{margin-top:32px;color:#555;font-size:13px}
</style>
</head>
<body>
<div class="card">
<div class="orb-container" id="orb"></div>
<div class="badge">${escapedCategory}</div>
<h1>${escapedName}</h1>
<p class="desc">${escapedDesc}</p>
<a class="btn" href="#" id="openApp" onclick="openInApp();return false">Open in Council</a>
<a class="btn btn-secondary" href="${testFlightLink}" id="getApp">Get Council on TestFlight</a>
<script>
function openInApp(){
  var scheme="coachboard://coach/${coachId}";
  var fallback="${testFlightLink}";
  var clicked=Date.now();
  window.location.href=scheme;
  setTimeout(function(){
    if(Date.now()-clicked<2000){
      document.getElementById("openApp").textContent="App not installed";
      document.getElementById("openApp").style.opacity="0.5";
      document.getElementById("getApp").style.background="#fff";
      document.getElementById("getApp").style.color="#000";
    }
  },1500);
}
</script>
<p class="footer">AI coaching at the right moment</p>
</div>
<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js"}}</script>
<script type="module">
import*as THREE from"three";

const vertexShader=\`
uniform float uTime;
varying vec2 vUv;
void main(){
  vUv=uv;
  gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);
}
\`;

const fragmentShader=\`
uniform float uTime;
uniform float uAnimation;
uniform float uInverted;
uniform float uOffsets[7];
uniform vec3 uColor1;
uniform vec3 uColor2;
uniform float uInputVolume;
uniform float uOutputVolume;
uniform float uOpacity;
uniform sampler2D uPerlinTexture;
varying vec2 vUv;

const float PI=3.14159265358979323846;

bool drawOval(vec2 polarUv,vec2 polarCenter,float a,float b,bool reverseGradient,float softness,out vec4 color){
  vec2 p=polarUv-polarCenter;
  float oval=(p.x*p.x)/(a*a)+(p.y*p.y)/(b*b);
  float edge=smoothstep(1.0,1.0-softness,oval);
  if(edge>0.0){
    float gradient=reverseGradient?(1.0-(p.x/a+1.0)/2.0):((p.x/a+1.0)/2.0);
    gradient=mix(0.5,gradient,0.1);
    color=vec4(vec3(gradient),0.85*edge);
    return true;
  }
  return false;
}

vec3 colorRamp(float g,vec3 c1,vec3 c2,vec3 c3,vec3 c4){
  if(g<0.33)return mix(c1,c2,g*3.0);
  else if(g<0.66)return mix(c2,c3,(g-0.33)*3.0);
  else return mix(c3,c4,(g-0.66)*3.0);
}

vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}

float noise2D(vec2 p){
  vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
  float n=mix(mix(dot(hash2(i+vec2(0,0)),f-vec2(0,0)),dot(hash2(i+vec2(1,0)),f-vec2(1,0)),u.x),
  mix(dot(hash2(i+vec2(0,1)),f-vec2(0,1)),dot(hash2(i+vec2(1,1)),f-vec2(1,1)),u.x),u.y);
  return 0.5+0.5*n;
}

float sharpRing(vec3 d,float t){
  float n=mix(noise2D(vec2(d.x,t)*5.0),noise2D(vec2(d.y,t)*5.0),d.z);
  return 1.0+(n-0.5)*2.5*0.3*1.5;
}

float smoothRing(vec3 d,float t){
  float n=mix(noise2D(vec2(d.x,t)*6.0),noise2D(vec2(d.y,t)*6.0),d.z);
  return 0.9+(n-0.5)*5.0*0.2;
}

float flow(vec3 d,float t){
  return mix(texture2D(uPerlinTexture,vec2(t,d.x/2.0)).r,texture2D(uPerlinTexture,vec2(t,d.y/2.0)).r,d.z);
}

void main(){
  vec2 uv=vUv*2.0-1.0;
  float radius=length(uv);
  float theta=atan(uv.y,uv.x);
  if(theta<0.0)theta+=2.0*PI;
  vec3 decomposed=vec3(theta/(2.0*PI),mod(theta/(2.0*PI)+0.5,1.0)+1.0,abs(theta/PI-1.0));
  float noise=flow(decomposed,radius*0.03-uAnimation*0.2)-0.5;
  theta+=noise*mix(0.08,0.25,uOutputVolume);
  vec4 color=vec4(1,1,1,1);
  float originalCenters[7];
  originalCenters[0]=0.0;originalCenters[1]=0.5*PI;originalCenters[2]=1.0*PI;
  originalCenters[3]=1.5*PI;originalCenters[4]=2.0*PI;originalCenters[5]=2.5*PI;originalCenters[6]=3.0*PI;
  float centers[7];
  for(int i=0;i<7;i++){centers[i]=originalCenters[i]+0.5*sin(uTime/20.0+uOffsets[i]);}
  float a,b;vec4 ovalColor;
  for(int i=0;i<7;i++){
    float n=texture2D(uPerlinTexture,vec2(mod(centers[i]+uTime*0.05,1.0),0.5)).r;
    a=0.5+n*0.3;b=n*mix(3.5,2.5,uInputVolume);
    bool rev=(i/2*2!=i);
    float distTheta=min(abs(theta-centers[i]),min(abs(theta+2.0*PI-centers[i]),abs(theta-2.0*PI-centers[i])));
    if(drawOval(vec2(distTheta,radius),vec2(0,0),a,b,rev,0.6,ovalColor)){
      color.rgb=mix(color.rgb,ovalColor.rgb,ovalColor.a);
      color.a=max(color.a,ovalColor.a);
    }
  }
  float r1=sharpRing(decomposed,uTime*0.1);float r2=smoothRing(decomposed,uTime*0.1);
  float ir1=radius+uInputVolume*0.2;float ir2=radius+uInputVolume*0.15;
  float o1=mix(0.2,0.6,uInputVolume);float o2=mix(0.15,0.45,uInputVolume);
  float ra1=(ir2>=r1)?o1:0.0;float ra2=smoothstep(r2-0.05,r2+0.05,ir1)*o2;
  float tra=max(ra1,ra2);
  color.rgb=1.0-(1.0-color.rgb)*(1.0-vec3(1)*tra);
  float lum=mix(color.r,1.0-color.r,uInverted);
  color.rgb=colorRamp(lum,vec3(0),uColor1,uColor2,vec3(1));
  color.a*=uOpacity;
  gl_FragColor=color;
}
\`;

function splitmix32(a){return function(){a|=0;a=(a+0x9e3779b9)|0;let t=a^(a>>>16);t=Math.imul(t,0x21f0aaad);t=t^(t>>>15);t=Math.imul(t,0x735a2d97);return((t=t^(t>>>15))>>>0)/4294967296};}

const container=document.getElementById("orb");
const size=180*window.devicePixelRatio;
const scene=new THREE.Scene();
const camera=new THREE.OrthographicCamera(-3.5,3.5,3.5,-3.5,0.1,10);
camera.position.z=1;
const renderer=new THREE.WebGLRenderer({alpha:true,antialias:true,premultipliedAlpha:true});
renderer.setSize(size,size);
renderer.setPixelRatio(1);
container.appendChild(renderer.domElement);

const rand=splitmix32(42);
const offsets=new Float32Array(Array.from({length:7},()=>rand()*Math.PI*2));

const loader=new THREE.TextureLoader();
loader.load("https://storage.googleapis.com/eleven-public-cdn/images/perlin-noise.png",function(tex){
  tex.wrapS=THREE.RepeatWrapping;
  tex.wrapT=THREE.RepeatWrapping;
  const uniforms={
    uColor1:{value:new THREE.Color("#${c1}")},
    uColor2:{value:new THREE.Color("#${c2}")},
    uOffsets:{value:offsets},
    uPerlinTexture:{value:tex},
    uTime:{value:0},
    uAnimation:{value:0.1},
    uInverted:{value:1},
    uInputVolume:{value:0},
    uOutputVolume:{value:0.3},
    uOpacity:{value:0}
  };
  const mat=new THREE.ShaderMaterial({uniforms,vertexShader,fragmentShader,transparent:true});
  const mesh=new THREE.Mesh(new THREE.CircleGeometry(3.5,64),mat);
  scene.add(mesh);
  let last=0;
  function animate(t){
    requestAnimationFrame(animate);
    const delta=(t-last)/1000;last=t;
    const u=uniforms;
    u.uTime.value+=delta*0.5;
    u.uAnimation.value+=delta*0.1;
    if(u.uOpacity.value<1)u.uOpacity.value=Math.min(1,u.uOpacity.value+delta*2);
    renderer.render(scene,camera);
  }
  requestAnimationFrame(animate);
});
<\/script>
</body>
</html>`;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function hexToRgb(hex: string): string {
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  return `${r},${g},${b}`;
}

export const coachPreview = onRequest({ cors: true }, async (req, res) => {
  // Extract coachId from path: /coach/{coachId}
  const path = req.path.replace(/^\/+|\/+$/g, "");
  const segments = path.split("/");

  // Path should be "coach/{coachId}" after Firebase Hosting rewrite
  let coachId: string | undefined;
  if (segments.length >= 2 && segments[0] === "coach") {
    coachId = segments[1];
  } else if (segments.length === 1 && segments[0]) {
    // Direct function call with just the ID
    coachId = segments[0];
  }

  if (!coachId) {
    res.status(404).send(renderPage(null, ""));
    return;
  }

  logger.info("Coach preview requested", { coachId });
  const coach = await getCoach(coachId);
  res.status(coach ? 200 : 404).send(renderPage(coach, coachId));
});
