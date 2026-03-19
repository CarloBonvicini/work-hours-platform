import { randomUUID } from "node:crypto";
import { createReadStream, promises as fs } from "node:fs";
import path from "node:path";
import cors from "@fastify/cors";
import Fastify from "fastify";
import type { FastifyRequest } from "fastify";
import { InMemoryStore } from "./data/in-memory-store.js";
import type { AppStore } from "./data/store.js";
import {
  buildUniformWeekdayTargetMinutes,
  buildMonthlySummary,
  isIsoDate,
  isYearMonth,
  WEEKDAY_KEYS
} from "./domain/monthly-summary.js";
import type {
  LeaveType,
  Profile,
  WeekdayTargetMinutes
} from "./domain/types.js";

interface BuildAppOptions {
  store?: AppStore;
}

interface MobileReleaseMetadata {
  tag: string;
  version: string;
  buildNumber: string;
  fileName: string;
  releaseNotes?: string;
  publishedAt?: string;
}

interface MobileReleaseStatus {
  state: "publishing";
  tag: string;
  version: string;
  buildNumber: string;
  startedAt?: string;
}

type SupportTicketCategory = "bug" | "feature" | "support";

interface SupportTicketInput {
  category: SupportTicketCategory;
  name?: string;
  email?: string;
  subject: string;
  message: string;
  appVersion?: string;
  userAgent?: string;
}

interface SupportTicket extends SupportTicketInput {
  id: string;
  status: "new";
  createdAt: string;
}

function parseMonthQuery(query: unknown): string | null | undefined {
  if (!query || typeof query !== "object") {
    return undefined;
  }

  const monthValue = (query as Record<string, unknown>).month;
  if (monthValue === undefined) {
    return undefined;
  }

  if (typeof monthValue !== "string" || !isYearMonth(monthValue)) {
    return null;
  }

  return monthValue;
}

function isPositiveInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value > 0;
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

function isLeaveType(value: unknown): value is LeaveType {
  return value === "vacation" || value === "permit";
}

function parseWeekdayTargetMinutes(
  value: unknown
): WeekdayTargetMinutes | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const targetByWeekday = value as Record<string, unknown>;
  const weekdayTargetMinutes = {} as WeekdayTargetMinutes;

  for (const key of WEEKDAY_KEYS) {
    const dayValue = targetByWeekday[key];
    if (!isNonNegativeInteger(dayValue)) {
      return null;
    }

    weekdayTargetMinutes[key] = dayValue;
  }

  return weekdayTargetMinutes;
}

function deriveDailyTargetMinutes(
  useUniformDailyTarget: boolean,
  dailyTargetMinutes: number | undefined,
  weekdayTargetMinutes: WeekdayTargetMinutes
) {
  if (useUniformDailyTarget && dailyTargetMinutes !== undefined) {
    return dailyTargetMinutes;
  }

  const workingDayValues = [
    weekdayTargetMinutes.monday,
    weekdayTargetMinutes.tuesday,
    weekdayTargetMinutes.wednesday,
    weekdayTargetMinutes.thursday,
    weekdayTargetMinutes.friday
  ];
  const total = workingDayValues.reduce((sum, value) => sum + value, 0);

  return Math.round(total / workingDayValues.length);
}

function getUpdatesDirectory() {
  return process.env.MOBILE_UPDATES_DIR ?? "/app/updates";
}

function getReleaseMetadataPath() {
  return path.join(getUpdatesDirectory(), "latest-release.json");
}

function getReleaseStatusPath() {
  return path.join(getUpdatesDirectory(), "release-status.json");
}

function getTicketsDirectory() {
  return process.env.TICKETS_DIR ?? "/app/tickets";
}

async function loadReleaseMetadata(): Promise<MobileReleaseMetadata | null> {
  try {
    const rawValue = await fs.readFile(getReleaseMetadataPath(), "utf8");
    const parsedValue = JSON.parse(rawValue) as Partial<MobileReleaseMetadata>;
    if (
      typeof parsedValue.tag !== "string" ||
      typeof parsedValue.version !== "string" ||
      typeof parsedValue.buildNumber !== "string" ||
      typeof parsedValue.fileName !== "string"
    ) {
      return null;
    }

    return {
      tag: parsedValue.tag,
      version: parsedValue.version,
      buildNumber: parsedValue.buildNumber,
      fileName: parsedValue.fileName,
      releaseNotes: parsedValue.releaseNotes,
      publishedAt: parsedValue.publishedAt
    };
  } catch {
    return null;
  }
}

