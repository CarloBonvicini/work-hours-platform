// Rendering e gestione degli utenti nella dashboard admin.
//
// Blocco di JavaScript servito nella pagina: e' testo, non codice del
// backend, e legge la configurazione da `data-base-url` sul body.

export const adminScriptUsers = `
      function renderUserList() {
        const canManageUsers = Boolean(state.adminUser && state.adminUser.isSuperAdmin === true);
        if (userManagementSection) {
          userManagementSection.classList.toggle("hidden", !canManageUsers);
        }
        if (!canManageUsers) {
          if (userSearchInput) {
            userSearchInput.value = "";
          }
          userList.innerHTML = "";
          return;
        }

        const normalizedSearch = String(state.userSearchQuery || "")
          .trim()
          .toLowerCase();
        const visibleUsers = normalizedSearch
          ? state.users.filter((user) =>
              String(user.email || "").toLowerCase().includes(normalizedSearch)
            )
          : state.users;

        if (!visibleUsers.length) {
          userList.innerHTML =
            state.users.length === 0
              ? '<div class="empty-state">Nessun profilo registrato.</div>'
              : '<div class="empty-state">Nessun utente trovato con questo filtro.</div>';
          return;
        }

        userList.innerHTML = visibleUsers.map((user) => {
          const isCurrentUser = Boolean(state.adminUser && state.adminUser.id === user.id);
          const roleLabel = user.isSuperAdmin
            ? "Super admin"
            : user.isAdmin
              ? "Admin"
              : "Utente";
          const roleTone = user.isSuperAdmin
            ? "warning"
            : user.isAdmin
              ? "success"
              : "info";
          const actionButtons = user.isSuperAdmin
            ? ""
            : (
                (user.isAdmin
                  ? '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="toggle-admin" data-next-admin="false">Rimuovi admin</button>'
                  : '<button type="button" class="primary" data-user-id="' + escapeHtml(user.id) + '" data-user-action="toggle-admin" data-next-admin="true">Rendi admin</button>') +
                '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="edit-user">Modifica</button>' +
                '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="reset-password">Reset password</button>' +
                '<button type="button" data-user-id="' + escapeHtml(user.id) + '" data-user-action="delete-user">Elimina</button>'
              );

          return '<article class="user-row"><div class="user-row-main"><div class="user-row-email">' + escapeHtml(user.email) + '</div><div class="user-row-meta"><span class="pill ' + roleTone + '">' + roleLabel + '</span>' + (isCurrentUser ? '<span class="pill info">Sessione corrente</span>' : "") + '<span>Creato ' + formatDateTime(user.createdAt) + '</span><span>Aggiornato ' + formatDateTime(user.updatedAt) + '</span></div></div><div class="user-actions">' + actionButtons + '</div></article>';
        }).join("");

        userList.querySelectorAll("[data-user-action]").forEach((node) => {
          node.addEventListener("click", async () => {
            const userId = node.getAttribute("data-user-id");
            const action = node.getAttribute("data-user-action");
            if (!userId || !action) return;

            if (action === "toggle-admin") {
              const nextAdmin = node.getAttribute("data-next-admin") === "true";
              try {
                setStatus("Aggiornamento ruolo in corso...", "info", "dashboard");
                await api(
                  "/admin/api/users/" + encodeURIComponent(userId) + "/admin",
                  {
                    method: "POST",
                    body: JSON.stringify({ isAdmin: nextAdmin })
                  }
                );
                await loadDashboard();
                setStatus("Ruolo aggiornato.", "success", "dashboard");
              } catch (error) {
                setStatus(
                  error.message || "Impossibile aggiornare il ruolo.",
                  "error",
                  "dashboard"
                );
              }
              return;
            }

            if (action === "edit-user") {
              const targetUser = state.users.find((user) => user.id === userId);
              if (!targetUser) {
                return;
              }

              const emailPrompt = window.prompt(
                "Email utente:",
                targetUser.email || ""
              );
              if (emailPrompt === null) {
                return;
              }
              const nextEmail = String(emailPrompt || "").trim().toLowerCase();
              if (!nextEmail) {
                setStatus("Email non valida.", "error", "dashboard");
                return;
              }

              const currentRole = targetUser.isAdmin ? "admin" : "user";
              const rolePrompt = window.prompt("Ruolo (user/admin):", currentRole);
              if (rolePrompt === null) {
                return;
              }
              const nextRole = String(rolePrompt || "").trim().toLowerCase();
              if (nextRole !== "user" && nextRole !== "admin") {
                setStatus("Ruolo non valido. Usa user oppure admin.", "error", "dashboard");
                return;
              }

              try {
                setStatus("Aggiornamento utente in corso...", "info", "dashboard");
                await api(
                  "/admin/api/users/" + encodeURIComponent(userId),
                  {
                    method: "PATCH",
                    body: JSON.stringify({ email: nextEmail, role: nextRole })
                  }
                );
                await loadDashboard();
                setStatus("Utente aggiornato.", "success", "dashboard");
              } catch (error) {
                setStatus(
                  error.message || "Impossibile aggiornare l utente.",
                  "error",
                  "dashboard"
                );
              }
              return;
            }

            if (action === "reset-password") {
              const newPassword = window.prompt(
                "Nuova password per questo utente:",
                ""
              );
              if (newPassword === null) {
                return;
              }

              if (String(newPassword).trim().length === 0) {
                setStatus(
                  "La password non puo essere vuota.",
                  "error",
                  "dashboard"
                );
                return;
              }

              const confirmation = window.prompt("Conferma la nuova password:", "");
              if (confirmation === null) {
                return;
              }

              if (confirmation !== newPassword) {
                setStatus("Le password non coincidono.", "error", "dashboard");
                return;
              }

              try {
                setStatus("Aggiornamento password in corso...", "info", "dashboard");
                await api(
                  "/admin/api/users/" + encodeURIComponent(userId) + "/password",
                  {
                    method: "POST",
                    body: JSON.stringify({ newPassword })
                  }
                );
                await loadDashboard();
                setStatus("Password aggiornata.", "success", "dashboard");
              } catch (error) {
                setStatus(
                  error.message || "Impossibile aggiornare la password.",
                  "error",
                  "dashboard"
                );
              }
              return;
            }

            if (action === "delete-user") {
              const targetUser = state.users.find((user) => user.id === userId);
              if (!targetUser) {
                return;
              }

              const confirmed = window.confirm(
                "Confermi eliminazione utente " + (targetUser.email || userId) + "?"
              );
              if (!confirmed) {
                return;
              }

              try {
                setStatus("Eliminazione utente in corso...", "info", "dashboard");
                const deleteResponse = await api(
                  "/admin/api/users/" + encodeURIComponent(userId),
                  {
                    method: "DELETE"
                  }
                );

                if (!deleteResponse || deleteResponse.deleted !== true) {
                  throw new Error("Il server non ha confermato l eliminazione.");
                }

                state.users = state.users.filter((user) => user.id !== userId);
                renderUserList();

                try {
                  await loadDashboard();
                } catch (_) {}

                setStatus("Utente eliminato.", "success", "dashboard");
              } catch (error) {
                const errorMessage =
                  error && typeof error === "object" && "message" in error
                    ? String(error.message || "")
                    : "";
                if (errorMessage) {
                  window.alert(errorMessage);
                }
                setStatus(
                  errorMessage || "Impossibile eliminare l utente.",
                  "error",
                  "dashboard"
                );
              }
            }
          });
        });
      }
`;
