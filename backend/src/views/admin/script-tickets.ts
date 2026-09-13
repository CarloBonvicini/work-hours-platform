// Rendering di ticket, allegati e riepiloghi della dashboard admin.
//
// Blocco di JavaScript servito nella pagina: e' testo, non codice del
// backend, e legge la configurazione da `data-base-url` sul body.

export const adminScriptTickets = `
      function statusBadge(status) {
        const labels = { new: "Nuovo", in_progress: "In lavorazione", answered: "Risposto", closed: "Chiuso" };
        return '<span class="badge status-' + escapeHtml(status) + '">' + (labels[status] || status) + '</span>';
      }
      function categoryBadge(category) {
        const labels = { bug: "Bug", feature: "Feature", support: "Supporto" };
        return '<span class="badge category-' + escapeHtml(category) + '">' + (labels[category] || category) + '</span>';
      }
      function resolveTicketAssetUrl(path) {
        if (typeof path !== "string" || path.length === 0) {
          return "#";
        }
        if (path.startsWith("http://") || path.startsWith("https://")) {
          return path;
        }
        return resolveApiUrl(path);
      }
      function isImageAttachment(contentType) {
        return typeof contentType === "string" && contentType.startsWith("image/");
      }
      function isAudioAttachment(contentType) {
        return typeof contentType === "string" && contentType.startsWith("audio/");
      }
      function renderAttachmentCard(attachment) {
        const rawUrl = resolveTicketAssetUrl(attachment.downloadPath || "#");
        const downloadUrl = escapeHtml(rawUrl);
        const fileName = escapeHtml(attachment.fileName || "Allegato");
        const contentType = escapeHtml(attachment.contentType || "file");
        const sizeLabel = escapeHtml(formatBytes(attachment.sizeBytes));

        if (isAudioAttachment(attachment.contentType)) {
          return '<article class="attachment-card"><audio class="attachment-audio-player" controls preload="none" src="' + downloadUrl + '"></audio><div class="attachment-name">' + fileName + '</div><div class="attachment-meta">' + contentType + ' - ' + sizeLabel + '</div><a class="attachment-link" target="_blank" rel="noreferrer" href="' + downloadUrl + '">Apri allegato</a></article>';
        }

        const preview = isImageAttachment(attachment.contentType)
          ? '<img class="attachment-preview" loading="lazy" src="' + downloadUrl + '" alt="' + fileName + '" />'
          : '<div class="attachment-preview placeholder">Anteprima non disponibile</div>';
        return '<a class="attachment-card" target="_blank" rel="noreferrer" href="' + downloadUrl + '">' + preview + '<div class="attachment-name">' + fileName + '</div><div class="attachment-meta">' + contentType + ' - ' + sizeLabel + '</div></a>';
      }
      function renderWorkspaceSummary() {
        const overview = state.overview;
        const user = state.adminUser;
        if (sessionEmail) sessionEmail.textContent = user && user.email ? user.email : "Sessione non caricata";
        if (generatedAtLabel) generatedAtLabel.textContent = "Ultimo aggiornamento: " + (overview ? formatDateTime(overview.generatedAt) : "-");
        if (serviceLabel) serviceLabel.textContent = overview ? String(overview.service || "work-hours-backend") : "work-hours-backend";
        if (providerNote) providerNote.textContent = "Provider dati: " + (overview ? String(overview.dataProvider || "-") : "-");
        if (sessionCopy) {
          const currentVersion = overview && overview.release && overview.release.current
            ? String(overview.release.current.version || overview.release.current.tag || "n/d")
            : "nessuna release";
          const roleLabel = user && user.isSuperAdmin
            ? "super admin"
            : user && user.isAdmin
              ? "admin"
              : "utente";
          sessionCopy.textContent = user && user.email
            ? "Sessione " + roleLabel + " attiva per " + user.email + ". Release live: " + currentVersion + "."
            : "Monitoraggio release, data provider e thread ticket.";
        }
        if (healthLink && overview && overview.links) healthLink.href = String(overview.links.health || healthLink.href);
        if (feedLink && overview && overview.links) feedLink.href = String(overview.links.releaseFeed || feedLink.href);
        if (publicTicketsLink && overview && overview.links) publicTicketsLink.href = String(overview.links.publicTickets || publicTicketsLink.href);
        if (waitingCount) waitingCount.textContent = overview ? String(overview.tickets.waiting || 0) : "0";
        if (inProgressCount) inProgressCount.textContent = overview ? String(overview.tickets.inProgress || 0) : "0";
        if (answeredCount) answeredCount.textContent = overview ? String(overview.tickets.answered || 0) : "0";
        if (closedCount) closedCount.textContent = overview ? String(overview.tickets.closed || 0) : "0";
      }
      function renderStats() {
        if (!state.overview) { statsContainer.innerHTML = ""; return; }
        const currentRelease = state.overview.release.current;
        const publishingRelease = state.overview.release.publishing;
        const activeTickets = Number(state.overview.tickets.active || 0);
        const resolvedTickets = Number(state.overview.tickets.resolved || 0);
        const cards = [
          {
            label: "Release live",
            value: currentRelease ? escapeHtml(currentRelease.version) : "Nessuna",
            note: currentRelease ? "Tag " + escapeHtml(currentRelease.tag) + " - " + formatDateTime(currentRelease.publishedAt) : "Ancora nessuna release pubblicata",
            tone: "tone-info",
          },
          {
            label: "Pipeline",
            value: publishingRelease ? escapeHtml(publishingRelease.version) : "Idle",
            note: publishingRelease ? "Pubblicazione iniziata " + formatDateTime(publishingRelease.startedAt) : "Nessun rilascio in corso",
            tone: publishingRelease ? "tone-warning" : "",
          },
          {
            label: "Ticket da gestire",
            value: String(activeTickets),
            note: state.overview.tickets.total + " totali, " + state.overview.tickets.waiting + " nuovi, " + state.overview.tickets.inProgress + " in lavorazione",
            tone: activeTickets > 0 ? "tone-warning" : "",
          },
          {
            label: "Ticket gestiti",
            value: String(resolvedTickets),
            note: state.overview.tickets.answered + " risposti, " + state.overview.tickets.closed + " chiusi, ultimo update " + formatDateTime(state.overview.tickets.latestUpdatedAt),
            tone: resolvedTickets > 0 ? "tone-success" : "",
          },
          {
            label: "Storage",
            value: escapeHtml(state.overview.dataProvider),
            note: "Service " + escapeHtml(state.overview.service) + ", overview generata " + formatDateTime(state.overview.generatedAt),
            tone: "",
          },
        ];
        statsContainer.innerHTML = cards.map((card) => '<article class="stat ' + escapeHtml(card.tone || "") + '"><div class="stat-label">' + card.label + '</div><div class="stat-value">' + card.value + '</div><div class="stat-note">' + card.note + '</div></article>').join("");
      }
      function renderTicketDetailLoading() {
        ticketDetail.innerHTML = '<div class="empty-state">Caricamento dettaglio ticket...</div>';
      }
      async function loadSelectedTicketDetail(options = {}) {
        if (!state.selectedTicketId) {
          return null;
        }

        const forceReload = options.force === true;
        if (!forceReload && state.ticketDetailsById[state.selectedTicketId]) {
          return state.ticketDetailsById[state.selectedTicketId];
        }

        const detail = await api(
          "/admin/api/tickets/" + encodeURIComponent(state.selectedTicketId)
        );
        state.ticketDetailsById[state.selectedTicketId] = detail;
        return detail;
      }
      async function selectTicket(ticketId) {
        if (!ticketId) {
          return;
        }
        state.selectedTicketId = ticketId;
        renderTicketList();
        renderTicketDetailLoading();
        try {
          await loadSelectedTicketDetail({ force: true });
          renderTicketDetail();
        } catch (error) {
          ticketDetail.innerHTML = '<div class="empty-state">Impossibile caricare il dettaglio ticket.</div>';
          setStatus(
            error.message || "Errore durante il caricamento del ticket.",
            "error",
            "dashboard"
          );
        }
      }
      function renderTicketList() {
        if (!state.tickets.length) { ticketList.innerHTML = '<div class="empty-state">Nessun ticket trovato.</div>'; return; }
        ticketList.innerHTML = state.tickets.map((ticket) => {
          const attachments = Array.isArray(ticket.attachments) ? ticket.attachments.length : 0;
          const replies = Array.isArray(ticket.replies) ? ticket.replies.length : 0;
          return '<article class="ticket-card ' + (ticket.id === state.selectedTicketId ? "is-active" : "") + '" data-ticket-id="' + escapeHtml(ticket.id) + '"><div class="ticket-card-head"><div class="ticket-badges">' + categoryBadge(ticket.category) + statusBadge(ticket.status) + '</div><span class="muted">' + formatDateTime(ticket.updatedAt) + '</span></div><div class="ticket-title">' + escapeHtml(ticket.subject) + '</div><div class="ticket-meta">' + escapeHtml(ticket.name || ticket.email || "Ticket anonimo") + '</div><div class="ticket-meta" style="margin-top:6px;">' + escapeHtml(ticket.message.slice(0, 120)) + (ticket.message.length > 120 ? "..." : "") + '</div><div class="ticket-card-summary"><span>' + replies + ' risposte</span><span>' + attachments + ' allegati</span></div></article>';
        }).join("");
        ticketList.querySelectorAll("[data-ticket-id]").forEach((node) => node.addEventListener("click", () => selectTicket(node.getAttribute("data-ticket-id"))));
      }
      function renderTicketDetail() {
        if (!state.selectedTicketId) {
          ticketDetail.innerHTML = '<div class="empty-state">Seleziona un ticket dall elenco per aprire messaggi, allegati e risposta admin.</div>';
          return;
        }
        const ticket = state.ticketDetailsById[state.selectedTicketId];
        if (!ticket) {
          ticketDetail.innerHTML = '<div class="empty-state">Apri un ticket dalla lista per caricare il dettaglio completo.</div>';
          return;
        }
        const attachments = Array.isArray(ticket.attachments) ? ticket.attachments : [];
        const replies = Array.isArray(ticket.replies) ? ticket.replies : [];
        const attachmentsSection = attachments.length
          ? '<article class="message-card"><div class="field-label">Allegati ticket</div><div class="attachment-gallery">' + attachments.map((attachment) => renderAttachmentCard(attachment)).join("") + '</div></article>'
          : '';
        const hasClientLogs = typeof ticket.clientLogs === "string" && ticket.clientLogs.trim().length > 0;
        const clientLogsSection = hasClientLogs
          ? '<article class="message-card"><div class="field-label">Log condivisi dal dispositivo</div><div style="margin-top:8px; white-space:pre-wrap; max-height:280px; overflow:auto;">' + escapeHtml(ticket.clientLogs) + '</div></article>'
          : '';
        ticketDetail.innerHTML = '<div class="detail-shell"><div class="toolbar"><div><div class="reply-meta">' + categoryBadge(ticket.category) + statusBadge(ticket.status) + '</div><h3 class="detail-title">' + escapeHtml(ticket.subject) + '</h3><p class="lede">' + escapeHtml(ticket.name || ticket.email || "Ticket anonimo") + '</p></div></div><div class="detail-grid"><div class="field"><div class="field-label">Creato</div><div>' + formatDateTime(ticket.createdAt) + '</div></div><div class="field"><div class="field-label">Aggiornato</div><div>' + formatDateTime(ticket.updatedAt) + '</div></div><div class="field"><div class="field-label">Contatto</div><div>' + escapeHtml(ticket.name || "-") + (ticket.email ? " (" + escapeHtml(ticket.email) + ")" : "") + '</div></div><div class="field"><div class="field-label">Versione app</div><div>' + escapeHtml(ticket.appVersion || "-") + '</div></div></div><section class="thread"><article class="message-card"><div class="field-label">Messaggio utente</div><div style="margin-top:8px; white-space:pre-wrap;">' + escapeHtml(ticket.message) + '</div></article>' + attachmentsSection + clientLogsSection + (replies.map((reply) => '<article class="message-card reply"><div class="field-label">' + (reply.author === "admin" ? "Risposta admin" : "Replica utente") + ' - ' + formatDateTime(reply.createdAt) + '</div><div style="margin-top:8px; white-space:pre-wrap;">' + escapeHtml(reply.message) + '</div></article>').join("") || '<div class="empty-state">Ancora nessuna risposta nel thread.</div>') + '</section><form id="admin-reply-form" class="reply-form"><label class="field"><span class="field-label">Nuova risposta</span><textarea name="message" required placeholder="Scrivi la risposta che vuoi salvare nel thread del ticket"></textarea></label><label class="field"><span class="field-label">Nuovo stato</span><select name="status"><option value="answered">Risposto</option><option value="in_progress">In lavorazione</option><option value="closed">Chiuso</option></select></label><div class="reply-actions"><button type="submit" class="primary">Salva risposta</button></div></form></div>';
        const form = document.getElementById("admin-reply-form");
        form?.addEventListener("submit", async (event) => {
          event.preventDefault();
          const formData = new FormData(form);
          const message = String(formData.get("message") || "").trim();
          const status = String(formData.get("status") || "").trim();
          if (!message) { setStatus("Scrivi una risposta prima di salvare.", "error", "dashboard"); return; }
          try {
            setStatus("Salvataggio risposta...", "info", "dashboard");
            await api("/admin/api/tickets/" + encodeURIComponent(ticket.id) + "/replies", { method: "POST", body: JSON.stringify({ message, status }) });
            form.reset();
            delete state.ticketDetailsById[ticket.id];
            await loadDashboard();
            setStatus("Risposta ticket salvata.", "success", "dashboard");
          } catch (error) {
            setStatus(error.message || "Errore durante il salvataggio della risposta.", "error", "dashboard");
          }
        });
      }
`;