async function loadReleaseStatus(): Promise<MobileReleaseStatus | null> {
  try {
    const rawValue = await fs.readFile(getReleaseStatusPath(), "utf8");
    const parsedValue = JSON.parse(rawValue) as Partial<MobileReleaseStatus>;
    if (
      parsedValue.state !== "publishing" ||
      typeof parsedValue.tag !== "string" ||
      typeof parsedValue.version !== "string" ||
      typeof parsedValue.buildNumber !== "string"
    ) {
      return null;
    }

    return {
      state: "publishing",
      tag: parsedValue.tag,
      version: parsedValue.version,
      buildNumber: parsedValue.buildNumber,
      startedAt: parsedValue.startedAt
    };
  } catch {
    return null;
  }
}

function getPublicBaseUrl(request: FastifyRequest) {
  const configuredBaseUrl = process.env.MOBILE_UPDATES_PUBLIC_BASE_URL;
  if (configuredBaseUrl) {
    return configuredBaseUrl.replace(/\/+$/, "");
  }

  const protocol =
    typeof request.headers["x-forwarded-proto"] === "string"
      ? request.headers["x-forwarded-proto"]
      : request.protocol;

  return `${protocol}://${request.headers.host ?? "localhost:8080"}`;
}

function resolveUpdateFilePath(fileName: string) {
  const updatesDir = getUpdatesDirectory();
  const downloadsDir = path.join(updatesDir, "downloads");
  const filePath = path.resolve(downloadsDir, fileName);

  if (!filePath.startsWith(path.resolve(downloadsDir) + path.sep)) {
    return null;
  }

  return filePath;
}

function isSupportTicketCategory(value: unknown): value is SupportTicketCategory {
  return value === "bug" || value === "feature" || value === "support";
}

function normalizeOptionalText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalizedValue = value.trim();
  if (normalizedValue.length === 0) {
    return undefined;
  }

  return normalizedValue.slice(0, maxLength);
}

function normalizeRequiredText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return null;
  }

  const normalizedValue = value.trim();
  if (normalizedValue.length === 0) {
    return null;
  }

  return normalizedValue.slice(0, maxLength);
}

function isValidEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function parseSupportTicketInput(
  payload: unknown,
  userAgent: string | undefined
): { value: SupportTicketInput | null; error?: string } {
  if (!payload || typeof payload !== "object") {
    return { value: null, error: "Invalid body" };
  }

  const body = payload as Record<string, unknown>;
  if (!isSupportTicketCategory(body.category)) {
    return {
      value: null,
      error: "category must be one of: bug, feature, support"
    };
  }

  const subject = normalizeRequiredText(body.subject, 160);
  if (!subject) {
    return { value: null, error: "subject is required" };
  }

  const message = normalizeRequiredText(body.message, 4000);
  if (!message) {
    return { value: null, error: "message is required" };
  }

  const email = normalizeOptionalText(body.email, 160);
  if (email && !isValidEmail(email)) {
    return { value: null, error: "email must be valid" };
  }

  return {
    value: {
      category: body.category,
      name: normalizeOptionalText(body.name, 120),
      email,
      subject,
      message,
      appVersion: normalizeOptionalText(body.appVersion, 40),
      userAgent
    }
  };
}

