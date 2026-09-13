// Pagina pubblica di invio ticket.

import { escapeHtml } from "./html.js";

const ticketStyles = `
      :root {
        --page: #f4efe6;
        --card: rgba(255, 255, 255, 0.9);
        --ink: #112321;
        --muted: #4a5d58;
        --line: #d8cec0;
        --brand: #0b6e69;
        --brand-dark: #084c49;
        --accent: #e6b84c;
        --danger: #9d3d2f;
        --shadow: 0 28px 80px rgba(17, 35, 33, 0.12);
      }

      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
        color: var(--ink);
        background:
          radial-gradient(circle at top left, rgba(11, 110, 105, 0.18), transparent 34%),
          radial-gradient(circle at top right, rgba(230, 184, 76, 0.22), transparent 28%),
          linear-gradient(180deg, #faf6ee 0%, var(--page) 100%);
      }

      main {
        width: min(980px, calc(100% - 32px));
        margin: 0 auto;
        padding: 32px 0 48px;
      }

      .hero,
      .panel {
        background: var(--card);
        border: 1px solid rgba(216, 206, 192, 0.92);
        border-radius: 28px;
        box-shadow: var(--shadow);
      }

      .hero {
        background: linear-gradient(150deg, rgba(17, 49, 49, 0.98), rgba(11, 110, 105, 0.94));
        color: white;
        padding: 28px;
      }

      h1 {
        margin: 0 0 10px;
        font-size: clamp(34px, 5vw, 56px);
        line-height: 0.96;
        letter-spacing: -0.04em;
      }

      .hero p {
        margin: 0;
        max-width: 720px;
        color: rgba(255, 255, 255, 0.84);
        font-size: 18px;
        line-height: 1.5;
      }

      .hero-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 18px;
      }

      .hero-link {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 48px;
        padding: 0 18px;
        border-radius: 16px;
        text-decoration: none;
        font-weight: 700;
        color: white;
        border: 1px solid rgba(255, 255, 255, 0.22);
        background: rgba(255, 255, 255, 0.12);
      }

      .panel {
        margin-top: 18px;
        padding: 24px;
      }

      .grid {
        display: grid;
        grid-template-columns: repeat(12, minmax(0, 1fr));
        gap: 16px;
      }

      .intro {
        grid-column: span 4;
      }

      .form-panel {
        grid-column: span 8;
      }

      h2 {
        margin: 0 0 8px;
        font-size: 26px;
        letter-spacing: -0.03em;
      }

      p,
      li,
      label,
      legend {
        color: var(--muted);
        line-height: 1.5;
      }

      .stack {
        display: grid;
        gap: 16px;
      }

      .field {
        display: grid;
        gap: 8px;
      }

      .field-row {
        display: grid;
        gap: 16px;
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      input,
      textarea,
      select {
        width: 100%;
        border-radius: 18px;
        border: 1px solid var(--line);
        padding: 14px 16px;
        font: inherit;
        color: var(--ink);
        background: white;
      }

      textarea {
        min-height: 180px;
        resize: vertical;
      }

      fieldset {
        margin: 0;
        padding: 0;
        border: 0;
      }

      .choices {
        display: grid;
        gap: 12px;
      }

      .choice {
        display: grid;
        grid-template-columns: auto 1fr;
        gap: 12px;
        align-items: start;
        padding: 14px 16px;
        border: 1px solid var(--line);
        border-radius: 18px;
        background: rgba(255, 255, 255, 0.6);
      }

      .choice strong {
        display: block;
        color: var(--ink);
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        align-items: center;
      }

      button {
        border: 0;
        border-radius: 18px;
        min-height: 54px;
        padding: 0 22px;
        font: inherit;
        font-weight: 700;
        cursor: pointer;
        background: var(--accent);
        color: #17302d;
      }

      button:disabled {
        cursor: wait;
        opacity: 0.6;
      }

      .muted-link {
        color: var(--brand-dark);
        text-decoration: none;
        font-weight: 700;
      }

      .status {
        display: none;
        padding: 14px 16px;
        border-radius: 18px;
        font-weight: 600;
      }

      .status.success {
        display: block;
        background: rgba(11, 110, 105, 0.12);
        color: var(--brand-dark);
      }

      .status.error {
        display: block;
        background: rgba(157, 61, 47, 0.12);
        color: var(--danger);
      }

      ul {
        margin: 12px 0 0;
        padding-left: 18px;
      }

      @media (max-width: 860px) {
        main { width: min(100% - 24px, 980px); padding-top: 20px; }
        .intro, .form-panel { grid-column: 1 / -1; }
        .field-row { grid-template-columns: 1fr; }
      }
`;

