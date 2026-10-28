// Puerto opencode de tools/hooks/handoff-reminder.js: si el proyecto tiene HANDOFF.md,
// inyecta el recordatorio de leerlo. Claude Code usa el evento SessionStart, que no existe
// para plugins de opencode; el sustituto en opencode 2.x es session.hook("context"), que se
// dispara en CADA llamada al modelo con el system prompt reconstruido desde cero (verificado
// en vivo con 2.0.30), así que el texto se calcula una vez por sesión y se reinyecta siempre.
import fs from "node:fs";
import path from "node:path";

export default {
  id: "neptuno-handoff-reminder",
  setup: async (ctx) => {
    const cache = new Map();
    const reminder = async (sessionID) => {
      const session = await ctx.session.get({ sessionID });
      const directory = session?.location?.directory || process.cwd();
      const handoff = path.join(directory, "HANDOFF.md");
      if (!fs.existsSync(handoff)) return null;
      const mtime = fs.statSync(handoff).mtime.toISOString().slice(0, 10);
      return `[plugin NEPTUNO] Existe HANDOFF.md (modificado ${mtime}). Si el usuario retoma un trabajo, léelo ANTES de hacer nada: contiene estado, decisiones tomadas y callejones ya explorados.`;
    };

    await ctx.session.hook("context", async (input) => {
      if (!cache.has(input.sessionID)) cache.set(input.sessionID, await reminder(input.sessionID));
      const text = cache.get(input.sessionID);
      if (text) input.system.push({ type: "text", text });
    });
  },
};
