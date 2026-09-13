// Struttura della pagina della dashboard admin.

import { escapeHtml } from "../html.js";

// La sezione di accesso non ha parti dinamiche: e' un dato, non una funzione.
const adminAuthSection = `      <section class="panel auth-stage" id="admin-auth-panel">
        <div class="card auth-shell">
          <section class="auth-view">
            <h2>Accesso admin</h2>
            <p class="lede">Accedi con un profilo gia autorizzato. Se devi prima creare un account, apri la registrazione dal link qui sotto.</p>
            <div id="admin-auth-status" class="status info">Accedi con un profilo admin per aprire la dashboard.</div>
            <div class="auth-grid">
              <article class="workspace-card auth-card" id="admin-login-card">
                <span class="pill info">Login</span>
                <div>
                  <h3>Entra in dashboard</h3>
                  <p class="lede">Accedi con email e password del super admin o di un admin gia promosso.</p>
                </div>
                <form id="admin-login-form">
                  <label>Email
                    <input id="admin-email-input" type="email" autocomplete="username" placeholder="admin@example.com" required />
                  </label>
                  <label>Password
                    <input id="admin-password-input" type="password" autocomplete="current-password" placeholder="Password" required />
                  </label>
                  <div class="toolbar-actions" style="justify-content:flex-start;">
                    <button class="primary" id="admin-login-btn" type="submit">Login</button>
                  </div>
                </form>
                <div class="auth-switch">
                  <span>Non hai ancora un profilo?</span>
                  <button class="link-button" id="admin-show-register-btn" type="button">Registrati</button>
                </div>
              </article>

              <article class="workspace-card auth-card hidden" id="admin-register-card">
                <span class="pill success">Registrazione</span>
                <div>
                  <h3>Registra profilo</h3>
                  <p class="lede">La registrazione crea un account normale. Solo il super admin puo promuoverti ad admin.</p>
                </div>
                <form id="admin-register-form">
                  <label>Email
                    <input id="admin-register-email-input" type="email" autocomplete="username" placeholder="utente@example.com" required />
                  </label>
                  <label>Password
                    <input id="admin-register-password-input" type="password" autocomplete="new-password" placeholder="Scegli la password" required />
                  </label>
                  <div class="toolbar-actions" style="justify-content:flex-start;">
                    <button type="submit">Registrati</button>
                  </div>
                </form>
                <div class="auth-switch">
                  <span>Hai gia un profilo?</span>
                  <button class="link-button" id="admin-show-login-btn" type="button">Torna al login</button>
                </div>
              </article>
            </div>
            <p class="auth-cta" id="admin-auth-cta">La registrazione non rende admin in automatico. Solo il <code>super_admin</code> puo promuovere o revocare gli altri admin.</p>
          </section>
        </div>
      </section>
`;

function renderAdminHero(baseUrl: string) {
  return `      <section class="hero">
        <div class="hero-actions">
          <a class="ghost-link" href="${escapeHtml(baseUrl)}/">Home</a>
          <a class="ghost-link" href="${escapeHtml(baseUrl)}/tickets">Ticket pubblici</a>
        </div>
        <div class="brand-lockup" aria-hidden="true">
          <div class="brand-mark brand-mark-glow"></div>
          <div class="brand-mark brand-mark-main"></div>
        </div>
        <p class="eyebrow">Work Hours Platform</p>
        <h1>Admin Console</h1>
      </section>
`;
}

// Le sezioni senza link dinamici restano costanti.
const adminOverviewSection = `        <section class="console-section" id="overview-section">
          <div class="section-heading">
            <div class="section-heading-copy">
              <h3>Overview</h3>
              <p>Segnali rapidi per release, provider e coda ticket. La parte alta resta panoramica, il workspace operativo vive sotto come nell altra admin.</p>
            </div>
          </div>
          <div class="stats" id="admin-stats"></div>
        </section>
`;

const adminTicketsPanels = `              <div class="ticket-workspace">
                <section class="card" style="padding:16px;">
              <div class="toolbar">
                <div>
                  <h3 style="margin-bottom:6px;">Ticket</h3>
                  <p class="lede">Seleziona un ticket per aprire messaggi, allegati (anche vocali) e risposta admin.</p>
                </div>
                <button type="button" id="admin-refresh-tickets-btn">Aggiorna</button>
              </div>
                  <div class="ticket-list" id="admin-ticket-list" style="margin-top:14px;"></div>
                </section>
                <section class="card" style="padding:18px;" id="admin-ticket-detail"></section>
              </div>
              <section class="card" style="padding:16px;" id="admin-user-management-section">
                <div class="toolbar">
                  <div>
                    <h3 style="margin-bottom:6px;">Accessi e ruoli</h3>
                    <p class="lede">Solo il super admin puo promuovere, revocare accessi admin e resettare password.</p>
                  </div>
                  <button type="button" id="admin-refresh-users-btn">Aggiorna utenti</button>
                </div>
                <div style="margin-top:14px; display:grid; gap:10px;">
                  <label class="field">
                    <span class="field-label">Ricerca utenti</span>
                    <input id="admin-user-search-input" type="search" placeholder="Cerca per email" />
                  </label>
                  <form id="admin-create-user-form" class="reply-form">
                    <div class="field-label">Crea utente</div>
                    <div class="detail-grid">
                      <label class="field">
                        <span class="field-label">Email</span>
                        <input id="admin-create-user-email-input" type="email" placeholder="utente@example.com" required />
                      </label>
                      <label class="field">
                        <span class="field-label">Password</span>
                        <input id="admin-create-user-password-input" type="password" placeholder="Scegli la password" required />
                      </label>
                      <label class="field">
                        <span class="field-label">Ruolo</span>
                        <select id="admin-create-user-role-input">
                          <option value="user">Utente</option>
                          <option value="admin">Admin</option>
                        </select>
                      </label>
                    </div>
                    <div class="reply-actions">
                      <button type="submit" class="primary">Crea utente</button>
                    </div>
                  </form>
                </div>
                <div class="user-list" id="admin-user-list" style="margin-top:14px;"></div>
              </section>
            </div>
          </div>
        </section>`;

