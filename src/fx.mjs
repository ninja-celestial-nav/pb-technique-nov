// The Paddle Review — WebGPU page backdrop (progressive enhancement).
// Without WebGPU, or on any error, nothing here runs and the plain CSS page is untouched.
import { init, surface, effect, frame, frameLoop, clock } from "vgpu";
import shader from "./fx.shader.json";

const body = document.body;
const canvas = document.getElementById("fx");

async function start() {
  if (!canvas || !navigator.gpu) return;
  const reduce = !!(window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches);

  const gpu = await init();
  const surf = surface(gpu, canvas, { dpr: [1, 1.5], alphaMode: "premultiplied", clearColor: [0, 0, 0, 0] });
  const clk = clock(gpu);
  const fx = effect(gpu, shader, {
    set: { params: { time: 0, ink: 0, wCover: 0, wEmber: 0, res: [1, 1], ptr: [0.5, 0.5], ptrW: 0, dpr: 1 } },
  });
  surf.onResize((e) => { fx.set({ params: { res: [e.width, e.height], dpr: e.dpr } }); });

  const want = { ink: 0, cover: 0, ember: 0 };
  const cur = { cover: 0, ember: 0 };
  const ptr = { x: 0.5, y: 0.5, tx: 0.5, ty: 0.5, w: 0, tw: 0 };
  let handle = null;
  let alive = true;
  let shown = false;
  let frames = 0;

  function fail() {
    alive = false;
    try { if (handle) handle.stop(); } catch (e) {}
    handle = null;
    body.classList.remove("fx");
    canvas.style.display = "none";
  }

  function encode(f, dt) {
    if (reduce) { cur.cover = want.cover; cur.ember = want.ember; }
    else {
      const k = 1 - Math.exp(-dt / 0.55);
      cur.cover += (want.cover - cur.cover) * k;
      cur.ember += (want.ember - cur.ember) * k;
      const kp = 1 - Math.exp(-dt / 0.18);
      ptr.x += (ptr.tx - ptr.x) * kp; ptr.y += (ptr.ty - ptr.y) * kp; ptr.w += (ptr.tw - ptr.w) * kp;
    }
    fx.set({ params: {
      time: reduce ? 0 : clk.time, ink: want.ink, wCover: cur.cover, wEmber: cur.ember,
      ptr: [ptr.x, ptr.y], ptrW: reduce ? 0 : ptr.w,
    } });
    f.pass(surf, fx);
    frames++;
    if (!shown) { shown = true; body.classList.add("fx"); }
  }

  function settled() {
    return Math.abs(want.cover - cur.cover) < 0.004 && Math.abs(want.ember - cur.ember) < 0.004 &&
      ptr.w < 0.01 && ptr.tw === 0 && want.cover === 0 && want.ember === 0;
  }

  function drawOnce() {
    if (!alive) return;
    try { frame(gpu, (f) => encode(f, 1 / 30)); } catch (e) { fail(); }
  }

  function run() {
    if (!alive || reduce || handle) return;
    handle = frameLoop(gpu, (f) => {
      try {
        encode(f, Math.min(clk.deltaTime || 1 / 30, 0.1));
        if (settled()) { const h = handle; handle = null; if (h) h.stop(); }
      } catch (e) { fail(); }
    }, { fps: 30 });
  }

  function setMode(mode) {
    if (!alive) return;
    const dark = mode === "dark";
    want.ink = dark ? 1 : 0;
    want.cover = mode === "cover" ? 1 : 0;
    want.ember = dark ? 1 : 0;
    ptr.tw = (mode === "cover" || dark) ? ptr.tw : 0;
    drawOnce();      // same task as the DOM change, so both reach the screen together
    run();
  }

  window.addEventListener("pointermove", (e) => {
    if (!alive || reduce || e.pointerType === "touch") return;
    const m = body.getAttribute("data-fx");
    if (m !== "cover" && m !== "dark") return;
    const r = canvas.getBoundingClientRect();
    if (!r.width || !r.height) return;
    ptr.tx = (e.clientX - r.left) / r.width; ptr.ty = (e.clientY - r.top) / r.height; ptr.tw = 1;
    run();
  }, { passive: true });
  document.addEventListener("pointerleave", () => { ptr.tw = 0; run(); });

  let rz = 0;
  window.addEventListener("resize", () => {
    if (rz) return;
    rz = requestAnimationFrame(() => { rz = 0; if (!handle) drawOnce(); });
  });

  window.PR_FX = { set: setMode, get frames() { return frames; } };
  setMode(body.getAttribute("data-fx") || "plain");
}

start().catch(() => { /* WebGPU unavailable or init failed: keep the plain page */ });
