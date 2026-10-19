import { useEffect, useRef, useState, type ReactNode } from "react";
import { BookOpen, ChevronLeft, ImagePlus, Plus, Trash2 } from "lucide-react";
import { deleteWork, listWorks } from "@/lib/ink/db";
import {
  PAPERS,
  PRESETS,
  PROMPTS,
  presetById,
  type Draft,
  type PaperId,
  type WorkRecord,
} from "@/lib/ink/model";
import { Editor } from "@/components/ink/Editor";

type Tab = "studio" | "prompts" | "create";

function ago(ts: number) {
  const s = Math.max(0, Math.round((Date.now() - ts) / 1000));
  if (s < 45) return "Just now";
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

function Seal() {
  return (
    <div
      className="grid size-14 rotate-6 place-items-center rounded-md border-2 border-cinnabar bg-cinnabar/15"
      aria-hidden
    >
      <div className="size-8 rounded-sm border border-cinnabar" />
    </div>
  );
}

export function Atelier() {
  const [tab, setTab] = useState<Tab>("studio");
  const [works, setWorks] = useState<WorkRecord[]>([]);
  const [booted, setBooted] = useState(false);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [paper, setPaper] = useState<PaperId>("xuan");
  const [presetId, setPresetId] = useState("scroll");
  const [promptTitle, setPromptTitle] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  async function refresh() {
    setWorks(await listWorks());
    setBooted(true);
  }

  useEffect(() => {
    void refresh();
  }, []);

  function openNew(next?: { preset?: string; paper?: PaperId; title?: string }) {
    setPresetId(next?.preset ?? "scroll");
    setPaper(next?.paper ?? "xuan");
    setPromptTitle(next?.title ?? null);
    setTab("create");
  }

  function begin(underlay?: string) {
    const preset = presetById(presetId);
    setDraft({
      id: crypto.randomUUID(),
      title: promptTitle ?? preset.name,
      width: preset.w,
      height: preset.h,
      paper,
      underlay,
    });
  }

  function openWork(work: WorkRecord) {
    setDraft({
      id: work.id,
      title: work.title,
      width: work.width,
      height: work.height,
      paper: work.paper,
      layers: work.layers,
    });
  }

  if (draft) {
    return (
      <Editor
        draft={draft}
        onExit={() => {
          setDraft(null);
          setTab("studio");
          void refresh();
        }}
      />
    );
  }

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-3xl flex-col overflow-x-hidden">
      {tab === "studio" && (
        <Studio
          works={works}
          booted={booted}
          pendingDelete={pendingDelete}
          onOpen={openWork}
          onAskDelete={setPendingDelete}
          onDelete={async (id) => {
            await deleteWork(id);
            setPendingDelete(null);
            await refresh();
          }}
        />
      )}
      {tab === "prompts" && <Prompts onUse={openNew} />}
      {tab === "create" && (
        <CreateSheet
          paper={paper}
          presetId={presetId}
          promptTitle={promptTitle}
          onPaper={setPaper}
          onPreset={(id) => {
            setPresetId(id);
            setPromptTitle(null);
          }}
          onBack={() => setTab("studio")}
          onBegin={() => begin()}
          onPicture={() => fileRef.current?.click()}
        />
      )}
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          e.target.value = "";
          if (!file) return;
          const reader = new FileReader();
          reader.onload = () => {
            if (typeof reader.result === "string") begin(reader.result);
          };
          reader.readAsDataURL(file);
        }}
      />
      {tab !== "create" && (
        <nav className="dock sticky bottom-0 grid grid-cols-3 items-end border-t border-line bg-panel px-6 pt-2">
          <NavButton active={tab === "studio"} label="Studio" onClick={() => setTab("studio")}>
            <span className="mb-1 block size-2 rounded-sm bg-current" />
          </NavButton>
          <div className="flex justify-center">
            <button
              type="button"
              className="-mt-7 grid size-14 place-items-center rounded-full bg-cinnabar text-rice shadow-lg"
              onClick={() => openNew()}
              aria-label="Cut a new sheet"
            >
              <Plus className="size-7" strokeWidth={1.75} />
            </button>
          </div>
          <NavButton active={tab === "prompts"} label="Prompts" onClick={() => setTab("prompts")}>
            <BookOpen className="mb-1 size-5" strokeWidth={1.75} />
          </NavButton>
        </nav>
      )}
    </div>
  );
}

