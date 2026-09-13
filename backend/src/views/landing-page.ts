// Pagina pubblica di download dell'app Android.

import { escapeHtml, formatReleaseNotesForLanding } from "./html.js";

export interface LandingReleaseMetadata {
  version: string;
  publishedAt?: string;
  releaseNotes?: string;
}

export interface LandingReleaseStatus {
  state?: string;
}

export interface LandingPageOptions {
  baseUrl: string;
  latestRelease: LandingReleaseMetadata | null;
  releaseStatus: LandingReleaseStatus | null;
}

const landingStyles = `
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
`;

interface LandingFlags {
  hasRelease: boolean;
  isPublishing: boolean;
}

// La precedenza fra "c'e' un APK" e "stiamo pubblicando" cambia da campo a
// campo: e' il motivo per cui questi testi restano separati per gruppo.
function buildHeadline(flags: LandingFlags, version: string | undefined) {
  const { hasRelease, isPublishing } = flags;
  return {
    titleLabel: hasRelease
      ? "Download disponibile"
      : isPublishing
        ? "Nuova versione in arrivo"
        : "APK non disponibile in questo momento",
    versionValue: hasRelease
      ? `Versione ${version}`
      : isPublishing
        ? "Stiamo preparando la prossima versione"
        : "Nessuna versione disponibile in questo momento",
    detailLabel: isPublishing
      ? hasRelease
        ? "Stiamo pubblicando una nuova versione. Il download tornera disponibile appena il rilascio e completato."
        : "Stiamo pubblicando una nuova versione. Il pulsante di download comparira qui appena pronto."
      : hasRelease
        ? "Qui trovi l ultima versione disponibile dell app Android."
        : "Il download non e disponibile al momento."
  };
}

function buildReleaseDetails(
  isPublishing: boolean,
  latestRelease: LandingReleaseMetadata | null
) {
  const publishedAt = latestRelease?.publishedAt
    ? new Date(latestRelease.publishedAt).toLocaleString("it-IT", {
        dateStyle: "medium",
        timeStyle: "short"
      })
    : null;
  return {
    publishedLabel: publishedAt
      ? `Ultima pubblicazione: ${publishedAt}`
      : isPublishing
        ? "Pubblicazione in corso."
        : "Nessuna pubblicazione disponibile per ora.",
    notesLabel: latestRelease?.releaseNotes
      ? formatReleaseNotesForLanding(latestRelease.releaseNotes)
      : isPublishing
        ? "Aggiorna questa pagina tra qualche minuto per vedere la nuova versione."
        : "Controlla di nuovo piu tardi per vedere quando il download sara disponibile."
  };
}

function buildInstallItems(flags: LandingFlags) {
  if (flags.hasRelease) {
    return [
      "Apri la pagina dal telefono Android.",
      "Tocca Scarica APK.",
      "Se Android lo chiede, autorizza l installazione da questa sorgente.",
      "Quando uscira una nuova release, l app mostrera il banner update."
    ];
  }

  if (flags.isPublishing) {
    return [
      "La nuova versione e in preparazione.",
      "Il pulsante di download tornera disponibile appena il rilascio termina.",
      "Non serve fare altro: basta riaprire questa pagina."
    ];
  }

  return [
    "Al momento non c e un APK disponibile da scaricare.",
    "Quando il download sara pronto, il pulsante Scarica APK comparira qui.",
    "Puoi tornare su questa pagina piu tardi per controllare."
  ];
}

function buildInstallCopy(flags: LandingFlags) {
  const { hasRelease, isPublishing } = flags;
  return {
    installTitle: hasRelease ? "Installazione rapida" : "Disponibilita",
    installDescription: hasRelease
      ? "Il download funziona da browser mobile e desktop. Su Android devi confermare l installazione dell APK."
      : isPublishing
        ? "Il rilascio e in corso. Manteniamo disponibile qui l ultima informazione utile finche la nuova versione non e pronta."
        : "L APK non e ancora stato pubblicato. Quando sara pronto, potrai scaricarlo direttamente da questa pagina.",
    installItems: buildInstallItems(flags)
  };
}

function buildPrimaryAction(flags: LandingFlags, downloadUrl: string) {
  if (flags.isPublishing) {
    return `<span class="button disabled">APK temporaneamente non disponibile</span>`;
  }

  return flags.hasRelease
    ? `<a class="button primary" href="${escapeHtml(downloadUrl)}">Scarica APK</a>`
    : `<span class="button disabled">APK non disponibile</span>`;
}

function buildLandingCopy(options: LandingPageOptions) {
  const { baseUrl, latestRelease, releaseStatus } = options;
  const flags: LandingFlags = {
    hasRelease: latestRelease !== null,
    isPublishing: releaseStatus?.state === "publishing"
  };
  const downloadUrl = `${baseUrl}/mobile-updates/releases/latest`;

  return {
    ...buildHeadline(flags, latestRelease?.version),
    ...buildReleaseDetails(flags.isPublishing, latestRelease),
    ...buildInstallCopy(flags),
    primaryAction: buildPrimaryAction(flags, downloadUrl)
  };
}

type LandingCopy = ReturnType<typeof buildLandingCopy>;

function renderHero(copy: LandingCopy, baseUrl: string) {
  return `<section class="hero">
        <h1>Work Hours Platform</h1>
        <p>Scarica l app Android ufficiale o controlla quando sara disponibile la prossima versione.</p>
        <div class="actions">
          ${copy.primaryAction}
          <a class="button secondary" href="${escapeHtml(baseUrl)}/tickets">Invia ticket</a>
          <a class="button secondary" href="${escapeHtml(baseUrl)}/admin">Area admin</a>
        </div>
      </section>`;
}

function renderReleasePanel(copy: LandingCopy) {
  return `<article class="panel release">
          <h2>${escapeHtml(copy.titleLabel)}</h2>
          <p>${escapeHtml(copy.detailLabel)}</p>
          <p><strong>${escapeHtml(copy.versionValue)}</strong></p>
          <p>${escapeHtml(copy.publishedLabel)}</p>
          <p>${escapeHtml(copy.notesLabel)}</p>
        </article>`;
}

function renderInstallPanel(copy: LandingCopy) {
  return `<article class="panel install">
          <h2>${escapeHtml(copy.installTitle)}</h2>
          <p>${escapeHtml(copy.installDescription)}</p>
          <ul>
            ${copy.installItems.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ul>
        </article>`;
}

export function renderLandingPage(options: LandingPageOptions) {
  const copy = buildLandingCopy(options);

  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Work Hours Platform</title>
    <style>${landingStyles}</style>
  </head>
  <body>
    <main>
      ${renderHero(copy, options.baseUrl)}

      <section class="grid">
        ${renderReleasePanel(copy)}

        ${renderInstallPanel(copy)}
      </section>

      <p class="footer">Pagina servita dal backend Work Hours Platform.</p>
    </main>
  </body>
</html>`;
}
