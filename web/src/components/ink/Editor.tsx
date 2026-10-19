import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  Brush,
  Check,
  Crosshair,
  Download,
  Eraser,
  Eye,
  EyeOff,
  FlipHorizontal2,
  Grid3x3,
  Hand,
  Layers,
  Minus,
  PaintBucket,
  Pipette,
  Plus,
  Redo2,
  SlidersHorizontal,
  Square,
  Trash2,
  Undo2,
  X,
  Circle,
} from "lucide-react";
import { deleteWork, putWork } from "@/lib/ink/db";
import { BRUSHES, SWATCH_GROUPS, type BrushSpec, type Draft, type LayerRecord } from "@/lib/ink/model";
import {
  blankLayer,
  clamp,
  drawContain,
  floodFill,
  hexToRgb,
  hsvToRgb,
  layerFromPng,
  paintSegment,
  renderPaper,
  rgbToHex,
  rgbToHsv,
  stamp,
  strokeShape,
} from "@/lib/ink/paint";

type Tool = "brush" | "eraser" | "fill" | "picker" | "shape" | "hand";
type ShapeKind = "line" | "rect" | "ellipse";
type Sheet = null | "brush" | "color" | "layers" | "shape" | "more" | "leave";

type Live = {
  tool: Tool;
  shape: ShapeKind;
  brush: BrushSpec;
  color: string;
  size: number;
  flow: number;
  mirror: boolean;
  stabilize: number;
  zoom: number;
  pan: { x: number; y: number };
  title: string;
};

type Snap = { index: number; data: ImageData };
type Pt = { x: number; y: number };