function NavButton({
  active,
  label,
  onClick,
  children,
}: {
  active: boolean;
  label: string;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex min-h-11 flex-col items-center justify-end pb-1 text-xs ${active ? "text-cinnabar" : "text-mist"}`}
    >
      {children}
      {label}
    </button>
  );
}

function Studio({
  works,
  booted,
  pendingDelete,
  onOpen,
  onAskDelete,
  onDelete,
}: {
  works: WorkRecord[];
  booted: boolean;
  pendingDelete: string | null;
  onOpen: (work: WorkRecord) => void;
  onAskDelete: (id: string | null) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <main className="flex-1 px-5 pt-7 pb-8">
      <header className="flex items-end justify-between gap-4">
        <div>
          <p className="text-xs tracking-widest text-cinnabar uppercase">Vermilion</p>
          <h1 className="font-display text-5xl leading-none">Atelier</h1>
        </div>
        <Seal />
      </header>
      <p className="mt-4 max-w-md text-sm leading-relaxed text-mist">
        A pocket ink studio for people who think the page will refuse them. Wolf hair, mineral color, and a great deal of unpainted paper. Everything stays on this device.
      </p>
      {!booted && <p className="mt-10 text-sm text-mist">Opening the cabinet…</p>}
      {booted && works.length === 0 && (
        <div className="mt-10 rounded-3xl border border-line bg-panel px-5 py-8">
          <p className="font-display text-3xl leading-tight">The cabinet is empty, which is the correct way to begin.</p>
          <p className="mt-3 text-sm leading-relaxed text-mist">
            Cut a sheet, or take a prompt that tells you when to stop. Stopping is the whole craft.
          </p>
        </div>
      )}
      <ul className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-3">
        {works.map((work) => (
          <li key={work.id} className="min-w-0">
            <button type="button" onClick={() => onOpen(work)} className="block w-full text-left">
              <img
                src={work.thumb}
                alt=""
                className="aspect-[3/4] w-full rounded-2xl border border-line object-cover"
              />
              <p className="mt-2 truncate font-display text-xl leading-tight">{work.title}</p>
              <p className="text-xs text-mist">
                {ago(work.updatedAt)} · {work.paper}
              </p>
            </button>
            {pendingDelete === work.id ? (
              <div className="mt-2 flex gap-2">
                <button
                  type="button"
                  className="min-h-11 flex-1 rounded-xl bg-cinnabar text-sm text-rice"
                  onClick={() => onDelete(work.id)}
                >
                  Delete
                </button>
                <button
                  type="button"
                  className="min-h-11 flex-1 rounded-xl bg-raise text-sm text-rice"
                  onClick={() => onAskDelete(null)}
                >
                  Keep
                </button>
              </div>
            ) : (
              <button
                type="button"
                className="mt-1 inline-flex min-h-11 items-center gap-1 text-xs text-mist"
                onClick={() => onAskDelete(work.id)}
              >
                <Trash2 className="size-3.5" />
                Remove
              </button>
            )}
          </li>
        ))}
      </ul>
    </main>
  );
}

function Prompts({ onUse }: { onUse: (next: { preset: string; paper: PaperId; title: string }) => void }) {
  return (
    <main className="flex-1 px-5 pt-7 pb-8">
      <p className="text-xs tracking-widest text-cinnabar uppercase">Restraints</p>
      <h1 className="font-display text-5xl leading-none">Prompts</h1>
      <p className="mt-4 max-w-md text-sm leading-relaxed text-mist">
        Most pictures fail because they try to say everything. Pick one limit and obey it.
      </p>
      <ul className="mt-6 flex flex-col gap-3">
        {PROMPTS.map((prompt) => (
          <li key={prompt.id} className="rounded-3xl border border-line bg-panel px-5 py-4">
            <h2 className="font-display text-2xl leading-tight">{prompt.title}</h2>
            <p className="mt-2 text-sm leading-relaxed text-mist">{prompt.text}</p>
            <button
              type="button"
              className="mt-3 min-h-11 rounded-full bg-cinnabar px-4 text-sm text-rice"
              onClick={() => onUse({ preset: prompt.preset, paper: prompt.paper, title: prompt.title })}
            >
              Use this sheet
            </button>
          </li>
        ))}
      </ul>
    </main>
  );
}

function CreateSheet({
  paper,
  presetId,
  promptTitle,
  onPaper,
  onPreset,
  onBack,
  onBegin,
  onPicture,
}: {
  paper: PaperId;
  presetId: string;
  promptTitle: string | null;
  onPaper: (id: PaperId) => void;
  onPreset: (id: string) => void;
  onBack: () => void;
  onBegin: () => void;
  onPicture: () => void;
}) {
  const preset = presetById(presetId);
  return (
    <main className="flex min-h-dvh flex-1 flex-col px-5 pt-4 pb-6">
      <header className="flex items-center gap-2">
        <button type="button" className="grid size-11 place-items-center rounded-full text-rice" onClick={onBack} aria-label="Back">
          <ChevronLeft />
        </button>
        <h1 className="flex-1 text-center font-display text-3xl">Cut a sheet</h1>
        <span className="size-11" />
      </header>
      {promptTitle && (
        <p className="mt-2 text-center text-sm text-cinnabar">For “{promptTitle}”</p>
      )}
      <div className="mt-5 flex gap-2 overflow-x-auto pb-1">
        {PAPERS.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => onPaper(item.id)}
            className={`min-h-11 shrink-0 rounded-full border px-4 text-sm ${
              paper === item.id ? "border-cinnabar bg-cinnabar text-rice" : "border-line bg-panel text-rice"
            }`}
          >
            {item.name}
            <span className={paper === item.id ? "text-rice/80" : "text-mist"}> · {item.hint}</span>
          </button>
        ))}
      </div>
      <ul className="mt-4 flex flex-1 flex-col gap-2 overflow-y-auto">
        {PRESETS.map((item) => (
          <li key={item.id}>
            <button
              type="button"
              onClick={() => onPreset(item.id)}
              className={`flex w-full items-center gap-4 rounded-2xl border px-4 py-3 text-left ${
                presetId === item.id ? "border-cinnabar bg-raise" : "border-transparent bg-panel"
              }`}
            >
              <span className="w-12 font-display text-xl text-cinnabar">{item.ratio}</span>
              <span className="min-w-0 flex-1">
                <span className="block truncate">{item.name}</span>
                <span className="block truncate text-sm text-mist">{item.blurb}</span>
              </span>
              <span className="text-xs text-mist">
                {item.w}×{item.h}
              </span>
            </button>
          </li>
        ))}
      </ul>
      <button type="button" className="mt-4 min-h-12 rounded-2xl bg-cinnabar text-base text-rice" onClick={onBegin}>
        Begin {preset.name.toLowerCase()}
      </button>
      <button type="button" className="mt-2 inline-flex min-h-12 items-center justify-center gap-2 text-sm text-mist" onClick={onPicture}>
        <ImagePlus className="size-4" />
        Start from a picture
      </button>
    </main>
  );
}
