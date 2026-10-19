import type { WorkRecord } from "@/lib/ink/model";

const DB_NAME = "vermilion-atelier";
const STORE = "works";
const memory = new Map<string, WorkRecord>();
let useMemory = false;

function openDb() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE, { keyPath: "id" });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function listWorks(): Promise<WorkRecord[]> {
  if (useMemory) return [...memory.values()].sort((a, b) => b.updatedAt - a.updatedAt);
  try {
    const db = await openDb();
    const rows = await new Promise<WorkRecord[]>((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const req = tx.objectStore(STORE).getAll();
      req.onsuccess = () => resolve(req.result as WorkRecord[]);
      req.onerror = () => reject(req.error);
    });
    db.close();
    return rows.sort((a, b) => b.updatedAt - a.updatedAt);
  } catch {
    useMemory = true;
    return [...memory.values()].sort((a, b) => b.updatedAt - a.updatedAt);
  }
}

export async function putWork(work: WorkRecord) {
  if (useMemory) {
    memory.set(work.id, work);
    return;
  }
  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.objectStore(STORE).put(work);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  } catch {
    useMemory = true;
    memory.set(work.id, work);
  }
}

export async function deleteWork(id: string) {
  if (useMemory) {
    memory.delete(id);
    return;
  }
  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.objectStore(STORE).delete(id);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  } catch {
    useMemory = true;
    memory.delete(id);
  }
}
