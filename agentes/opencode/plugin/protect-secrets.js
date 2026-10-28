// Puerto opencode de tools/hooks/protect-secrets.js: bloquea Edit/Write sobre archivos
// de secretos/credenciales. Formato de plugin de opencode 2.x (default export { id, setup };
// hook tool.hook("execute.before") de @opencode-ai/plugin). Lanzar Error bloquea la llamada
// y el mensaje llega al modelo como motivo del fallo (verificado en vivo con opencode 2.0.30).
// En 2.x el argumento de ruta de edit/write es `path` (en 1.x era `filePath`).
const PATTERNS = [
  /(^|[\\/])\.env(\.[\w.-]+)?$/i,       // .env, .env.local, .env.production
  /\.(pem|p12|pfx|jks|keystore)$/i,     // claves y keystores
  /(^|[\\/])id_(rsa|ed25519|ecdsa)(\.pub)?$/i,
  /(^|[\\/])(credentials|secrets?)\.(json|ya?ml|toml|properties)$/i,
  /(^|[\\/])\.netrc$/i,
  /(^|[\\/])\.npmrc$/i,
];

export default {
  id: "neptuno-protect-secrets",
  setup: async (ctx) => {
    await ctx.tool.hook("execute.before", (input) => {
      if (input.tool !== "edit" && input.tool !== "write") return;
      const file = input.input?.path || input.input?.filePath || "";
      if (file && PATTERNS.some((re) => re.test(file))) {
        throw new Error(
          `BLOQUEADO por plugin NEPTUNO: "${file}" parece un archivo de secretos/credenciales. ` +
            "No se edita automáticamente. Si el usuario lo pidió explícitamente, que lo edite él o desactive el plugin."
        );
      }
    });
  },
};