// I campi non dipendono da nulla: restano una costante, non una funzione.
const ticketFields = `            <fieldset class="field">
              <legend>Tipo di ticket</legend>
              <div class="choices">
                <label class="choice">
                  <input type="radio" name="category" value="bug" checked />
                  <span><strong>Bug</strong>Segnala un problema che hai trovato.</span>
                </label>
                <label class="choice">
                  <input type="radio" name="category" value="feature" />
                  <span><strong>Nuova funzione</strong>Proponi una funzione o un miglioramento.</span>
                </label>
                <label class="choice">
                  <input type="radio" name="category" value="support" />
                  <span><strong>Supporto</strong>Scrivi per dubbi, blocchi o chiarimenti.</span>
                </label>
              </div>
            </fieldset>

            <div class="field-row">
              <label class="field">
                <span>Nome</span>
                <input name="name" type="text" maxlength="120" placeholder="Come ti chiami" />
              </label>
              <label class="field">
                <span>Email</span>
                <input name="email" type="email" maxlength="160" placeholder="Se vuoi una risposta" />
              </label>
            </div>

            <div class="field-row">
              <label class="field">
                <span>Oggetto</span>
                <input name="subject" type="text" maxlength="160" required placeholder="Riassunto breve" />
              </label>
              <label class="field">
                <span>Versione app</span>
                <input name="appVersion" type="text" maxlength="40" placeholder="Facoltativa" />
              </label>
            </div>

            <label class="field">
              <span>Messaggio</span>
              <textarea name="message" required maxlength="4000" placeholder="Descrivi il problema o la richiesta nel modo piu chiaro possibile"></textarea>
            </label>

            <div id="ticket-status" class="status"></div>
`;

// L'endpoint diventa una variabile del documento, cosi' lo script e' statico.
const ticketScript = `      const form = document.getElementById('ticket-form');
      const submitButton = document.getElementById('ticket-submit');
      const statusBox = document.getElementById('ticket-status');

      form.addEventListener('submit', async (event) => {
        event.preventDefault();
        statusBox.className = 'status';
        statusBox.textContent = '';
        submitButton.disabled = true;
        submitButton.textContent = 'Invio in corso...';

        const formData = new FormData(form);
        const payload = {
          category: formData.get('category'),
          name: formData.get('name'),
          email: formData.get('email'),
          subject: formData.get('subject'),
          message: formData.get('message'),
          appVersion: formData.get('appVersion')
        };

        try {
          const response = await fetch(ticketsEndpoint, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(payload)
          });
          const result = await response.json().catch(() => ({}));

          if (!response.ok) {
            throw new Error(result.error || 'Non siamo riusciti a inviare il ticket.');
          }

          form.reset();
          const bugChoice = form.querySelector('input[name="category"][value="bug"]');
          if (bugChoice) bugChoice.checked = true;
          statusBox.className = 'status success';
          statusBox.textContent = 'Ticket inviato. Grazie, lo prendiamo in carico.';
        } catch (error) {
          statusBox.className = 'status error';
          statusBox.textContent = error instanceof Error
            ? error.message
            : 'Non siamo riusciti a inviare il ticket.';
        } finally {
          submitButton.disabled = false;
          submitButton.textContent = 'Invia ticket';
        }
      });`;

function renderTicketHero(baseUrl: string) {
  return `      <section class="hero">
        <h1>Invia un ticket</h1>
        <p>Usa questa pagina per segnalare bug, chiedere nuove funzioni o inviare una richiesta di supporto sul progetto.</p>
        <div class="hero-actions">
          <a class="hero-link" href="${escapeHtml(baseUrl)}/">Torna al download app</a>
          <a class="hero-link" href="${escapeHtml(baseUrl)}/admin">Area admin</a>
        </div>
      </section>`;
}

function renderTicketForm(baseUrl: string) {
  return `      <section class="grid">
        <article class="panel intro">
          <h2>Quando usarlo</h2>
          <p>Ti conviene aprire un ticket quando vuoi far arrivare un problema o una richiesta in modo ordinato e rintracciabile.</p>
          <ul>
            <li>Bug o comportamento anomalo dell app</li>
            <li>Nuove funzioni o miglioramenti desiderati</li>
            <li>Dubbi pratici su uso, installazione o aggiornamenti</li>
          </ul>
        </article>

        <article class="panel form-panel">
          <h2>Raccontaci cosa ti serve</h2>
          <form id="ticket-form" class="stack">
${ticketFields}
            <div class="actions">
              <button id="ticket-submit" type="submit">Invia ticket</button>
              <a class="muted-link" href="${escapeHtml(baseUrl)}/">Annulla</a>
            </div>
          </form>
        </article>
      </section>`;
}

export function renderTicketPage(options: { baseUrl: string }) {
  const { baseUrl } = options;

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Ticket - Work Hours Platform</title>
    <style>${ticketStyles}</style>
  </head>
  <body>
    <main>
${renderTicketHero(baseUrl)}

${renderTicketForm(baseUrl)}
    </main>

    <script>
      const ticketsEndpoint = '${escapeHtml(baseUrl)}/tickets';
${ticketScript}
    </script>
  </body>
</html>`;
}
