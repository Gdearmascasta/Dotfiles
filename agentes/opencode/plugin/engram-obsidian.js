// Puerto opencode de tools/hooks/engram-obsidian.js: vuelca la memoria de Engram a la bóveda de
// Obsidian. Claude Code usa el evento SessionEnd, que no existe para plugins de opencode, y la
// limpieza que devuelve setup() tampoco sirve: en opencode 2.x los plugins viven en el servicio
// persistente `opencode serve --service`, que no se cierra al acabar cada sesión (verificado: un
// `opencode run` terminó sin que la limpieza corriera). El sustituto es el evento `session.idle`
// del flujo ctx.event.subscribe(), que llega cada vez que el agente termina de responder.
// Bóveda: $NEPTUNO_OBSIDIAN_VAULT del entorno del servicio, por defecto ~/Documentos/Obsidian Vault.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const VAULT = process.env.NEPTUNO_OBSIDIAN_VAULT || path.join(os.homedir(), "Documentos", "Obsidian Vault");
// Un candado más viejo que esto es de un volcado que murió a medias, no de uno en curso.
const LOCK_STALE_MS = 120_000;
const RETRY_MS = 5_000;

// Asíncrono a propósito: un spawnSync aquí bloquearía el servicio de opencode entero.
function exportToVault() {
  if (!fs.existsSync(VAULT)) return;
  const lock = path.join(VAULT, "engram", ".neptuno-export.lock");
  fs.mkdirSync(path.dirname(lock), { recursive: true });
  try {
    fs.mkdirSync(lock);
  } catch {
    // Otro volcado en curso (este u otro agente): el siguiente session.idle lo recupera.
    if (Date.now() - fs.statSync(lock).mtimeMs < LOCK_STALE_MS) return;
    fs.rmSync(lock, { recursive: true, force: true });
    fs.mkdirSync(lock);
  }
  const release = () => fs.rmSync(lock, { recursive: true, force: true });
  const child = spawn("engram", ["obsidian-export", "--all", "--vault", VAULT], { stdio: "ignore" });
  child.on("error", release);
  child.on("close", release);
}

export default {
  id: "neptuno-engram-obsidian",
  setup: async (ctx) => {
    const abort = new AbortController();
    (async () => {
      while (!abort.signal.aborted) {
        try {
          for await (const event of ctx.event.subscribe({ signal: abort.signal })) {
            if (event?.type === "session.idle") {
              try { exportToVault(); } catch {}
            }
          }
        } catch {}
        if (!abort.signal.aborted) await new Promise((resolve) => setTimeout(resolve, RETRY_MS));
      }
    })();
    return async () => abort.abort();
  },
};