function renderAdminToolbar(baseUrl: string) {
  return `        <div class="toolbar console-toolbar">
          <div>
            <p class="eyebrow" style="margin-bottom:8px;">Sessione Admin</p>
            <h2 style="margin-bottom:6px;">Admin Dashboard</h2>
            <p class="lede" id="admin-session-copy">Monitoraggio release, data provider e thread ticket.</p>
          </div>
          <div class="toolbar-actions">
            <a class="ghost-link toolbar-quick-link" href="${escapeHtml(baseUrl)}/">Home</a>
            <a class="ghost-link toolbar-quick-link" href="${escapeHtml(baseUrl)}/tickets">Ticket pubblici</a>
            <button type="button" id="admin-refresh-btn">Refresh all</button>
            <button type="button" id="admin-logout-btn">Logout</button>
          </div>
        </div>
        <div id="admin-status" class="status info">Caricamento dashboard...</div>
`;
}

// Intestazione della inbox: nessun link dinamico.
const adminTicketsHeading = `        <section class="console-section" id="tickets-section">
          <div class="section-heading">
            <div class="section-heading-copy">
              <h3>Support Inbox</h3>
              <p>Prima scorri l inbox, poi apri il dettaglio solo sul ticket che vuoi gestire.</p>
            </div>
          </div>
          <div class="admin-console-layout">
            <aside class="card workspace-nav" aria-label="Admin workspace">
              <h4>Workspace</h4>
              <div class="workspace-stack">
                <article class="workspace-card">
                  <div class="mini-label">Profilo</div>
                  <div class="workspace-value" id="admin-session-email">Sessione non caricata</div>
                  <p class="lede" id="admin-generated-at">Ultimo aggiornamento: -</p>
                </article>
                <article class="workspace-card">
                  <div class="mini-label">Ambiente</div>
                  <div class="workspace-value" id="admin-service-label">work-hours-backend</div>
                  <p class="lede" id="admin-provider-note">Provider dati: -</p>`;

function renderAdminWorkspaceLinks(baseUrl: string) {
  return `                </article>
                <article class="workspace-card">
                  <div class="mini-label">Link rapidi</div>
                  <div class="quick-link-grid">
                    <a class="ghost-link" id="admin-health-link" href="${escapeHtml(baseUrl)}/health" target="_blank" rel="noreferrer">Health</a>
                    <a class="ghost-link" id="admin-feed-link" href="${escapeHtml(baseUrl)}/mobile-updates/latest.json" target="_blank" rel="noreferrer">Feed release</a>
                    <a class="ghost-link" id="admin-public-tickets-link" href="${escapeHtml(baseUrl)}/tickets" target="_blank" rel="noreferrer">Ticket pubblici</a>
                  </div>
                </article>
                <article class="workspace-card">
                  <div class="mini-label">Queue ticket</div>
                  <div class="metric-row"><span>Nuovi</span><strong id="admin-ticket-waiting">0</strong></div>
                  <div class="metric-row"><span>In lavorazione</span><strong id="admin-ticket-progress">0</strong></div>
                  <div class="metric-row"><span>Risposti</span><strong id="admin-ticket-answered">0</strong></div>
                  <div class="metric-row"><span>Chiusi</span><strong id="admin-ticket-closed">0</strong></div>
                </article>
              </div>
            </aside>

            <div class="admin-content-grid">`;
}

function renderAdminTicketsSection(baseUrl: string) {
  return `${adminTicketsHeading}
${renderAdminWorkspaceLinks(baseUrl)}
${adminTicketsPanels}`;
}

function renderAdminDashboardSection(baseUrl: string) {
  return `      <section class="panel hidden" id="admin-dashboard-panel">
${renderAdminToolbar(baseUrl)}

${adminOverviewSection}

${renderAdminTicketsSection(baseUrl)}
      </section>`;
}

export function renderAdminBody(options: {
  baseUrl: string;
  superAdminConfigured: boolean;
}) {
  const { baseUrl, superAdminConfigured } = options;

  return `  <body
    data-base-url="${escapeHtml(baseUrl)}"
    data-super-admin-configured="${superAdminConfigured ? "true" : "false"}"
  >
    <main class="shell">
${renderAdminHero(baseUrl)}

${adminAuthSection}

${renderAdminDashboardSection(baseUrl)}
    </main>`;
}
