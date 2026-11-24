// The Paddle Review — page backdrop.
// A transparent overlay drawn above the page, so the page keeps its own paper / ink
// background and a missing or stale canvas can never hide any text. Output is premultiplied alpha.
//   paper  : fibre + mottling + faint vignette (ink=0, every light page, static)
//   cover  : slow oxblood ink wash that creeps in from the page edges (page 01)
//   ember  : drifting oxblood heat and rising specks over the dark page (ink=1, Coach's Corner)
// Everything is kept low-alpha so the text underneath stays the hero.

struct Params {
  time: f32,
  ink: f32,     // 0 = overlay for the paper pages, 1 = overlay for the ink page
  wCover: f32,  // 0..1 ink-wash strength (eased in JS)
  wEmber: f32,  // 0..1 ember strength (eased in JS)
  res: vec2f,   // surface size in device pixels
  ptr: vec2f,   // pointer in 0..1 uv (top-left origin)
  ptrW: f32,    // pointer influence 0..1
  dpr: f32,
}
@group(0) @binding(0) var<uniform> params: Params;

const PAPER = vec3f(0.9569, 0.9412, 0.9059); // #F4F0E7
const INK   = vec3f(0.0863, 0.0824, 0.0745); // #161513
const RED   = vec3f(0.6392, 0.1922, 0.1137); // #A3311D

