// Configurazione, stato e chiamate API della dashboard admin.
//
// Blocco di JavaScript servito nella pagina: e' testo, non codice del
// backend, e legge la configurazione da `data-base-url` sul body.

export const adminScriptCore = `
      const ADMIN_TOKEN_KEY = "work_hours_admin_session_token";
      const bodyDataset = document.body.dataset || {};
      const baseUrl = bodyDataset.baseUrl || "";
      const normalizedBaseUrl = String(baseUrl || "").replace(/\\/+$/, "");
      const sameOriginOrigin = (
        typeof window !== "undefined" &&
        window.location &&
        window.location.origin
      )
        ? String(window.location.origin).replace(/\\/+$/, "")
        : "";
      const inferredBasePath = (
        typeof window !== "undefined" &&
        window.location &&
        typeof window.location.pathname === "string"
      )
        ? (() => {
            const pathname = window.location.pathname;
            const adminMarker = "/admin";
            const markerIndex = pathname.lastIndexOf(adminMarker);
            if (markerIndex <= 0) {
              return "";
            }
            return pathname.slice(0, markerIndex);
          })()
        : "";
      const sameOriginBaseUrl = (sameOriginOrigin + inferredBasePath).replace(/\\/+$/, "");
      const apiBaseCandidates = Array.from(
        new Set(
          [sameOriginBaseUrl, normalizedBaseUrl, sameOriginOrigin].filter(
            (value) => typeof value === "string" && value.length > 0
          )
        )
      );
      const authPanel = document.getElementById("admin-auth-panel");
      const dashboardPanel = document.getElementById("admin-dashboard-panel");
      const authStatusBox = document.getElementById("admin-auth-status");
      const authCta = document.getElementById("admin-auth-cta");
      const loginCard = document.getElementById("admin-login-card");
      const loginForm = document.getElementById("admin-login-form");
      const emailInput = document.getElementById("admin-email-input");
      const passwordInput = document.getElementById("admin-password-input");
      const registerCard = document.getElementById("admin-register-card");
      const registerForm = document.getElementById("admin-register-form");
      const registerEmailInput = document.getElementById("admin-register-email-input");
      const registerPasswordInput = document.getElementById("admin-register-password-input");
      const showRegisterButton = document.getElementById("admin-show-register-btn");
      const showLoginButton = document.getElementById("admin-show-login-btn");
      const statusBox = document.getElementById("admin-status");
      const statsContainer = document.getElementById("admin-stats");
      const ticketList = document.getElementById("admin-ticket-list");
      const ticketDetail = document.getElementById("admin-ticket-detail");
      const userList = document.getElementById("admin-user-list");
      const userManagementSection = document.getElementById("admin-user-management-section");
      const userSearchInput = document.getElementById("admin-user-search-input");
      const createUserForm = document.getElementById("admin-create-user-form");
      const createUserEmailInput = document.getElementById("admin-create-user-email-input");
      const createUserPasswordInput = document.getElementById("admin-create-user-password-input");
      const createUserRoleInput = document.getElementById("admin-create-user-role-input");
      const sessionCopy = document.getElementById("admin-session-copy");
      const sessionEmail = document.getElementById("admin-session-email");
      const generatedAtLabel = document.getElementById("admin-generated-at");
      const serviceLabel = document.getElementById("admin-service-label");
      const providerNote = document.getElementById("admin-provider-note");
      const healthLink = document.getElementById("admin-health-link");
      const feedLink = document.getElementById("admin-feed-link");
      const publicTicketsLink = document.getElementById("admin-public-tickets-link");
      const waitingCount = document.getElementById("admin-ticket-waiting");
      const inProgressCount = document.getElementById("admin-ticket-progress");
      const answeredCount = document.getElementById("admin-ticket-answered");
      const closedCount = document.getElementById("admin-ticket-closed");
      const state = {
        token: "",
        adminUser: null,
        overview: null,
        tickets: [],
        users: [],
        ticketDetailsById: {},
        selectedTicketId: null,
        userSearchQuery: "",
        authMode: "login",
        superAdminConfigured: bodyDataset.superAdminConfigured === "true"
      };

      function readToken() {
        try {
          return sessionStorage.getItem(ADMIN_TOKEN_KEY) || "";
        } catch (_) {
          return "";
        }
      }
      function writeToken(value) {
        try {
          value
            ? sessionStorage.setItem(ADMIN_TOKEN_KEY, value)
            : sessionStorage.removeItem(ADMIN_TOKEN_KEY);
        } catch (_) {}
      }
      function escapeHtml(value) {
        return String(value ?? "")
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll('"', "&quot;")
          .replaceAll("'", "&#39;");
      }
      function formatDateTime(value) {
        if (!value) return "-";
        try {
          return new Date(value).toLocaleString("it-IT", {
            dateStyle: "medium",
            timeStyle: "short"
          });
        } catch (_) {
          return value;
        }
      }
      function formatBytes(value) {
        const size = Number(value || 0);
        if (!Number.isFinite(size) || size <= 0) return "0 KB";
        if (size >= 1024 * 1024) return (size / (1024 * 1024)).toFixed(1) + " MB";
        return Math.ceil(size / 1024) + " KB";
      }
      function defaultAuthMessage() {
        if (!state.superAdminConfigured) {
          return "Login disponibile, ma prima va configurato il super admin nel runtime del backend.";
        }
        return "Accedi con un profilo admin per aprire la dashboard.";
      }
      function updateAuthMode(nextMode = "login") {
        state.authMode = nextMode === "register" ? "register" : "login";
        loginCard?.classList.toggle("hidden", state.authMode !== "login");
        registerCard?.classList.toggle("hidden", state.authMode !== "register");
      }
      function updateAuthPanel() {
        if (authCta) {
          if (!state.superAdminConfigured) {
            authCta.innerHTML =
              'La registrazione non rende admin in automatico. Solo il <code>super_admin</code> puo promuovere o revocare gli altri admin.';
          } else {
            authCta.innerHTML =
              'La registrazione non rende admin in automatico. Solo il <code>super_admin</code> puo promuovere o revocare gli altri admin.';
          }
        }
      }
      function setStatus(message, tone = "info", scope = "both") {
        const targets = scope === "auth"
          ? [authStatusBox]
          : scope === "dashboard"
            ? [statusBox]
            : [authStatusBox, statusBox];
        targets.filter(Boolean).forEach((element) => {
          element.textContent = message;
          element.className = "status " + tone;
        });
      }
      function resolveApiUrl(path, apiRoot = apiBaseCandidates[0] || "") {
        const value = String(path ?? "");
        if (value.startsWith("http://") || value.startsWith("https://")) {
          return value;
        }

        const normalizedPath = value.startsWith("/") ? value : "/" + value;
        return String(apiRoot || "").replace(/\\/+$/, "") + normalizedPath;
      }
      async function api(path, options = {}) {
        const headers = { ...(options.headers || {}) };
        const hasBody = options.body !== undefined && options.body !== null;
        const hasContentTypeHeader = Object.keys(headers).some(
          (key) => key.toLowerCase() === "content-type"
        );
        if (hasBody && !hasContentTypeHeader && !(options.body instanceof FormData)) {
          headers["Content-Type"] = "application/json";
        }
        if (state.token) headers.Authorization = "Bearer " + state.token;

        let lastError = null;
        for (let index = 0; index < apiBaseCandidates.length; index += 1) {
          const requestUrl = resolveApiUrl(path, apiBaseCandidates[index]);
          try {
            const response = await fetch(requestUrl, {
              cache: "no-store",
              ...options,
              headers
            });
            const contentType = String(response.headers.get("content-type") || "");
            const payload = contentType.includes("application/json")
              ? await response.json().catch(() => null)
              : null;

            if (!response.ok) {
              const errorMessage =
                payload &&
                typeof payload === "object" &&
                typeof payload.error === "string"
                  ? payload.error
                  : "Request failed";

              const canRetry =
                index < apiBaseCandidates.length - 1 &&
                (response.status === 404 ||
                  response.status === 405 ||
                  response.status === 502 ||
                  response.status === 503);
              if (canRetry) {
                continue;
              }
              throw new Error(errorMessage);
            }

            if (response.status === 204) {
              return {};
            }

            if (!payload || typeof payload !== "object") {
              if (index < apiBaseCandidates.length - 1) {
                continue;
              }
              throw new Error("Risposta API non valida.");
            }

            return payload;
          } catch (error) {
            lastError = error;
            if (index < apiBaseCandidates.length - 1) {
              continue;
            }
            throw error;
          }
        }

        throw lastError || new Error("Request failed");
      }
`;