export function Editor({ draft, onExit }: { draft: Draft; onExit: () => void }) {
  const viewRef = useRef<HTMLCanvasElement>(null);
  const overlayRef = useRef<HTMLCanvasElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const viewportRef = useRef<HTMLDivElement>(null);
  const layersRef = useRef<HTMLCanvasElement[]>([]);
  const paperRef = useRef<HTMLCanvasElement | null>(null);
  const activeRef = useRef(0);
  const visRef = useRef<boolean[]>([true]);
  const namesRef = useRef<string[]>(["Ink"]);
  const undoRef = useRef<Snap[]>([]);
  const redoRef = useRef<Snap[]>([]);
  const dirtyRef = useRef(false);
  const pointersRef = useRef<Map<number, Pt>>(new Map());
  const pinchRef = useRef<{ dist: number; zoom: number; pan: Pt; mid: Pt } | null>(null);
  const strokeRef = useRef<{ id: number; x: number; y: number; rawX: number; rawY: number } | null>(null);
  const shapeRef = useRef<{ a: Pt } | null>(null);
  const panDragRef = useRef<{ id: number; x: number; y: number; pan: Pt } | null>(null);
  const rafRef = useRef(0);
  const readyRef = useRef(false);

  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState("");
  const [tool, setTool] = useState<Tool>("brush");
  const [shape, setShape] = useState<ShapeKind>("line");
  const [brush, setBrush] = useState<BrushSpec>(BRUSHES[0]);
  const [color, setColor] = useState("#1a120e");
  const [size, setSize] = useState(18);
  const [flow, setFlow] = useState(0.9);
  const [mirror, setMirror] = useState(false);
  const [stabilize, setStabilize] = useState(28);
  const [grid, setGrid] = useState(false);
  const [vanish, setVanish] = useState(false);
  const [vanishPos, setVanishPos] = useState({ x: 0.5, y: 0.42 });
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [sheet, setSheet] = useState<Sheet>(null);
  const [layers, setLayers] = useState<{ name: string; visible: boolean }[]>([{ name: "Ink", visible: true }]);
  const [active, setActive] = useState(0);
  const [title, setTitle] = useState(draft.title);
  const [canUndo, setCanUndo] = useState(false);
  const [canRedo, setCanRedo] = useState(false);
  const [tip, setTip] = useState(true);
  const [note, setNote] = useState<string | null>(null);
  const noteTimer = useRef(0);
  const pictureRef = useRef<HTMLInputElement>(null);

  function ping(message: string) {
    setNote(message);
    window.clearTimeout(noteTimer.current);
    noteTimer.current = window.setTimeout(() => setNote(null), 2200);
  }

  const live = useRef<Live>({
    tool: "brush",
    shape: "line",
    brush: BRUSHES[0],
    color: "#1a120e",
    size: 18,
    flow: 0.9,
    mirror: false,
    stabilize: 28,
    zoom: 1,
    pan: { x: 0, y: 0 },
    title: draft.title,
  });
  live.current = { tool, shape, brush, color, size, flow, mirror, stabilize, zoom, pan, title };

  function syncHistory() {
    setCanUndo(undoRef.current.length > 0);
    setCanRedo(redoRef.current.length > 0);
  }

  function redraw() {
    const view = viewRef.current;
    const paper = paperRef.current;
    if (!view || !paper) return;
    const ctx = view.getContext("2d");
    if (!ctx) return;
    ctx.clearRect(0, 0, view.width, view.height);
    ctx.drawImage(paper, 0, 0);
    layersRef.current.forEach((layer, i) => {
      if (visRef.current[i] !== false) ctx.drawImage(layer, 0, 0);
    });
  }

  function requestRedraw() {
    if (rafRef.current) return;
    rafRef.current = requestAnimationFrame(() => {
      rafRef.current = 0;
      redraw();
    });
  }

  function pushUndo() {
    const index = activeRef.current;
    const layer = layersRef.current[index];
    if (!layer) return;
    const data = layer.getContext("2d")!.getImageData(0, 0, layer.width, layer.height);
    undoRef.current.push({ index, data });
    if (undoRef.current.length > 16) undoRef.current.shift();
    redoRef.current = [];
    dirtyRef.current = true;
    syncHistory();
  }

  function restore(snap: Snap) {
    const layer = layersRef.current[snap.index];
    if (!layer) return;
    layer.getContext("2d")!.putImageData(snap.data, 0, 0);
    redraw();
  }

  function undo() {
    const snap = undoRef.current.pop();
    if (!snap) return;
    const layer = layersRef.current[snap.index];
    if (!layer) return;
    redoRef.current.push({
      index: snap.index,
      data: layer.getContext("2d")!.getImageData(0, 0, layer.width, layer.height),
    });
    restore(snap);
    syncHistory();
  }

  function redo() {
    const snap = redoRef.current.pop();
    if (!snap) return;
    const layer = layersRef.current[snap.index];
    if (!layer) return;
    undoRef.current.push({
      index: snap.index,
      data: layer.getContext("2d")!.getImageData(0, 0, layer.width, layer.height),
    });
    restore(snap);
    syncHistory();
  }

  function toCanvas(clientX: number, clientY: number): Pt {
    const canvas = viewRef.current!;
    const rect = canvas.getBoundingClientRect();
    return {
      x: ((clientX - rect.left) / rect.width) * canvas.width,
      y: ((clientY - rect.top) / rect.height) * canvas.height,
    };
  }

  function applyZoom(next: number, nextPan = live.current.pan) {
    const z = clamp(next, 0.15, 8);
    live.current.zoom = z;
    live.current.pan = nextPan;
    setZoom(z);
    setPan(nextPan);
  }

  function fit() {
    const viewport = viewportRef.current;
    const view = viewRef.current;
    if (!viewport || !view) return;
    const z = Math.min(viewport.clientWidth / view.width, viewport.clientHeight / view.height) * 0.92;
    applyZoom(z, { x: 0, y: 0 });
  }

  async function persist() {
    const view = viewRef.current;
    if (!view) return;
    const thumbCanvas = document.createElement("canvas");
    thumbCanvas.width = 240;
    thumbCanvas.height = Math.max(1, Math.round(240 * (view.height / view.width)));
    thumbCanvas.getContext("2d")!.drawImage(view, 0, 0, thumbCanvas.width, thumbCanvas.height);
    const stored: LayerRecord[] = layersRef.current.map((layer, i) => ({
      name: namesRef.current[i] ?? `Wash ${i + 1}`,
      visible: visRef.current[i] !== false,
      png: layer.toDataURL("image/png"),
    }));
    await putWork({
      id: draft.id,
      title: live.current.title.trim() || "Untitled sheet",
      width: draft.width,
      height: draft.height,
      paper: draft.paper,
      updatedAt: Date.now(),
      thumb: thumbCanvas.toDataURL("image/jpeg", 0.72),
      layers: stored,
    });
    dirtyRef.current = false;
  }

  function exportPng() {
    const view = viewRef.current;
    if (!view) return;
    void persist();
    const a = document.createElement("a");
    a.href = view.toDataURL("image/png");
    a.download = `${(live.current.title || "vermilion").replace(/\s+/g, "-").toLowerCase()}.png`;
    a.click();
    ping("PNG downloaded. The sheet is also kept on this device.");
  }

  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport) return;
    let cancelled = false;

    const boot = async () => {
      const paper = renderPaper(draft.width, draft.height, draft.paper);
      const built: HTMLCanvasElement[] = [];
      const names: string[] = [];
      const vis: boolean[] = [];
      if (draft.layers?.length) {
        for (const layer of draft.layers) {
          built.push(await layerFromPng(layer.png, draft.width, draft.height));
          names.push(layer.name);
          vis.push(layer.visible);
        }
      } else if (draft.underlay) {
        const base = blankLayer(draft.width, draft.height);
        await drawContain(base, draft.underlay);
        built.push(base, blankLayer(draft.width, draft.height));
        names.push("Picture", "Ink");
        vis.push(true, true);
      } else {
        built.push(blankLayer(draft.width, draft.height));
        names.push("Ink");
        vis.push(true);
      }
      if (cancelled) return;
      paperRef.current = paper;
      layersRef.current = built;
      namesRef.current = names;
      visRef.current = vis;
      const view = viewRef.current!;
      const overlay = overlayRef.current!;
      view.width = draft.width;
      view.height = draft.height;
      overlay.width = draft.width;
      overlay.height = draft.height;
      const start = draft.underlay && !draft.layers ? 1 : 0;
      activeRef.current = start;
      setActive(start);
      setLayers(names.map((name, i) => ({ name, visible: vis[i] })));
      redraw();
      readyRef.current = true;
      setReady(true);
      requestAnimationFrame(() => fit());
    };

    void boot().catch(() => {
      if (!cancelled) setFailed("This sheet could not be opened.");
    });

    const onDown = (e: PointerEvent) => {
      if (!readyRef.current) return;
      const target = e.target as HTMLElement | null;
      if (target?.closest("[data-ui]")) return;
      if (e.button !== 0) return;
      viewport.setPointerCapture(e.pointerId);
      pointersRef.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pointersRef.current.size >= 2) {
        abortStroke();
        const pts = [...pointersRef.current.values()];
        pinchRef.current = {
          dist: Math.max(1, Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)),
          zoom: live.current.zoom,
          pan: live.current.pan,
          mid: { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 },
        };
        return;
      }
      const point = toCanvas(e.clientX, e.clientY);
      const current = live.current;
      if (current.tool === "hand") {
        panDragRef.current = { id: e.pointerId, x: e.clientX, y: e.clientY, pan: current.pan };
        return;
      }
      if (current.tool === "picker") {
        const pixel = viewRef.current!.getContext("2d")!.getImageData(clamp(point.x, 0, draft.width - 1), clamp(point.y, 0, draft.height - 1), 1, 1).data;
        const next = rgbToHex(pixel[0], pixel[1], pixel[2]);
        live.current.color = next;
        live.current.tool = "brush";
        setColor(next);
        setTool("brush");
        return;
      }
      if (current.tool === "fill") {
        const layer = layersRef.current[activeRef.current];
        if (!layer) return;
        pushUndo();
        floodFill(layer.getContext("2d")!, point.x, point.y, current.color, current.flow);
        redraw();
        return;
      }
      if (current.tool === "shape") {
        pushUndo();
        shapeRef.current = { a: point };
        return;
      }
      pushUndo();
      strokeRef.current = { id: e.pointerId, x: point.x, y: point.y, rawX: point.x, rawY: point.y };
      const ctx = layersRef.current[activeRef.current]?.getContext("2d");
      if (!ctx) return;
      paintSegment(
        ctx,
        point.x,
        point.y,
        point.x,
        point.y,
        current.brush,
        current.size / 2,
        current.color,
        current.flow,
        current.tool === "eraser",
        current.mirror ? draft.width : undefined,
      );
      requestRedraw();
    };

    const onMove = (e: PointerEvent) => {
      if (!pointersRef.current.has(e.pointerId)) return;
      pointersRef.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pointersRef.current.size >= 2 && pinchRef.current) {
        const pts = [...pointersRef.current.values()];
        const dist = Math.max(1, Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y));
        const mid = { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 };
        const pinch = pinchRef.current;
        applyZoom(pinch.zoom * (dist / pinch.dist), {
          x: pinch.pan.x + (mid.x - pinch.mid.x),
          y: pinch.pan.y + (mid.y - pinch.mid.y),
        });
        return;
      }
      const drag = panDragRef.current;
      if (drag && drag.id === e.pointerId) {
        applyZoom(live.current.zoom, {
          x: drag.pan.x + (e.clientX - drag.x),
          y: drag.pan.y + (e.clientY - drag.y),
        });
        return;
      }
      const point = toCanvas(e.clientX, e.clientY);
      const shaping = shapeRef.current;
      if (shaping) {
        const overlay = overlayRef.current;
        if (!overlay) return;
        const ctx = overlay.getContext("2d")!;
        ctx.clearRect(0, 0, overlay.width, overlay.height);
        const current = live.current;
        strokeShape(ctx, current.shape, shaping.a, point, current.color, current.size, current.flow);
        if (current.mirror) {
          strokeShape(
            ctx,
            current.shape,
            { x: draft.width - shaping.a.x, y: shaping.a.y },
            { x: draft.width - point.x, y: point.y },
            current.color,
            current.size,
            current.flow,
          );
        }
        return;
      }
      const stroke = strokeRef.current;
      if (!stroke || stroke.id !== e.pointerId) return;
      const current = live.current;
      const k = current.stabilize / 100;
      const x = stroke.x * k + point.x * (1 - k);
      const y = stroke.y * k + point.y * (1 - k);
      const ctx = layersRef.current[activeRef.current]?.getContext("2d");
      if (!ctx) return;
      paintSegment(
        ctx,
        stroke.x,
        stroke.y,
        x,
        y,
        current.brush,
        current.size / 2,
        current.color,
        current.flow,
        current.tool === "eraser",
        current.mirror ? draft.width : undefined,
      );
      stroke.x = x;
      stroke.y = y;
      stroke.rawX = point.x;
      stroke.rawY = point.y;
      requestRedraw();
    };

    const endPointer = (e: PointerEvent) => {
      pointersRef.current.delete(e.pointerId);
      if (pointersRef.current.size < 2) pinchRef.current = null;
      if (panDragRef.current?.id === e.pointerId) panDragRef.current = null;
      if (shapeRef.current) {
        const point = toCanvas(e.clientX, e.clientY);
        const current = live.current;
        const ctx = layersRef.current[activeRef.current]?.getContext("2d");
        if (ctx) {
          strokeShape(ctx, current.shape, shapeRef.current.a, point, current.color, current.size, current.flow);
          if (current.mirror) {
            strokeShape(
              ctx,
              current.shape,
              { x: draft.width - shapeRef.current.a.x, y: shapeRef.current.a.y },
              { x: draft.width - point.x, y: point.y },
              current.color,
              current.size,
              current.flow,
            );
          }
        }
        shapeRef.current = null;
        overlayRef.current?.getContext("2d")!.clearRect(0, 0, draft.width, draft.height);
        redraw();
      }
      if (strokeRef.current?.id === e.pointerId) strokeRef.current = null;
    };

    const abortStroke = () => {
      if (strokeRef.current || shapeRef.current) {
        const snap = undoRef.current.pop();
        if (snap) restore(snap);
        strokeRef.current = null;
        shapeRef.current = null;
        overlayRef.current?.getContext("2d")!.clearRect(0, 0, draft.width, draft.height);
        syncHistory();
      }
    };

    const onWheel = (e: WheelEvent) => {
      if (!readyRef.current) return;
      e.preventDefault();
      const factor = e.deltaY > 0 ? 0.92 : 1.08;
      applyZoom(live.current.zoom * factor);
    };

    const onKey = (e: KeyboardEvent) => {
      const meta = e.metaKey || e.ctrlKey;
      if (meta && e.key.toLowerCase() === "z") {
        e.preventDefault();
        if (e.shiftKey) redo();
        else undo();
      } else if (e.key === "[") {
        setSize((n) => {
          const next = clamp(n - 2, 1, 160);
          live.current.size = next;
          return next;
        });
      } else if (e.key === "]") {
        setSize((n) => {
          const next = clamp(n + 2, 1, 160);
          live.current.size = next;
          return next;
        });
      }
    };

    viewport.addEventListener("pointerdown", onDown);
    viewport.addEventListener("pointermove", onMove);
    viewport.addEventListener("pointerup", endPointer);
    viewport.addEventListener("pointercancel", endPointer);
    viewport.addEventListener("wheel", onWheel, { passive: false });
    window.addEventListener("keydown", onKey);
    return () => {
      cancelled = true;
      readyRef.current = false;
      viewport.removeEventListener("pointerdown", onDown);
      viewport.removeEventListener("pointermove", onMove);
      viewport.removeEventListener("pointerup", endPointer);
      viewport.removeEventListener("pointercancel", endPointer);
      viewport.removeEventListener("wheel", onWheel);
      window.removeEventListener("keydown", onKey);
    };
    // Boot and listeners are bound once per sheet.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [draft.id]);

  useEffect(() => {
    visRef.current = layers.map((layer) => layer.visible);
    namesRef.current = layers.map((layer) => layer.name);
    if (readyRef.current) redraw();
  }, [layers]);

  useEffect(() => {
    activeRef.current = active;
  }, [active]);

  useEffect(() => {
    if (!tip) return;
    const id = window.setTimeout(() => setTip(false), 4200);
    return () => window.clearTimeout(id);
  }, [tip]);

  function toggleSheet(next: Sheet) {
    setSheet((cur) => (cur === next ? null : next));
  }

  function selectTool(next: Tool, open?: Sheet) {
    if (tool === next && open && sheet === open) {
      setSheet(null);
      ping("Closed.");
      return;
    }
    setTool(next);
    live.current.tool = next;
    setSheet(open ?? null);
    const names: Record<Tool, string> = {
      brush: "Brush. Tap again for the set.",
      eraser: "Eraser. The paper stays.",
      fill: "Fill. Tap a region.",
      picker: "Eyedropper. Tap the sheet.",
      shape: "Shape. Drag a mark. Tap again to switch.",
      hand: "Move. One finger pans.",
    };
    ping(names[next]);
  }

  async function leave(mode: "save" | "drop" | "revert") {
    if (mode === "save") await persist();
    if (mode === "drop") await deleteWork(draft.id);
    onExit();
  }

  function addLayer() {
    if (layersRef.current.length >= 8) {
      ping("Eight washes is the limit.");
      return;
    }
    const layer = blankLayer(draft.width, draft.height);
    const index = activeRef.current + 1;
    layersRef.current.splice(index, 0, layer);
    const next = [...layers];
    next.splice(index, 0, { name: `Wash ${layers.length + 1}`, visible: true });
    setLayers(next);
    setActive(index);
    redraw();
    ping("Wash added.");
  }

  function removeLayer(index: number) {
    if (layersRef.current.length <= 1) {
      ping("A sheet needs one wash.");
      return;
    }
    layersRef.current.splice(index, 1);
    const next = layers.filter((_, i) => i !== index);
    setLayers(next);
    const nextActive = Math.max(0, Math.min(active, next.length - 1, index === active ? index - 1 : active > index ? active - 1 : active));
    setActive(nextActive);
    redraw();
    ping("Wash removed.");
  }

  async function placePicture(src: string) {
    if (layersRef.current.length >= 8) {
      ping("Eight washes is the limit.");
      return;
    }
    const layer = blankLayer(draft.width, draft.height);
    await drawContain(layer, src);
    const index = activeRef.current + 1;
    layersRef.current.splice(index, 0, layer);
    const next = [...layers];
    next.splice(index, 0, { name: "Picture", visible: true });
    namesRef.current.splice(index, 0, "Picture");
    visRef.current.splice(index, 0, true);
    setLayers(next);
    setActive(index);
    dirtyRef.current = true;
    redraw();
    ping("Picture placed. Draw over it.");
  }

  const toolButtons: { id: Tool; label: string; icon: ReactNode; sheet?: Sheet }[] = [
    { id: "brush", label: "Brush", icon: <Brush className="size-5" />, sheet: "brush" },
    { id: "eraser", label: "Eraser", icon: <Eraser className="size-5" /> },
    { id: "fill", label: "Fill", icon: <PaintBucket className="size-5" /> },
    { id: "picker", label: "Pick", icon: <Pipette className="size-5" /> },
    { id: "shape", label: "Shape", icon: <Square className="size-5" />, sheet: "shape" },
    { id: "hand", label: "Move", icon: <Hand className="size-5" /> },
  ];

  return (
    <div className="relative flex h-dvh flex-col bg-ink text-rice">
      <header className="flex h-14 shrink-0 items-center gap-1 border-b border-line px-2">
        <button type="button" className="grid size-11 place-items-center" aria-label="Close" onClick={() => (dirtyRef.current ? setSheet("leave") : onExit())}>
          <X className="size-5" />
        </button>
        <input
          value={title}
          onChange={(e) => {
            setTitle(e.target.value);
            dirtyRef.current = true;
          }}
          aria-label="Sheet title"
          className="min-w-0 flex-1 bg-transparent font-display text-xl outline-none"
        />
        <button
          type="button"
          className={`grid size-11 place-items-center ${canUndo ? "" : "opacity-40"}`}
          aria-label="Undo"
          onClick={() => {
            if (!canUndo) {
              ping("Nothing to step back to.");
              return;
            }
            undo();
            ping("Stepped back.");
          }}
        >
          <Undo2 className="size-5" />
        </button>
        <button
          type="button"
          className={`grid size-11 place-items-center ${canRedo ? "" : "opacity-40"}`}
          aria-label="Redo"
          onClick={() => {
            if (!canRedo) {
              ping("Nothing to step forward to.");
              return;
            }
            redo();
            ping("Stepped forward.");
          }}
        >
          <Redo2 className="size-5" />
        </button>
        <button
          type="button"
          className="grid size-11 place-items-center"
          aria-label="Keep on this device"
          onClick={() => {
            void persist().then(() => ping("Kept on this device."));
          }}
        >
          <Check className="size-5" />
        </button>
        <button type="button" className="grid size-11 place-items-center" aria-label="Save image" onClick={exportPng}>
          <Download className="size-5" />
        </button>
      </header>
      <div className="relative min-h-0 flex-1">
        <div ref={viewportRef} className="absolute inset-y-0 right-0 left-16 touch-none overflow-hidden" onContextMenu={(e) => e.preventDefault()}>
          <div
            ref={stageRef}
            className="absolute top-1/2 left-1/2"
            style={{
              width: draft.width,
              height: draft.height,
              transform: `translate(-50%, -50%) translate(${pan.x}px, ${pan.y}px) scale(${zoom})`,
            }}
          >
            <canvas ref={viewRef} className="block bg-rice" />
            <canvas ref={overlayRef} className="pointer-events-none absolute top-0 left-0" />
            {grid && <div className="sheet-grid pointer-events-none absolute inset-0" />}
            {vanish && (
              <svg className="pointer-events-none absolute inset-0 h-full w-full" viewBox={`0 0 ${draft.width} ${draft.height}`}>
                {Array.from({ length: 12 }, (_, i) => {
                  const a = (i / 12) * Math.PI * 2;
                  const len = Math.hypot(draft.width, draft.height);
                  const cx = vanishPos.x * draft.width;
                  const cy = vanishPos.y * draft.height;
                  return (
                    <line
                      key={i}
                      x1={cx}
                      y1={cy}
                      x2={cx + Math.cos(a) * len}
                      y2={cy + Math.sin(a) * len}
                      stroke="var(--color-cinnabar)"
                      strokeOpacity="0.45"
                      strokeWidth="1"
                    />
                  );
                })}
              </svg>
            )}
            {vanish && (
              <button
                type="button"
                data-ui
                aria-label="Move the vanishing point"
                className="absolute z-10 size-8 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-cinnabar bg-ink/70"
                style={{ left: `${vanishPos.x * 100}%`, top: `${vanishPos.y * 100}%` }}
                onPointerDown={(e) => {
                  e.stopPropagation();
                  e.currentTarget.setPointerCapture(e.pointerId);
                }}
                onPointerMove={(e) => {
                  if (!e.currentTarget.hasPointerCapture(e.pointerId)) return;
                  const rect = stageRef.current!.getBoundingClientRect();
                  setVanishPos({
                    x: clamp((e.clientX - rect.left) / rect.width, 0.04, 0.96),
                    y: clamp((e.clientY - rect.top) / rect.height, 0.04, 0.96),
                  });
                }}
              />
            )}
          </div>
        </div>
        <div data-ui className="absolute top-2 bottom-24 left-2 flex w-14 flex-col gap-1 overflow-y-auto">
          {toolButtons.map((item) => (
            <RailButton
              key={item.id}
              label={item.label}
              active={tool === item.id}
              onClick={() => selectTool(item.id, item.sheet)}
            >
              {item.icon}
            </RailButton>
          ))}
          <button
            type="button"
            aria-label="Color"
            className="grid size-11 place-items-center"
            onClick={() => {
              toggleSheet("color");
              ping(sheet === "color" ? "Closed." : "Pigment.");
            }}
          >
            <span className="size-6 rounded-full border border-rice" style={{ background: color }} />
          </button>
          <RailButton label="Layers" active={sheet === "layers"} onClick={() => { toggleSheet("layers"); ping(sheet === "layers" ? "Closed." : "Washes."); }}>
            <Layers className="size-5" />
          </RailButton>
          <RailButton label="Studio" active={sheet === "more"} onClick={() => { toggleSheet("more"); ping(sheet === "more" ? "Closed." : "The desk."); }}>
            <SlidersHorizontal className="size-5" />
          </RailButton>
        </div>
        {!ready && !failed && (
          <p className="pointer-events-none absolute inset-x-0 top-6 text-center text-sm text-mist">Grinding the ink…</p>
        )}
        {failed && <p className="absolute inset-x-6 top-16 text-center text-sm text-cinnabar">{failed}</p>}
        {note ? (
          <p role="status" className="pointer-events-none absolute right-3 bottom-3 left-20 rounded-full bg-ink/90 px-3 py-2 text-center text-xs text-rice">
            {note}
          </p>
        ) : tip && ready ? (
          <p className="pointer-events-none absolute right-3 bottom-3 left-20 rounded-full bg-ink/80 px-3 py-1 text-center text-xs text-mist">
            One finger draws. Two fingers move the page.
          </p>
        ) : null}
      </div>
      <footer data-ui className="dock shrink-0 border-t border-line bg-panel px-4 pt-3">
        <label className="flex items-center gap-3 text-xs text-mist">
          <span className="w-10">Size</span>
          <input
            type="range"
            min={1}
            max={120}
            value={size}
            onChange={(e) => setSize(Number(e.target.value))}
            className="min-h-11 flex-1 accent-cinnabar"
          />
          <span className="w-8 text-right text-rice">{size}</span>
        </label>
        <label className="flex items-center gap-3 text-xs text-mist">
          <span className="w-10">Flow</span>
          <input
            type="range"
            min={4}
            max={100}
            value={Math.round(flow * 100)}
            onChange={(e) => setFlow(Number(e.target.value) / 100)}
            className="min-h-11 flex-1 accent-cinnabar"
          />
          <span className="w-8 text-right text-rice">{Math.round(flow * 100)}</span>
        </label>
      </footer>
      {sheet === "brush" && (
        <Sheet title="Brushes" onClose={() => setSheet(null)}>
          <ul className="flex flex-col gap-2">
            {BRUSHES.map((item) => (
              <li key={item.id}>
                <button
                  type="button"
                  onClick={() => {
                    setBrush(item);
                    setTool("brush");
                    setSheet(null);
                  }}
                  className={`w-full rounded-2xl border px-3 py-2 text-left ${brush.id === item.id ? "border-cinnabar bg-raise" : "border-line bg-ink"}`}
                >
                  <span className="flex items-baseline justify-between gap-3">
                    <span>{item.name}</span>
                    <span className="text-xs text-mist">{item.hint}</span>
                  </span>
                  <BrushPreview brush={item} color={color} />
                </button>
              </li>
            ))}
          </ul>
        </Sheet>
      )}
      {sheet === "color" && <ColorSheet color={color} onChange={setColor} onClose={() => setSheet(null)} />}
      {sheet === "shape" && (
        <Sheet title="Marks" onClose={() => setSheet(null)}>
          <div className="grid grid-cols-3 gap-2">
            {(
              [
                ["line", "Line", <Minus key="l" />],
                ["rect", "Frame", <Square key="r" />],
                ["ellipse", "Moon", <Circle key="e" />],
              ] as const
            ).map(([id, label, icon]) => (
              <button
                key={id}
                type="button"
                className={`flex min-h-20 flex-col items-center justify-center gap-2 rounded-2xl border ${shape === id ? "border-cinnabar text-cinnabar" : "border-line"}`}
                onClick={() => {
                  setShape(id);
                  setTool("shape");
                  setSheet(null);
                }}
              >
                {icon}
                {label}
              </button>
            ))}
          </div>
        </Sheet>
      )}
      {sheet === "layers" && (
        <Sheet title="Washes" onClose={() => setSheet(null)}>
          <ul className="flex flex-col gap-2">
            {layers.map((layer, index) => (
              <li key={`${layer.name}-${index}`} className={`flex items-center gap-2 rounded-2xl border px-2 ${index === active ? "border-cinnabar" : "border-line"}`}>
                <button type="button" className="min-h-11 flex-1 text-left" onClick={() => setActive(index)}>
                  {layer.name}
                </button>
                <button
                  type="button"
                  className="grid size-11 place-items-center"
                  aria-label={layer.visible ? "Hide wash" : "Show wash"}
                  onClick={() => setLayers(layers.map((item, i) => (i === index ? { ...item, visible: !item.visible } : item)))}
                >
                  {layer.visible ? <Eye className="size-4" /> : <EyeOff className="size-4" />}
                </button>
                <button type="button" className="grid size-11 place-items-center" aria-label="Remove wash" onClick={() => removeLayer(index)}>
                  <Trash2 className="size-4" />
                </button>
              </li>
            ))}
          </ul>
          <button type="button" className="mt-3 inline-flex min-h-11 items-center gap-2 text-sm text-cinnabar" onClick={addLayer}>
            <Plus className="size-4" />
            Add a wash
          </button>
        </Sheet>
      )}
      {sheet === "more" && (
        <Sheet title="The desk" onClose={() => setSheet(null)}>
          <ToggleRow
            icon={<FlipHorizontal2 className="size-4" />}
            label="Mirror"
            on={mirror}
            onClick={() => {
              const next = !mirror;
              setMirror(next);
              ping(next ? "Mirror on." : "Mirror off.");
            }}
          />
          <ToggleRow
            icon={<Grid3x3 className="size-4" />}
            label="Grid"
            on={grid}
            onClick={() => {
              const next = !grid;
              setGrid(next);
              ping(next ? "Grid on." : "Grid off.");
            }}
          />
          <ToggleRow
            icon={<Crosshair className="size-4" />}
            label="One-point guide"
            on={vanish}
            onClick={() => {
              const next = !vanish;
              setVanish(next);
              ping(next ? "One-point guide on." : "Guide off.");
            }}
          />
          <label className="mt-4 flex items-center gap-3 text-sm text-mist">
            Steady
            <input
              type="range"
              min={0}
              max={85}
              value={stabilize}
              onChange={(e) => setStabilize(Number(e.target.value))}
              className="min-h-11 flex-1 accent-cinnabar"
            />
          </label>
          <button type="button" className="mt-2 min-h-11 text-sm text-mist" onClick={() => { fit(); ping("Fitted to the screen."); }}>
            Fit the sheet
          </button>
          <button
            type="button"
            className="mt-1 min-h-11 text-sm text-mist"
            onClick={() => pictureRef.current?.click()}
          >
            Place a picture
          </button>
          <input
            ref={pictureRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              e.target.value = "";
              if (!file) {
                ping("No picture chosen.");
                return;
              }
              const reader = new FileReader();
              reader.onload = () => {
                if (typeof reader.result === "string") void placePicture(reader.result);
              };
              reader.readAsDataURL(file);
            }}
          />
          <button
            type="button"
            className="mt-1 min-h-11 text-sm text-cinnabar"
            onClick={() => {
              pushUndo();
              const layer = layersRef.current[active];
              layer?.getContext("2d")!.clearRect(0, 0, draft.width, draft.height);
              redraw();
              setSheet(null);
              ping("Wash cleared.");
            }}
          >
            Clear this wash
          </button>
        </Sheet>
      )}
      {sheet === "leave" && (
        <div className="absolute inset-0 z-30 grid place-items-center bg-ink/70 px-6" data-ui>
          <div className="w-full max-w-sm rounded-3xl bg-panel p-5">
            <h2 className="font-display text-3xl">Leave the sheet?</h2>
            <p className="mt-2 text-sm text-mist">Unsaved ink stays only if you keep it on this device.</p>
            <button type="button" className="mt-4 min-h-12 w-full rounded-2xl bg-cinnabar text-rice" onClick={() => void leave("save")}>
              Keep and leave
            </button>
            {draft.layers ? (
              <button type="button" className="mt-2 min-h-12 w-full rounded-2xl bg-raise text-rice" onClick={() => void leave("revert")}>
                Leave without saving
              </button>
            ) : (
              <button type="button" className="mt-2 min-h-12 w-full rounded-2xl bg-raise text-rice" onClick={() => void leave("drop")}>
                Throw this sheet away
              </button>
            )}
            <button type="button" className="mt-2 min-h-11 w-full text-sm text-mist" onClick={() => setSheet(null)}>
              Keep painting
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function RailButton({
  label,
  active,
  onClick,
  children,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className={`grid size-11 place-items-center rounded-2xl ${active ? "bg-cinnabar text-rice" : "text-rice"}`}
    >
      {children}
    </button>
  );
}

function Sheet({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="absolute inset-0 z-20 flex items-end bg-ink/50" data-ui onClick={onClose}>
      <div className="max-h-[78%] w-full overflow-y-auto rounded-t-3xl bg-panel px-4 pt-4 pb-6" onClick={(e) => e.stopPropagation()}>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="font-display text-2xl">{title}</h2>
          <button type="button" className="grid size-11 place-items-center" aria-label="Close panel" onClick={onClose}>
            <Check className="size-5" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function ToggleRow({
  icon,
  label,
  on,
  onClick,
}: {
  icon: ReactNode;
  label: string;
  on: boolean;
  onClick: () => void;
}) {
  return (
    <button type="button" onClick={onClick} className="flex min-h-12 w-full items-center justify-between gap-3 text-left">
      <span className="inline-flex items-center gap-2">
        {icon}
        {label}
      </span>
      <span className={`rounded-full px-3 py-1 text-xs ${on ? "bg-cinnabar text-rice" : "bg-raise text-mist"}`}>{on ? "On" : "Off"}</span>
    </button>
  );
}

function BrushPreview({ brush, color }: { brush: BrushSpec; color: string }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    let prev = 12;
    const end = canvas.width - 12;
    for (let i = 0; i <= 28; i++) {
      const t = i / 28;
      const x = 12 + (end - 12) * t;
      const y = canvas.height / 2 + Math.sin(t * Math.PI * 2) * 8;
      const radius = brush.kind === "speed" ? 3 + Math.sin(t * Math.PI) * 10 : 3 + Math.sin(t * Math.PI) * 8;
      stamp(ctx, x, y, radius, color, brush.baseFlow, brush.hard, false, brush.kind === "dry");
      prev = x;
    }
    void prev;
  }, [brush, color]);
  return <canvas ref={ref} width={320} height={56} className="mt-1 h-14 w-full" />;
}

function ColorSheet({ color, onChange, onClose }: { color: string; onChange: (hex: string) => void; onClose: () => void }) {
  const [rgb, setRgb] = useState(() => hexToRgb(color));
  const hsv = rgbToHsv(rgb[0], rgb[1], rgb[2]);
  const [hue, setHue] = useState(hsv.h);
  const [sat, setSat] = useState(hsv.s);
  const [val, setVal] = useState(hsv.v);

  function commit(h: number, s: number, v: number) {
    const next = hsvToRgb(h, s, v);
    setHue(h);
    setSat(s);
    setVal(v);
    setRgb([next.r, next.g, next.b]);
    onChange(rgbToHex(next.r, next.g, next.b));
  }

  const pure = rgbToHex(hsvToRgb(hue, 1, 1).r, hsvToRgb(hue, 1, 1).g, hsvToRgb(hue, 1, 1).b);

  return (
    <Sheet title="Pigment" onClose={onClose}>
      <div
        className="relative h-40 overflow-hidden rounded-2xl"
        style={{ background: pure }}
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId);
          const rect = e.currentTarget.getBoundingClientRect();
          commit(hue, clamp((e.clientX - rect.left) / rect.width, 0, 1), clamp(1 - (e.clientY - rect.top) / rect.height, 0, 1));
        }}
        onPointerMove={(e) => {
          if (!e.currentTarget.hasPointerCapture(e.pointerId)) return;
          const rect = e.currentTarget.getBoundingClientRect();
          commit(hue, clamp((e.clientX - rect.left) / rect.width, 0, 1), clamp(1 - (e.clientY - rect.top) / rect.height, 0, 1));
        }}
      >
        <div className="absolute inset-0" style={{ background: "linear-gradient(to right, #fff, transparent)" }} />
        <div className="absolute inset-0" style={{ background: "linear-gradient(to top, #000, transparent)" }} />
        <span
          className="absolute size-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-rice"
          style={{ left: `${sat * 100}%`, top: `${(1 - val) * 100}%` }}
        />
      </div>
      <input className="hue-slider mt-4" type="range" min={0} max={360} value={Math.round(hue)} onChange={(e) => commit(Number(e.target.value), sat, val)} />
      <div className="mt-4 flex flex-col gap-3">
        {SWATCH_GROUPS.map((group) => (
          <div key={group.name}>
            <p className="mb-2 text-xs tracking-widest text-mist uppercase">{group.name}</p>
            <div className="grid grid-cols-8 gap-2">
              {group.colors.map((swatch) => (
                <button
                  key={swatch}
                  type="button"
                  aria-label={swatch}
                  className="aspect-square rounded-md border border-line"
                  style={{ background: swatch }}
                  onClick={() => {
                    const next = hexToRgb(swatch);
                    const picked = rgbToHsv(next[0], next[1], next[2]);
                    setRgb(next);
                    setHue(picked.h);
                    setSat(picked.s);
                    setVal(picked.v);
                    onChange(swatch);
                  }}
                />
              ))}
            </div>
          </div>
        ))}
      </div>
    </Sheet>
  );
}
