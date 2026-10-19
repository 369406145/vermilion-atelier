import type { BrushSpec, PaperId } from "@/lib/ink/model";

export function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}

export function hexToRgb(hex: string): [number, number, number] {
  const n = hex.replace("#", "");
  const full = n.length === 3 ? n.split("").map((c) => c + c).join("") : n;
  return [
    parseInt(full.slice(0, 2), 16),
    parseInt(full.slice(2, 4), 16),
    parseInt(full.slice(4, 6), 16),
  ];
}

export function rgbToHex(r: number, g: number, b: number) {
  return (
    "#" +
    [r, g, b]
      .map((v) => clamp(Math.round(v), 0, 255).toString(16).padStart(2, "0"))
      .join("")
  );
}

export function rgbToHsv(r: number, g: number, b: number) {
  const rr = r / 255;
  const gg = g / 255;
  const bb = b / 255;
  const max = Math.max(rr, gg, bb);
  const min = Math.min(rr, gg, bb);
  const d = max - min;
  let h = 0;
  if (d !== 0) {
    if (max === rr) h = ((gg - bb) / d) % 6;
    else if (max === gg) h = (bb - rr) / d + 2;
    else h = (rr - gg) / d + 4;
    h *= 60;
    if (h < 0) h += 360;
  }
  return { h, s: max === 0 ? 0 : d / max, v: max };
}

export function hsvToRgb(h: number, s: number, v: number) {
  const c = v * s;
  const hp = (((h % 360) + 360) % 360) / 60;
  const x = c * (1 - Math.abs((hp % 2) - 1));
  let r = 0;
  let g = 0;
  let b = 0;
  if (hp < 1) [r, g, b] = [c, x, 0];
  else if (hp < 2) [r, g, b] = [x, c, 0];
  else if (hp < 3) [r, g, b] = [0, c, x];
  else if (hp < 4) [r, g, b] = [0, x, c];
  else if (hp < 5) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const m = v - c;
  return {
    r: Math.round((r + m) * 255),
    g: Math.round((g + m) * 255),
    b: Math.round((b + m) * 255),
  };
}

function rgba(hex: string, alpha: number) {
  const [r, g, b] = hexToRgb(hex);
  return `rgba(${r},${g},${b},${alpha})`;
}

export function blankLayer(w: number, h: number) {
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  return c;
}

export function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("Could not read that picture."));
    img.src = src;
  });
}

export async function layerFromPng(src: string, w: number, h: number) {
  const layer = blankLayer(w, h);
  const img = await loadImage(src);
  layer.getContext("2d")!.drawImage(img, 0, 0, w, h);
  return layer;
}

export async function drawContain(layer: HTMLCanvasElement, src: string) {
  const img = await loadImage(src);
  const ctx = layer.getContext("2d")!;
  const s = Math.min(layer.width / img.width, layer.height / img.height);
  const w = img.width * s;
  const h = img.height * s;
  ctx.drawImage(img, (layer.width - w) / 2, (layer.height - h) / 2, w, h);
}

export function renderPaper(w: number, h: number, paper: PaperId) {
  const c = blankLayer(w, h);
  const ctx = c.getContext("2d")!;
  const base = paper === "silk" ? "#efe2cc" : paper === "coarse" ? "#f1e6d4" : "#f7f3ea";
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, w, h);
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  const amp = paper === "plain" ? 5 : paper === "coarse" ? 20 : paper === "silk" ? 9 : 13;
  let seed = 17 + w + h + paper.length * 13;
  const rnd = () => {
    seed = (seed * 16807 + 11) % 2147483647;
    return seed / 2147483647;
  };
  for (let i = 0; i < d.length; i += 4) {
    const n = (rnd() - 0.5) * amp;
    d[i] = clamp(d[i] + n, 0, 255);
    d[i + 1] = clamp(d[i + 1] + n * 0.94, 0, 255);
    d[i + 2] = clamp(d[i + 2] + n * 0.82, 0, 255);
  }
  ctx.putImageData(img, 0, 0);
  if (paper !== "plain") {
    ctx.strokeStyle = paper === "coarse" ? "rgba(90,64,32,0.09)" : "rgba(110,82,46,0.05)";
    ctx.lineWidth = 1;
    const fibers = paper === "coarse" ? 70 : 36;
    for (let i = 0; i < fibers; i++) {
      const x = rnd() * w;
      const y = rnd() * h;
      const len = 4 + rnd() * (paper === "coarse" ? 16 : 10);
      const ang = rnd() * Math.PI;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + Math.cos(ang) * len, y + Math.sin(ang) * 0.45 * len);
      ctx.stroke();
    }
  }
  return c;
}

