// Pagina della dashboard admin.

import { adminStyles } from "./styles.js";
import { renderAdminBody } from "./body.js";
import { adminScriptCore } from "./script-core.js";
import { adminScriptTickets } from "./script-tickets.js";
import { adminScriptUsers } from "./script-users.js";
import { adminScriptActions } from "./script-actions.js";

// Lo script della pagina e' diviso per area solo per restare leggibile: qui
// torna un blocco unico, nello stesso ordine in cui era scritto.
const adminScript = [
  adminScriptCore,
  adminScriptTickets,
  adminScriptUsers,
  adminScriptActions
].join("");

export function renderAdminPage(options: {
  baseUrl: string;
  superAdminConfigured: boolean;
}) {
  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Admin Dashboard - Work Hours Platform</title>
    <style>${adminStyles}</style>
  </head>
${renderAdminBody(options)}
    <script>${adminScript}</script>
  </body>
</html>`;
}
