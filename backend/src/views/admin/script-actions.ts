// Ciclo di vita della dashboard admin: login, caricamento, azioni.
//
// Blocco di JavaScript servito nella pagina: e' testo, non codice del
// backend, e legge la configurazione da `data-base-url` sul body.

export const adminScriptActions = `
      function resetDashboardState() {
        state.adminUser = null;
        state.overview = null;
        state.tickets = [];
        state.users = [];
        state.ticketDetailsById = {};
        state.selectedTicketId = null;
        state.userSearchQuery = "";
        if (userSearchInput) {
          userSearchInput.value = "";
        }
        renderWorkspaceSummary();
        renderStats();
        renderTicketList();
        renderTicketDetail();
        renderUserList();
      }
      async function loadDashboard() {
        const [adminUser, overview, ticketsResponse] = await Promise.all([
          api("/auth/me"),
          api("/admin/api/overview"),
          api("/admin/api/tickets")
        ]);
        state.adminUser = adminUser;
        state.overview = overview;
        state.tickets = Array.isArray(ticketsResponse.items) ? ticketsResponse.items : [];
        state.ticketDetailsById = Object.fromEntries(
          Object.entries(state.ticketDetailsById).filter(([ticketId]) =>
            state.tickets.some((ticket) => ticket.id === ticketId)
          )
        );
        if (adminUser && adminUser.isSuperAdmin === true) {
          const searchQuery = String(state.userSearchQuery || "").trim();
          const usersPath = searchQuery.length > 0
            ? "/admin/api/users?search=" + encodeURIComponent(searchQuery)
            : "/admin/api/users";
          const usersResponse = await api(usersPath);
          state.users = Array.isArray(usersResponse.items) ? usersResponse.items : [];
        } else {
          state.users = [];
        }
        if (state.selectedTicketId && !state.tickets.some((ticket) => ticket.id === state.selectedTicketId)) {
          state.selectedTicketId = null;
        }
        renderWorkspaceSummary();
        renderStats();
        renderTicketList();
        if (state.selectedTicketId) {
          renderTicketDetailLoading();
          try {
            await loadSelectedTicketDetail({ force: true });
          } catch (_) {}
        }
        renderTicketDetail();
        renderUserList();
        updateAuthPanel();
      }
      async function bootstrapDashboard() {
        if (!state.token) {
          authPanel.classList.remove("hidden");
          dashboardPanel.classList.add("hidden");
          resetDashboardState();
          updateAuthMode("login");
          updateAuthPanel();
          setStatus(defaultAuthMessage(), "info", "auth");
          return;
        }
        try {
          setStatus("Caricamento dashboard...", "info", "dashboard");
          await loadDashboard();
          authPanel.classList.add("hidden");
          dashboardPanel.classList.remove("hidden");
          setStatus("Dashboard aggiornata.", "success", "dashboard");
        } catch (error) {
          resetDashboardState();
          authPanel.classList.remove("hidden");
          dashboardPanel.classList.add("hidden");
          updateAuthMode("login");
          state.token = "";
          writeToken("");
          updateAuthPanel();
          setStatus(error.message || "Impossibile caricare la dashboard.", "error", "auth");
        }
      }
      async function loginAdmin() {
        const email = String(emailInput?.value || "").trim();
        const password = String(passwordInput?.value || "");
        if (!email || !password) {
          setStatus("Inserisci email e password del profilo admin.", "error", "auth");
          return;
        }

        try {
          setStatus("Verifica profilo admin...", "info", "auth");
          const response = await api("/auth/login", {
            method: "POST",
            body: JSON.stringify({ email, password })
          });
          if (!response.user || response.user.isAdmin !== true) {
            try {
              await fetch(resolveApiUrl("/auth/session"), {
                method: "DELETE",
                headers: {
                  Authorization: "Bearer " + response.token
                }
              });
            } catch (_) {}
            throw new Error("Questo profilo non ha accesso admin.");
          }

          state.token = String(response.token || "");
          state.adminUser = response.user || null;
          writeToken(state.token);
          if (emailInput) emailInput.value = response.user.email || email;
          if (passwordInput) passwordInput.value = "";
          await bootstrapDashboard();
        } catch (error) {
          state.token = "";
          state.adminUser = null;
          writeToken("");
          setStatus(error.message || "Accesso admin non riuscito.", "error", "auth");
        }
      }
      async function registerAccount() {
        const email = String(registerEmailInput?.value || "").trim();
        const password = String(registerPasswordInput?.value || "");
        if (!email || !password) {
          setStatus("Inserisci email e password per creare il profilo.", "error", "auth");
          return;
        }

        try {
          setStatus("Creazione profilo in corso...", "info", "auth");
          const response = await api("/auth/register", {
            method: "POST",
            body: JSON.stringify({ email, password })
          });

          if (registerForm) registerForm.reset();
          if (emailInput) emailInput.value = response.user?.email || email;

          if (response.user && response.user.isAdmin === true) {
            state.token = String(response.token || "");
            state.adminUser = response.user || null;
            writeToken(state.token);
            await bootstrapDashboard();
            return;
          }

          try {
            if (response.token) {
              await fetch(resolveApiUrl("/auth/session"), {
                method: "DELETE",
                headers: {
                  Authorization: "Bearer " + response.token
                }
              });
            }
          } catch (_) {}

          updateAuthMode("login");
          if (passwordInput) passwordInput.value = "";
          setStatus(
            "Profilo creato. Ora fai login quando il super admin ti avra promosso, oppure attendi la promozione dalla sezione Accessi e ruoli.",
            "success",
            "auth"
          );
        } catch (error) {
          setStatus(error.message || "Registrazione non riuscita.", "error", "auth");
        }
      }
      async function createManagedUser() {
        const email = String(createUserEmailInput?.value || "").trim();
        const password = String(createUserPasswordInput?.value || "");
        const role = String(createUserRoleInput?.value || "user")
          .trim()
          .toLowerCase();
        if (!email || !password) {
          setStatus("Inserisci email e password per creare l utente.", "error", "dashboard");
          return;
        }
        if (password.trim().length === 0) {
          setStatus("La password non puo essere vuota.", "error", "dashboard");
          return;
        }
        if (role !== "user" && role !== "admin") {
          setStatus("Ruolo non valido.", "error", "dashboard");
          return;
        }

        try {
          setStatus("Creazione utente in corso...", "info", "dashboard");
          const response = await api("/admin/api/users", {
            method: "POST",
            body: JSON.stringify({ email, password, role })
          });
          createUserForm?.reset();
          if (createUserRoleInput) {
            createUserRoleInput.value = "user";
          }
          await loadDashboard();
          const recoveryCode =
            response &&
            typeof response === "object" &&
            typeof response.recoveryCode === "string"
              ? response.recoveryCode
              : null;
          setStatus(
            recoveryCode
              ? "Utente creato. Recovery code: " + recoveryCode
              : "Utente creato.",
            "success",
            "dashboard"
          );
        } catch (error) {
          setStatus(
            error.message || "Impossibile creare l utente.",
            "error",
            "dashboard"
          );
        }
      }
      loginForm?.addEventListener("submit", (event) => {
        event.preventDefault();
        loginAdmin();
      });
      registerForm?.addEventListener("submit", (event) => {
        event.preventDefault();
        registerAccount();
      });
      createUserForm?.addEventListener("submit", (event) => {
        event.preventDefault();
        createManagedUser();
      });
      userSearchInput?.addEventListener("input", (event) => {
        const target = event.target;
        const nextQuery =
          target && typeof target === "object" && "value" in target
            ? String(target.value || "")
            : "";
        state.userSearchQuery = nextQuery;
        renderUserList();
      });
      showRegisterButton?.addEventListener("click", () => {
        updateAuthMode("register");
        setStatus(
          "La registrazione crea un profilo normale. Solo il super admin puo darti accesso admin.",
          "info",
          "auth"
        );
      });
      showLoginButton?.addEventListener("click", () => {
        updateAuthMode("login");
        setStatus(defaultAuthMessage(), "info", "auth");
      });
      document.getElementById("admin-logout-btn")?.addEventListener("click", async () => {
        const currentToken = state.token;
        state.token = "";
        state.adminUser = null;
        writeToken("");
        if (passwordInput) passwordInput.value = "";
        try {
          if (currentToken) {
            await fetch(resolveApiUrl("/auth/session"), {
              method: "DELETE",
              headers: {
                Authorization: "Bearer " + currentToken
              }
            });
          }
        } catch (_) {}
        dashboardPanel.classList.add("hidden");
        authPanel.classList.remove("hidden");
        resetDashboardState();
        updateAuthMode("login");
        updateAuthPanel();
        setStatus("Sessione admin chiusa.", "info", "auth");
      });
      document.getElementById("admin-refresh-btn")?.addEventListener("click", bootstrapDashboard);
      document.getElementById("admin-refresh-tickets-btn")?.addEventListener("click", bootstrapDashboard);
      document.getElementById("admin-refresh-users-btn")?.addEventListener("click", bootstrapDashboard);
      updateAuthPanel();
      updateAuthMode("login");
      state.token = readToken();
      if (state.token) {
        bootstrapDashboard();
      } else {
        resetDashboardState();
        updateAuthPanel();
        setStatus(defaultAuthMessage(), "info", "auth");
      }
`;