export function stamp(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  radius: number,
  color: string,
  alpha: number,
  hard: number,
  erase: boolean,
  dry: boolean,
) {
  const r = Math.max(radius, 0.4);
  ctx.save();
  ctx.globalCompositeOperation = erase ? "destination-out" : "source-over";
  if (dry) {
    const count = 7 + Math.round(r / 4);
    for (let i = 0; i < count; i++) {
      const ang = Math.random() * Math.PI * 2;
      const dist = Math.random() * r;
      const sr = Math.max(0.4, r * (0.06 + Math.random() * 0.14));
      ctx.globalAlpha = alpha * (0.2 + Math.random() * 0.7);
      ctx.fillStyle = erase ? "rgba(0,0,0,1)" : color;
      ctx.beginPath();
      ctx.arc(x + Math.cos(ang) * dist, y + Math.sin(ang) * dist, sr, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
    return;
  }
  const inner = Math.max(0, r * hard * 0.9);
  const g = ctx.createRadialGradient(x, y, inner, x, y, r);
  g.addColorStop(0, erase ? `rgba(0,0,0,${alpha})` : rgba(color, alpha));
  g.addColorStop(1, erase ? "rgba(0,0,0,0)" : rgba(color, 0));
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

export function paintSegment(
  ctx: CanvasRenderingContext2D,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  brush: BrushSpec,
  radius: number,
  color: string,
  flow: number,
  erase: boolean,
  mirrorX?: number,
) {
  const dist = Math.hypot(x2 - x1, y2 - y1);
  const speedR =
    brush.kind === "speed" ? radius * clamp(14 / Math.max(dist, 0.8), 0.2, 1.45) : radius;
  const step = Math.max(0.7, speedR * brush.spacing);
  const n = Math.max(1, Math.ceil(dist / step));
  const alpha = clamp(flow * brush.baseFlow, 0.02, 1);
  for (let i = 0; i <= n; i++) {
    const t = n === 0 ? 0 : i / n;
    const x = x1 + (x2 - x1) * t;
    const y = y1 + (y2 - y1) * t;
    stamp(ctx, x, y, speedR, color, alpha, brush.hard, erase, brush.kind === "dry" && !erase);
    if (mirrorX !== undefined) {
      stamp(ctx, mirrorX - x, y, speedR, color, alpha, brush.hard, erase, brush.kind === "dry" && !erase);
    }
  }
}

export function strokeShape(
  ctx: CanvasRenderingContext2D,
  kind: "line" | "rect" | "ellipse",
  a: { x: number; y: number },
  b: { x: number; y: number },
  color: string,
  width: number,
  alpha: number,
) {
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.strokeStyle = color;
  ctx.lineWidth = Math.max(1, width);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  if (kind === "rect") {
    ctx.strokeRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
  } else {
    ctx.beginPath();
    if (kind === "line") {
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
    } else {
      ctx.ellipse(
        (a.x + b.x) / 2,
        (a.y + b.y) / 2,
        Math.max(Math.abs(b.x - a.x) / 2, 0.5),
        Math.max(Math.abs(b.y - a.y) / 2, 0.5),
        0,
        0,
        Math.PI * 2,
      );
    }
    ctx.stroke();
  }
  ctx.restore();
}

export function floodFill(
  ctx: CanvasRenderingContext2D,
  sx: number,
  sy: number,
  hex: string,
  alpha: number,
) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const x0 = Math.floor(sx);
  const y0 = Math.floor(sy);
  if (x0 < 0 || y0 < 0 || x0 >= w || y0 >= h) return;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  const start = y0 * w + x0;
  const si = start * 4;
  const sr = d[si];
  const sg = d[si + 1];
  const sb = d[si + 2];
  const sa = d[si + 3];
  const [tr, tg, tb] = hexToRgb(hex);
  const ta = Math.round(clamp(alpha, 0, 1) * 255);
  if (sr === tr && sg === tg && sb === tb && Math.abs(sa - ta) < 3) return;
  const tol = 32;
  const match = (i: number) =>
    Math.abs(d[i] - sr) <= tol &&
    Math.abs(d[i + 1] - sg) <= tol &&
    Math.abs(d[i + 2] - sb) <= tol &&
    Math.abs(d[i + 3] - sa) <= tol;
  const seen = new Uint8Array(w * h);
  const stack: number[] = [start];
  seen[start] = 1;
  const consider = (q: number) => {
    if (seen[q]) return;
    seen[q] = 1;
    if (match(q * 4)) stack.push(q);
  };
  while (stack.length) {
    const p = stack.pop()!;
    const i = p * 4;
    d[i] = tr;
    d[i + 1] = tg;
    d[i + 2] = tb;
    d[i + 3] = ta;
    const x = p % w;
    const y = (p / w) | 0;
    if (x > 0) consider(p - 1);
    if (x + 1 < w) consider(p + 1);
    if (y > 0) consider(p - w);
    if (y + 1 < h) consider(p + w);
  }
  ctx.putImageData(img, 0, 0);
}
