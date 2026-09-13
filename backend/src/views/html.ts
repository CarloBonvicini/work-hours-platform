// Utilita condivise dalle pagine HTML servite dal backend.

export function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function formatReleaseNotesForLanding(releaseNotes: string) {
  return releaseNotes
    .replace(/ \(\d+\)(?=[.!?,]|$)/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}