fn hash21(q: vec2f) -> f32 {
  var p3 = fract(vec3f(q.x, q.y, q.x) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

fn vnoise(x: vec2f) -> f32 {
  let i = floor(x);
  let f = fract(x);
  let u = f * f * (3.0 - 2.0 * f);
  let a = hash21(i);
  let b = hash21(i + vec2f(1.0, 0.0));
  let c = hash21(i + vec2f(0.0, 1.0));
  let d = hash21(i + vec2f(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn fbm(x: vec2f) -> f32 {
  var amp = 0.5;
  var sum = 0.0;
  var q = x;
  for (var i = 0; i < 5; i++) {
    sum += amp * vnoise(q);
    q = q * 2.03 + vec2f(17.1, 9.2);
    amp *= 0.5;
  }
  return sum;
}

// Rising specks: one candidate per cell, drifting upward, most cells empty.
fn specks(px: vec2f, t: f32) -> f32 {
  let cell = 84.0;
  var acc = 0.0;
  for (var layer = 0; layer < 2; layer++) {
    let fl = f32(layer);
    let size = cell * (1.0 + fl * 0.7);
    var q = px / size;
    q.y += t * (0.035 + fl * 0.02);
    let id = floor(q);
    let h = hash21(id + fl * 31.7);
    if (h > 0.72) {
      let jitter = vec2f(hash21(id + 3.1), hash21(id + 7.7));
      let local = fract(q) - jitter * 0.8 - 0.1;
      let d = length(local) * size;
      let tw = 0.55 + 0.45 * sin(t * (0.6 + h * 1.4) + h * 40.0);
      acc += smoothstep(2.2, 0.0, d) * tw * (0.5 + 0.5 * h);
    }
  }
  return acc;
}

fn over(top: vec4f, bottom: vec4f) -> vec4f {
  return top + bottom * (1.0 - top.a);
}

@fragment fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let t = params.time;
  let px = uv * params.res / params.dpr;               // css-pixel coordinates
  let asp = params.res.x / params.res.y;
  let q = (uv - 0.5) * vec2f(asp, 1.0);                 // aspect-correct, centred
  let corner = length(q * vec2f(0.82, 1.08));           // ~0 centre, ~1 corners
  let pix = floor(uv * params.res);
  let tooth = hash21(pix) - 0.5;
  let pd = length((uv - params.ptr) * vec2f(asp, 1.0));

  var outc = vec4f(0.0);

  if (params.ink < 0.5) {
    // ---- paper stock: signed lightness variation as a dark and a light layer ----
    let mottle = fbm(px * 0.018) - 0.5;
    let ang = 0.6;
    let r = vec2f(px.x * cos(ang) - px.y * sin(ang), px.x * sin(ang) + px.y * cos(ang));
    let r2 = vec2f(px.x * cos(-1.1) - px.y * sin(-1.1), px.x * sin(-1.1) + px.y * cos(-1.1));
    let fibre = (vnoise(r * vec2f(0.11, 0.9)) + vnoise(r2 * vec2f(0.14, 0.7)) - 1.0);
    let stock = tooth * 0.016 + mottle * 0.034 + fibre * 0.010;
    let vig = 0.035 * smoothstep(0.5, 1.15, corner);

    // ---- cover: ink wash creeping in from the edges ---------------------------
    let warp = vec2f(fbm(q * 1.7 + vec2f(t * 0.016, 3.0)), fbm(q * 1.7 + vec2f(8.0, -t * 0.019)));
    let bloom = exp(-pd * pd * 7.0) * params.ptrW;                       // wash leans toward the cursor
    let n = fbm(q * 1.35 + warp * 1.7) + bloom * 0.16;
    let edge = smoothstep(0.42, 1.02, corner);                           // quiet in the middle, stronger at the rim
    let stain = smoothstep(0.50, 0.78, n + edge * 0.36 - 0.17);
    let contour = smoothstep(0.011, 0.0, abs(n + edge * 0.18 - 0.60)) * edge;
    let washA = clamp(stain * 0.14 + contour * 0.08, 0.0, 0.21) * params.wCover;
    let washCol = mix(RED, RED * 0.55, smoothstep(0.55, 0.95, n));
    outc = vec4f(washCol * washA, washA);

    let darkA = clamp(-stock, 0.0, 1.0) + vig;                           // black layer
    let lightA = clamp(stock, 0.0, 1.0);                                 // white layer
    outc = over(vec4f(0.0, 0.0, 0.0, darkA), outc);
    outc = over(vec4f(lightA, lightA, lightA, lightA), outc);
  } else {
    // ---- ember: drifting heat over the ink page -------------------------------
    let w2 = vec2f(fbm(q * 1.4 + vec2f(2.0, t * 0.030)), fbm(q * 1.4 + vec2f(-t * 0.024, 6.0)));
    let e = fbm(q * vec2f(1.15, 1.75) + vec2f(0.0, -t * 0.045) + w2 * 1.5);
    let rise = smoothstep(0.05, 1.0, uv.y);                              // heat gathers at the foot of the page
    let heat = pow(clamp(e * 1.7 - 0.42, 0.0, 1.0), 1.4) * (0.35 + 0.65 * rise);
    let sideGlow = 0.45 * exp(-pow((uv.x - 0.88) * 2.2, 2.0)) * (0.25 + 0.75 * rise);
    let hotA = clamp(heat * 0.52 + sideGlow * heat * 0.4, 0.0, 0.5) * params.wEmber * 0.60;
    let hotCol = RED * vec3f(1.08, 0.92, 0.80);
    outc = vec4f(hotCol * hotA, hotA);

    let spA = clamp(specks(px, t) * params.wEmber * (0.2 + 0.8 * rise) * 0.34, 0.0, 0.5);
    outc = over(vec4f(vec3f(0.90, 0.46, 0.35) * spA, spA), outc);
    let pg = exp(-pd * pd * 6.0) * params.ptrW * params.wEmber * 0.10;
    outc = over(vec4f(RED * pg, pg), outc);

    let grain = hash21(pix + floor(t * 24.0) * 17.0) - 0.5;
    let gA = clamp(grain, 0.0, 1.0) * 0.044;                             // light film grain
    outc = over(vec4f(gA, gA, gA, gA), outc);
    let vA = 0.18 * smoothstep(0.55, 1.2, corner);
    outc = over(vec4f(0.0, 0.0, 0.0, vA), outc);
  }
  return clamp(outc, vec4f(0.0), vec4f(1.0));
}