async function saveSupportTicket(input: SupportTicketInput): Promise<SupportTicket> {
  const ticket: SupportTicket = {
    id: randomUUID(),
    status: "new",
    createdAt: new Date().toISOString(),
    ...input
  };

  await fs.mkdir(getTicketsDirectory(), { recursive: true });
  await fs.writeFile(
    path.join(getTicketsDirectory(), `${ticket.id}.json`),
    JSON.stringify(ticket, null, 2),
    "utf8"
  );

  return ticket;
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function formatReleaseNotesForLanding(releaseNotes: string) {
  return releaseNotes
    .replace(/ \(\d+\)(?=[.!?,]|$)/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function renderTicketPage(options: { baseUrl: string }) {
  const { baseUrl } = options;

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Ticket - Work Hours Platform</title>
    <style>
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

      .hero a {
        display: inline-flex;
        margin-top: 18px;
        color: white;
        text-decoration: none;
        font-weight: 700;
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
    </style>
  </head>
  <body>
    <main>
      <section class="hero">
        <h1>Invia un ticket</h1>
        <p>Usa questa pagina per segnalare bug, chiedere nuove funzioni o inviare una richiesta di supporto sul progetto.</p>
        <a href="${escapeHtml(baseUrl)}/">Torna al download app</a>
      </section>

      <section class="grid">
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
            <fieldset class="field">
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

            <div class="actions">
              <button id="ticket-submit" type="submit">Invia ticket</button>
              <a class="muted-link" href="${escapeHtml(baseUrl)}/">Annulla</a>
            </div>
          </form>
        </article>
      </section>
    </main>

    <script>
      const form = document.getElementById('ticket-form');
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
          const response = await fetch('${escapeHtml(baseUrl)}/tickets', {
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
      });
    </script>
  </body>
</html>`;
}

function renderLandingPage(options: {
  baseUrl: string;
  latestRelease: MobileReleaseMetadata | null;
  releaseStatus: MobileReleaseStatus | null;
}) {
  const { baseUrl, latestRelease, releaseStatus } = options;
  const downloadUrl = `${baseUrl}/mobile-updates/releases/latest`;
  const hasRelease = latestRelease !== null;
  const isPublishing = releaseStatus?.state === "publishing";
  const titleLabel = hasRelease
    ? "Download disponibile"
    : isPublishing
      ? "Nuova versione in arrivo"
      : "APK non disponibile in questo momento";
  const versionValue = hasRelease
    ? `Versione ${latestRelease.version}`
    : isPublishing
      ? "Stiamo preparando la prossima versione"
      : "Nessuna versione disponibile in questo momento";
  const detailLabel = isPublishing
    ? hasRelease
      ? "Stiamo pubblicando una nuova versione. Il download tornera disponibile appena il rilascio e completato."
      : "Stiamo pubblicando una nuova versione. Il pulsante di download comparira qui appena pronto."
    : hasRelease
      ? "Qui trovi l ultima versione disponibile dell app Android."
      : "Il download non e disponibile al momento.";
  const publishedAt = latestRelease?.publishedAt
    ? new Date(latestRelease.publishedAt).toLocaleString("it-IT", {
        dateStyle: "medium",
        timeStyle: "short"
      })
    : null;
  const publishedLabel = publishedAt
    ? `Ultima pubblicazione: ${publishedAt}`
    : isPublishing
      ? "Pubblicazione in corso."
      : "Nessuna pubblicazione disponibile per ora.";
  const notesLabel = latestRelease?.releaseNotes
    ? formatReleaseNotesForLanding(latestRelease.releaseNotes)
    : isPublishing
      ? "Aggiorna questa pagina tra qualche minuto per vedere la nuova versione."
      : "Controlla di nuovo piu tardi per vedere quando il download sara disponibile.";
  const installTitle = hasRelease ? "Installazione rapida" : "Disponibilita";
  const installDescription = hasRelease
    ? "Il download funziona da browser mobile e desktop. Su Android devi confermare l installazione dell APK."
    : isPublishing
      ? "Il rilascio e in corso. Manteniamo disponibile qui l ultima informazione utile finche la nuova versione non e pronta."
      : "L APK non e ancora stato pubblicato. Quando sara pronto, potrai scaricarlo direttamente da questa pagina.";
  const installItems = hasRelease
    ? [
        "Apri la pagina dal telefono Android.",
        "Tocca Scarica APK.",
        "Se Android lo chiede, autorizza l installazione da questa sorgente.",
        "Quando uscira una nuova release, l app mostrera il banner update."
      ]
    : isPublishing
      ? [
          "La nuova versione e in preparazione.",
          "Il pulsante di download tornera disponibile appena il rilascio termina.",
          "Non serve fare altro: basta riaprire questa pagina."
        ]
      : [
          "Al momento non c e un APK disponibile da scaricare.",
          "Quando il download sara pronto, il pulsante Scarica APK comparira qui.",
          "Puoi tornare su questa pagina piu tardi per controllare."
        ];

  const primaryAction = isPublishing
    ? `<span class="button disabled">APK temporaneamente non disponibile</span>`
    : hasRelease
      ? `<a class="button primary" href="${escapeHtml(downloadUrl)}">Scarica APK</a>`
      : `<span class="button disabled">APK non disponibile</span>`;

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Work Hours Platform</title>
    <style>
      :root {
        --page: #f4efe6;
        --card: rgba(255, 255, 255, 0.88);
        --ink: #112321;
        --muted: #4a5d58;
        --line: #d8cec0;
        --brand: #0b6e69;
        --brand-dark: #084c49;
        --accent: #e6b84c;
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
        width: min(1080px, calc(100% - 32px));
        margin: 0 auto;
        padding: 32px 0 48px;
      }

      .hero {
        background: linear-gradient(150deg, rgba(17, 49, 49, 0.98), rgba(11, 110, 105, 0.94));
        color: white;
        border-radius: 32px;
        padding: 32px;
        box-shadow: var(--shadow);
      }

      h1 {
        margin: 0 0 10px;
        font-size: clamp(40px, 6vw, 68px);
        line-height: 0.96;
        letter-spacing: -0.04em;
      }

      .hero p {
        margin: 0;
        max-width: 720px;
        color: rgba(255, 255, 255, 0.82);
        font-size: 18px;
        line-height: 1.5;
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 28px;
      }

      .button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 54px;
        padding: 0 22px;
        border-radius: 18px;
        text-decoration: none;
        font-weight: 700;
      }

      .button.primary {
        background: var(--accent);
        color: #17302d;
      }

      .button.secondary {
        background: rgba(255, 255, 255, 0.14);
        color: white;
        border: 1px solid rgba(255, 255, 255, 0.2);
      }

      .button.disabled {
        background: rgba(255, 255, 255, 0.12);
        color: rgba(255, 255, 255, 0.58);
        cursor: not-allowed;
      }

      .grid {
        display: grid;
        grid-template-columns: repeat(12, minmax(0, 1fr));
        gap: 16px;
        margin-top: 18px;
      }

      .panel {
        background: var(--card);
        border: 1px solid rgba(216, 206, 192, 0.92);
        border-radius: 24px;
        padding: 22px;
        backdrop-filter: blur(12px);
      }

      .panel h2 {
        margin: 0 0 8px;
        font-size: 24px;
        letter-spacing: -0.03em;
      }

      .panel p,
      .panel li {
        color: var(--muted);
        line-height: 1.5;
      }

      .panel strong {
        color: var(--ink);
      }

      .release {
        grid-column: span 8;
      }

      .install {
        grid-column: span 4;
      }

      ul {
        margin: 12px 0 0;
        padding-left: 18px;
      }

      .footer {
        margin-top: 18px;
        text-align: center;
        color: var(--muted);
        font-size: 14px;
      }

      @media (max-width: 860px) {
        main { width: min(100% - 24px, 1000px); padding-top: 20px; }
        .hero { padding: 24px; border-radius: 28px; }
        .release, .install { grid-column: 1 / -1; }
      }
    </style>
  </head>
  <body>
    <main>
      <section class="hero">
        <h1>Work Hours Platform</h1>
        <p>Scarica l app Android ufficiale o controlla quando sara disponibile la prossima versione.</p>
        <div class="actions">
          ${primaryAction}
          <a class="button secondary" href="${escapeHtml(baseUrl)}/tickets">Invia ticket</a>
        </div>
      </section>

      <section class="grid">
        <article class="panel release">
          <h2>${escapeHtml(titleLabel)}</h2>
          <p>${escapeHtml(detailLabel)}</p>
          <p><strong>${escapeHtml(versionValue)}</strong></p>
          <p>${escapeHtml(publishedLabel)}</p>
          <p>${escapeHtml(notesLabel)}</p>
        </article>

        <article class="panel install">
          <h2>${escapeHtml(installTitle)}</h2>
          <p>${escapeHtml(installDescription)}</p>
          <ul>
            ${installItems.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ul>
        </article>
      </section>

      <p class="footer">Pagina servita dal backend Work Hours Platform.</p>
    </main>
  </body>
</html>`;
}

export function buildApp(options: BuildAppOptions = {}) {
  const store: AppStore = options.store ?? new InMemoryStore();
  const corsOrigin = process.env.CORS_ORIGIN;

  const app = Fastify({
    logger: true
  });

  void app.register(cors, {
    origin: corsOrigin ? corsOrigin.split(",").map((value) => value.trim()) : true
  });

  app.get("/", async (request, reply) => {
    const latestRelease = await loadReleaseMetadata();
    const releaseStatus = await loadReleaseStatus();
    const baseUrl = getPublicBaseUrl(request);

    return reply
      .type("text/html; charset=utf-8")
      .send(renderLandingPage({ baseUrl, latestRelease, releaseStatus }));
  });

  app.get("/tickets", async (request, reply) => {
    const baseUrl = getPublicBaseUrl(request);

    return reply
      .type("text/html; charset=utf-8")
      .send(renderTicketPage({ baseUrl }));
  });

  app.post("/tickets", async (request, reply) => {
    const { value, error } = parseSupportTicketInput(
      request.body,
      typeof request.headers["user-agent"] === "string"
        ? request.headers["user-agent"]
        : undefined
    );
    if (!value) {
      return reply.code(400).send({ error: error ?? "Invalid ticket payload" });
    }

    const savedTicket = await saveSupportTicket(value);
    return reply.code(201).send({
      id: savedTicket.id,
      status: savedTicket.status,
      createdAt: savedTicket.createdAt
    });
  });

  app.get("/health", async () => {
    return {
      status: "ok",
      service: "work-hours-backend",
      timestamp: new Date().toISOString()
    };
  });

  app.get("/profile", async () => {
    return await store.getProfile();
  });

  app.put("/profile", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.fullName !== "string" || body.fullName.trim().length === 0) {
      return reply.code(400).send({ error: "fullName is required" });
    }

    const useUniformDailyTarget =
      body.useUniformDailyTarget === undefined
        ? true
        : body.useUniformDailyTarget === true;
    if (
      body.useUniformDailyTarget !== undefined &&
      typeof body.useUniformDailyTarget !== "boolean"
    ) {
      return reply.code(400).send({
        error: "useUniformDailyTarget must be a boolean"
      });
    }

    const parsedWeekdayTargetMinutes = parseWeekdayTargetMinutes(
      body.weekdayTargetMinutes
    );
    if (
      body.weekdayTargetMinutes !== undefined &&
      parsedWeekdayTargetMinutes === null
    ) {
      return reply.code(400).send({
        error: "weekdayTargetMinutes must include monday-sunday non-negative integers"
      });
    }

    if (useUniformDailyTarget && !isPositiveInteger(body.dailyTargetMinutes)) {
      return reply.code(400).send({
        error: "dailyTargetMinutes must be a positive integer"
      });
    }

    const weekdayTargetMinutes = useUniformDailyTarget
      ? buildUniformWeekdayTargetMinutes(body.dailyTargetMinutes as number)
      : parsedWeekdayTargetMinutes;

    if (!weekdayTargetMinutes) {
      return reply.code(400).send({
        error: "weekdayTargetMinutes is required when useUniformDailyTarget is false"
      });
    }

    const dailyTargetMinutes = deriveDailyTargetMinutes(
      useUniformDailyTarget,
      isPositiveInteger(body.dailyTargetMinutes)
        ? body.dailyTargetMinutes
        : undefined,
      weekdayTargetMinutes
    );

    const profile: Profile = {
      id: "default-profile",
      fullName: body.fullName.trim(),
      useUniformDailyTarget,
      dailyTargetMinutes,
      weekdayTargetMinutes
    };

    return await store.saveProfile(profile);
  });

  app.get("/work-entries", async (request, reply) => {
    const month = parseMonthQuery(request.query);
    if (month === null) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    return {
      items: await store.listWorkEntries(month)
    };
  });

  app.post("/work-entries", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.date !== "string" || !isIsoDate(body.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    if (!isPositiveInteger(body.minutes)) {
      return reply.code(400).send({ error: "minutes must be a positive integer" });
    }

    if (body.note !== undefined && typeof body.note !== "string") {
      return reply.code(400).send({ error: "note must be a string" });
    }

    const entry = await store.addWorkEntry({
      id: randomUUID(),
      date: body.date,
      minutes: body.minutes,
      note: typeof body.note === "string" ? body.note : undefined
    });

    return reply.code(201).send(entry);
  });

  app.get("/leave-entries", async (request, reply) => {
    const month = parseMonthQuery(request.query);
    if (month === null) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    return {
      items: await store.listLeaveEntries(month)
    };
  });

  app.post("/leave-entries", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.date !== "string" || !isIsoDate(body.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    if (!isPositiveInteger(body.minutes)) {
      return reply.code(400).send({ error: "minutes must be a positive integer" });
    }

    if (!isLeaveType(body.type)) {
      return reply.code(400).send({ error: "type must be 'vacation' or 'permit'" });
    }

    if (body.note !== undefined && typeof body.note !== "string") {
      return reply.code(400).send({ error: "note must be a string" });
    }

    const entry = await store.addLeaveEntry({
      id: randomUUID(),
      date: body.date,
      minutes: body.minutes,
      type: body.type,
      note: typeof body.note === "string" ? body.note : undefined
    });

    return reply.code(201).send(entry);
  });

  app.get("/schedule-overrides", async (request, reply) => {
    const month = parseMonthQuery(request.query);
    if (month === null) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    return {
      items: await store.listScheduleOverrides(month)
    };
  });

  app.post("/schedule-overrides", async (request, reply) => {
    const payload = request.body;
    if (!payload || typeof payload !== "object") {
      return reply.code(400).send({ error: "Invalid body" });
    }

    const body = payload as Record<string, unknown>;
    if (typeof body.date !== "string" || !isIsoDate(body.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    if (!isNonNegativeInteger(body.targetMinutes)) {
      return reply.code(400).send({
        error: "targetMinutes must be a non-negative integer"
      });
    }

    if (body.note !== undefined && typeof body.note !== "string") {
      return reply.code(400).send({ error: "note must be a string" });
    }

    const entry = await store.saveScheduleOverride({
      id: randomUUID(),
      date: body.date,
      targetMinutes: body.targetMinutes,
      note: typeof body.note === "string" ? body.note : undefined
    });

    return reply.code(201).send(entry);
  });

  app.delete("/schedule-overrides/:date", async (request, reply) => {
    const params = request.params as { date?: unknown };
    if (typeof params.date !== "string" || !isIsoDate(params.date)) {
      return reply.code(400).send({ error: "date must be in YYYY-MM-DD format" });
    }

    const wasRemoved = await store.removeScheduleOverride(params.date);
    if (!wasRemoved) {
      return reply.code(404).send({ error: "Schedule override not found" });
    }

    return reply.code(204).send();
  });

  app.get("/monthly-summary/:month", async (request, reply) => {
    const params = request.params as { month?: unknown };
    if (typeof params.month !== "string" || !isYearMonth(params.month)) {
      return reply.code(400).send({ error: "month must be in YYYY-MM format" });
    }

    const month = params.month;
    const profile = await store.getProfile();
    const workEntries = await store.listWorkEntries(month);
    const leaveEntries = await store.listLeaveEntries(month);
    const scheduleOverrides = await store.listScheduleOverrides(month);

    return buildMonthlySummary(
      month,
      profile,
      workEntries,
      leaveEntries,
      scheduleOverrides
    );
  });

  app.get("/mobile-updates/latest.json", async (request, reply) => {
    const metadata = await loadReleaseMetadata();
    if (!metadata) {
      return reply.code(404).send({ error: "No mobile release published" });
    }

    const baseUrl = getPublicBaseUrl(request);

    return {
      tag_name: metadata.tag,
      name: `Work Hours Mobile ${metadata.version}`,
      html_url: `${baseUrl}/mobile-updates/releases/latest`,
      published_at: metadata.publishedAt ?? null,
      body: metadata.releaseNotes ?? null,
      assets: [
        {
          name: metadata.fileName,
          browser_download_url:
            `${baseUrl}/mobile-updates/downloads/${encodeURIComponent(metadata.fileName)}`
        }
      ]
    };
  });

  app.get("/mobile-updates/releases/latest", async (request, reply) => {
    const metadata = await loadReleaseMetadata();
    if (!metadata) {
      return reply.code(404).send({ error: "No mobile release published" });
    }

    const baseUrl = getPublicBaseUrl(request);
    return reply.redirect(
      `${baseUrl}/mobile-updates/downloads/${encodeURIComponent(metadata.fileName)}`
    );
  });

  app.get("/mobile-updates/downloads/:fileName", async (request, reply) => {
    const params = request.params as { fileName?: unknown };
    if (typeof params.fileName !== "string" || params.fileName.length === 0) {
      return reply.code(400).send({ error: "fileName is required" });
    }

    const filePath = resolveUpdateFilePath(params.fileName);
    if (!filePath) {
      return reply.code(400).send({ error: "Invalid file name" });
    }

    try {
      await fs.access(filePath);
    } catch {
      return reply.code(404).send({ error: "Update file not found" });
    }

    reply
      .type("application/vnd.android.package-archive")
      .header(
        "content-disposition",
        `attachment; filename="${path.basename(filePath)}"`
      );

    return reply.send(createReadStream(filePath));
  });

  return app;
}
