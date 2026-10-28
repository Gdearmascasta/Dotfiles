// Hook SessionEnd: vuelca la memoria de Engram a la bóveda de Obsidian (notas + vista de grafo)
// con `engram obsidian-export`, que es incremental: Engram guarda su estado de sincronización en
// <bóveda>/engram/.engram-sync-state.json y solo reescribe lo nuevo. Silencioso si falta el
// binario o la bóveda: la memoria sigue en Engram aunque el volcado no ocurra.
// Bóveda: $NEPTUNO_OBSIDIAN_VAULT, por defecto ~/Documentos/Obsidian Vault.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const VAULT = process.env.NEPTUNO_OBSIDIAN_VAULT || path.join(os.homedir(), 'Documentos', 'Obsidian Vault');
// Un candado más viejo que esto es de un volcado que murió a medias, no de uno en curso.
const LOCK_STALE_MS = 120_000;

function exportToVault() {
  if (!fs.existsSync(VAULT)) return;
  const lock = path.join(VAULT, 'engram', '.neptuno-export.lock');
  fs.mkdirSync(path.dirname(lock), { recursive: true });
  try {
    fs.mkdirSync(lock);
  } catch {
    // Otro agente (Claude Code y opencode cierran a la vez) ya está volcando.
    if (Date.now() - fs.statSync(lock).mtimeMs < LOCK_STALE_MS) return;
    fs.rmSync(lock, { recursive: true, force: true });
    fs.mkdirSync(lock);
  }
  try {
    spawnSync('engram', ['obsidian-export', '--all', '--vault', VAULT], { stdio: 'ignore', timeout: 60_000 });
  } finally {
    fs.rmSync(lock, { recursive: true, force: true });
  }
}

if (require.main === module) {
  process.stdin.resume();
  process.stdin.on('end', () => {
    try { exportToVault(); } catch {}
    process.exit(0);
  });
}

module.exports = { exportToVault, VAULT };
