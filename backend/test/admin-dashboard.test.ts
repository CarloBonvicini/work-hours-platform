import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

let app = buildApp();
let tempDirectory: string | null = null;
const originalTicketsDir = process.env.TICKETS_DIR;
const originalAdminToken = process.env.ADMIN_DASHBOARD_TOKEN;
const originalAdminEmails = process.env.ADMIN_EMAILS;
const originalSuperAdminEmail = process.env.SUPER_ADMIN_EMAIL;
const originalSuperAdminPassword = process.env.SUPER_ADMIN_PASSWORD;

afterEach(async () => {
  await app.close();
  app = buildApp();

  if (tempDirectory) {
    await rm(tempDirectory, { recursive: true, force: true });
    tempDirectory = null;
  }

  if (originalTicketsDir === undefined) {
    delete process.env.TICKETS_DIR;
  } else {
    process.env.TICKETS_DIR = originalTicketsDir;
  }

  if (originalAdminToken === undefined) {
    delete process.env.ADMIN_DASHBOARD_TOKEN;
  } else {
    process.env.ADMIN_DASHBOARD_TOKEN = originalAdminToken;
  }

  if (originalAdminEmails === undefined) {
    delete process.env.ADMIN_EMAILS;
  } else {
    process.env.ADMIN_EMAILS = originalAdminEmails;
  }

  if (originalSuperAdminEmail === undefined) {
    delete process.env.SUPER_ADMIN_EMAIL;
  } else {
    process.env.SUPER_ADMIN_EMAIL = originalSuperAdminEmail;
  }

  if (originalSuperAdminPassword === undefined) {
    delete process.env.SUPER_ADMIN_PASSWORD;
  } else {
    process.env.SUPER_ADMIN_PASSWORD = originalSuperAdminPassword;
  }
});

describe("Admin dashboard", () => {
  it("serves the admin dashboard page", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/admin"
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/html");
    expect(response.body).toContain("Admin Dashboard");
    expect(response.body).toContain("Accedi con un profilo gia autorizzato");
    expect(response.body).toContain("Non hai ancora un profilo?");
    expect(response.body).toContain("Torna al login");
    expect(response.body).toContain(
      "Seleziona un ticket dall elenco per aprire messaggi, allegati e risposta admin."
    );
    expect(response.body).not.toContain("SUPER_ADMIN_EMAIL");
    expect(response.body).not.toContain("ADMIN_SETUP_TOKEN");
  });

  it("protects the overview api when an admin token is configured", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-admin-"));
    process.env.TICKETS_DIR = tempDirectory;
    process.env.ADMIN_DASHBOARD_TOKEN = "secret-token";
    app = buildApp();

    await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        category: "bug",
        subject: "Dashboard broken",
        message: "Il layout admin non si carica."
      }
    });

    const unauthorizedResponse = await app.inject({
      method: "GET",
      url: "/admin/api/overview"
    });
    expect(unauthorizedResponse.statusCode).toBe(401);

    const authorizedResponse = await app.inject({
      method: "GET",
      url: "/admin/api/overview",
      headers: {
        authorization: "Bearer secret-token"
      }
    });
    expect(authorizedResponse.statusCode).toBe(200);
    expect(authorizedResponse.json()).toMatchObject({
      service: "work-hours-backend",
      tickets: {
        total: 1,
        waiting: 1,
        active: 1,
        resolved: 0,
        bug: 1
      }
    });
  });

  it("reports active and resolved ticket counters in overview", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-admin-"));
    process.env.TICKETS_DIR = tempDirectory;
    process.env.ADMIN_DASHBOARD_TOKEN = "secret-token";
    app = buildApp();

    const createTicketResponse = await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        category: "bug",
        subject: "Contatore overview",
        message: "Verifico i contatori della dashboard."
      }
    });
    expect(createTicketResponse.statusCode).toBe(201);

    const ticketId = createTicketResponse.json().id as string;

    const replyResponse = await app.inject({
      method: "POST",
      url: `/admin/api/tickets/${ticketId}/replies`,
      headers: {
        "content-type": "application/json",
        authorization: "Bearer secret-token"
      },
      payload: {
        message: "Aggiornamento inviato.",
        status: "answered"
      }
    });
    expect(replyResponse.statusCode).toBe(200);

    const overviewResponse = await app.inject({
      method: "GET",
      url: "/admin/api/overview",
      headers: {
        authorization: "Bearer secret-token"
      }
    });
    expect(overviewResponse.statusCode).toBe(200);
    expect(overviewResponse.json()).toMatchObject({
      tickets: {
        total: 1,
        waiting: 0,
        inProgress: 0,
        answered: 1,
        closed: 0,
        active: 0,
        resolved: 1
      }
    });
  });

  it("persists admin replies on support tickets", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-admin-"));
    process.env.TICKETS_DIR = tempDirectory;
    process.env.ADMIN_DASHBOARD_TOKEN = "secret-token";
    app = buildApp();

    const createTicketResponse = await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        category: "feature",
        subject: "Nuova dashboard",
        message: "Vorrei una dashboard admin migliore."
      }
    });
    expect(createTicketResponse.statusCode).toBe(201);

    const ticketId = createTicketResponse.json().id as string;

    const replyResponse = await app.inject({
      method: "POST",
      url: `/admin/api/tickets/${ticketId}/replies`,
      headers: {
        "content-type": "application/json",
        authorization: "Bearer secret-token"
      },
      payload: {
        message: "Ricevuto. Lo stiamo implementando.",
        status: "in_progress"
      }
    });

    expect(replyResponse.statusCode).toBe(200);
    expect(replyResponse.json()).toMatchObject({
      id: ticketId,
      status: "in_progress"
    });

    const detailResponse = await app.inject({
      method: "GET",
      url: `/admin/api/tickets/${ticketId}`,
      headers: {
        authorization: "Bearer secret-token"
      }
    });
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.json()).toMatchObject({
      id: ticketId,
      replies: [
        {
          author: "admin",
          message: "Ricevuto. Lo stiamo implementando."
        }
      ]
    });

    const files = await readdir(tempDirectory);
    expect(files).toHaveLength(1);

    const storedTicket = JSON.parse(
      await readFile(path.join(tempDirectory, files[0]), "utf8")
    ) as Record<string, unknown>;
    expect(storedTicket.status).toBe("in_progress");
    expect(Array.isArray(storedTicket.replies)).toBe(true);
    expect((storedTicket.replies as Array<Record<string, string>>)[0]).toMatchObject({
      author: "admin",
      message: "Ricevuto. Lo stiamo implementando."
    });
  });

  it("keeps inline screenshot previews available in the admin dashboard", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-admin-"));
    process.env.TICKETS_DIR = tempDirectory;
    process.env.ADMIN_DASHBOARD_TOKEN = "secret-token";
    app = buildApp();

    const screenshotBytes = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0uoAAAAASUVORK5CYII=",
      "base64"
    );

    const createTicketResponse = await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        category: "bug",
        subject: "Screenshot admin",
        message: "Controllo anteprima inline.",
        attachments: [
          {
            fileName: "anteprima-admin.png",
            contentType: "image/png",
            base64Data: screenshotBytes.toString("base64")
          }
        ]
      }
    });
    expect(createTicketResponse.statusCode).toBe(201);

    const dashboardResponse = await app.inject({
      method: "GET",
      url: "/admin"
    });
    expect(dashboardResponse.statusCode).toBe(200);
    expect(dashboardResponse.body).toContain("attachment-preview");
    expect(dashboardResponse.body).toContain("Screenshot allegati");

    const ticketsResponse = await app.inject({
      method: "GET",
      url: "/admin/api/tickets",
      headers: {
        authorization: "Bearer secret-token"
      }
    });
    expect(ticketsResponse.statusCode).toBe(200);
    expect(ticketsResponse.json()).toMatchObject({
      items: [
        {
          attachments: [
            {
              fileName: "anteprima-admin.png",
            }
          ]
        }
      ]
    });
    expect(
      ticketsResponse.json().items[0].attachments[0].downloadPath as string
    ).toContain("/tickets/");

    const ticketId = createTicketResponse.json().id as string;
    const detailResponse = await app.inject({
      method: "GET",
      url: `/admin/api/tickets/${ticketId}`,
      headers: {
        authorization: "Bearer secret-token"
      }
    });
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.json()).toMatchObject({
      id: ticketId,
      attachments: [
        {
          fileName: "anteprima-admin.png",
        }
      ]
    });
  });

  it("seeds the super admin from env and allows access to user management", async () => {
    process.env.SUPER_ADMIN_EMAIL = "owner@example.com";
    process.env.SUPER_ADMIN_PASSWORD = "super-segreta";
    app = buildApp();

    const loginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "owner@example.com",
        password: "super-segreta"
      }
    });

    expect(loginResponse.statusCode).toBe(200);
    expect(loginResponse.json().user).toMatchObject({
      email: "owner@example.com",
      role: "super_admin",
      isAdmin: true,
      isSuperAdmin: true
    });

    const usersResponse = await app.inject({
      method: "GET",
      url: "/admin/api/users",
      headers: {
        authorization: `Bearer ${loginResponse.json().token as string}`
      }
    });
    expect(usersResponse.statusCode).toBe(200);
    expect(usersResponse.json().items).toHaveLength(1);
    expect(usersResponse.json().items[0]).toMatchObject({
      email: "owner@example.com",
      role: "super_admin",
      isSuperAdmin: true
    });

    const overviewResponse = await app.inject({
      method: "GET",
      url: "/admin/api/overview",
      headers: {
        authorization: `Bearer ${loginResponse.json().token as string}`
      }
    });

    expect(overviewResponse.statusCode).toBe(200);
  });

  it("rejects authenticated profiles without admin access", async () => {
    app = buildApp();

    const registerResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "user@example.com",
        password: "super-segreta"
      }
    });

    expect(registerResponse.statusCode).toBe(201);
    expect(registerResponse.json().user).toMatchObject({
      email: "user@example.com",
      role: "user",
      isAdmin: false
    });

    const overviewResponse = await app.inject({
      method: "GET",
      url: "/admin/api/overview",
      headers: {
        authorization: `Bearer ${registerResponse.json().token as string}`
      }
    });

    expect(overviewResponse.statusCode).toBe(403);
    expect(overviewResponse.json()).toEqual({
      error: "Admin profile required"
    });
  });

  it("allows only the super admin to promote other admins", async () => {
    process.env.SUPER_ADMIN_EMAIL = "owner@example.com";
    process.env.SUPER_ADMIN_PASSWORD = "super-segreta";
    app = buildApp();

    const superAdminLoginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "owner@example.com",
        password: "super-segreta"
      }
    });
    expect(superAdminLoginResponse.statusCode).toBe(200);

    const registerResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "user@example.com",
        password: "super-segreta"
      }
    });
    expect(registerResponse.statusCode).toBe(201);
    expect(registerResponse.json().user).toMatchObject({
      email: "user@example.com",
      role: "user",
      isAdmin: false
    });

    const promoteResponse = await app.inject({
      method: "POST",
      url: `/admin/api/users/${registerResponse.json().user.id as string}/admin`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${superAdminLoginResponse.json().token as string}`
      },
      payload: {
        isAdmin: true
      }
    });
    expect(promoteResponse.statusCode).toBe(200);
    expect(promoteResponse.json()).toMatchObject({
      email: "user@example.com",
      role: "admin",
      isAdmin: true
    });

    const promotedOverviewResponse = await app.inject({
      method: "GET",
      url: "/admin/api/overview",
      headers: {
        authorization: `Bearer ${registerResponse.json().token as string}`
      }
    });
    expect(promotedOverviewResponse.statusCode).toBe(200);

    const promotedUsersResponse = await app.inject({
      method: "GET",
      url: "/admin/api/users",
      headers: {
        authorization: `Bearer ${registerResponse.json().token as string}`
      }
    });
    expect(promotedUsersResponse.statusCode).toBe(403);
    expect(promotedUsersResponse.json()).toEqual({
      error: "Super admin required"
    });

    const secondUserResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "second@example.com",
        password: "super-segreta"
      }
    });
    expect(secondUserResponse.statusCode).toBe(201);

    const forbiddenPromoteResponse = await app.inject({
      method: "POST",
      url: `/admin/api/users/${secondUserResponse.json().user.id as string}/admin`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${registerResponse.json().token as string}`
      },
      payload: {
        isAdmin: true
      }
    });
    expect(forbiddenPromoteResponse.statusCode).toBe(403);
    expect(forbiddenPromoteResponse.json()).toEqual({
      error: "Super admin required"
    });
  });

  it("allows the super admin to reset passwords for managed users", async () => {
    process.env.SUPER_ADMIN_EMAIL = "owner@example.com";
    process.env.SUPER_ADMIN_PASSWORD = "super-segreta";
    app = buildApp();

    const superAdminLoginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "owner@example.com",
        password: "super-segreta"
      }
    });
    expect(superAdminLoginResponse.statusCode).toBe(200);

    const registerResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "user@example.com",
        password: "password-vecchia"
      }
    });
    expect(registerResponse.statusCode).toBe(201);

    const resetResponse = await app.inject({
      method: "POST",
      url: `/admin/api/users/${registerResponse.json().user.id as string}/password`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${superAdminLoginResponse.json().token as string}`
      },
      payload: {
        newPassword: "password-nuova"
      }
    });
    expect(resetResponse.statusCode).toBe(200);
    expect(resetResponse.json()).toMatchObject({
      email: "user@example.com",
      role: "user"
    });

    const oldPasswordLoginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "user@example.com",
        password: "password-vecchia"
      }
    });
    expect(oldPasswordLoginResponse.statusCode).toBe(401);

    const newPasswordLoginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "user@example.com",
        password: "password-nuova"
      }
    });
    expect(newPasswordLoginResponse.statusCode).toBe(200);
  });

  it("allows only the super admin to reset user passwords", async () => {
    process.env.SUPER_ADMIN_EMAIL = "owner@example.com";
    process.env.SUPER_ADMIN_PASSWORD = "super-segreta";
    app = buildApp();

    const superAdminLoginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "owner@example.com",
        password: "super-segreta"
      }
    });
    expect(superAdminLoginResponse.statusCode).toBe(200);

    const adminCandidateResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "admin@example.com",
        password: "admin-password"
      }
    });
    expect(adminCandidateResponse.statusCode).toBe(201);

    const promoteResponse = await app.inject({
      method: "POST",
      url: `/admin/api/users/${adminCandidateResponse.json().user.id as string}/admin`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${superAdminLoginResponse.json().token as string}`
      },
      payload: {
        isAdmin: true
      }
    });
    expect(promoteResponse.statusCode).toBe(200);

    const managedUserResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "target@example.com",
        password: "target-password"
      }
    });
    expect(managedUserResponse.statusCode).toBe(201);

    const forbiddenResetResponse = await app.inject({
      method: "POST",
      url: `/admin/api/users/${managedUserResponse.json().user.id as string}/password`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${adminCandidateResponse.json().token as string}`
      },
      payload: {
        newPassword: "nuova-password"
      }
    });
    expect(forbiddenResetResponse.statusCode).toBe(403);
    expect(forbiddenResetResponse.json()).toEqual({
      error: "Super admin required"
    });
  });

  it("allows the super admin to create, search, edit and delete users", async () => {
    process.env.SUPER_ADMIN_EMAIL = "owner@example.com";
    process.env.SUPER_ADMIN_PASSWORD = "super-segreta";
    app = buildApp();

    const superAdminLoginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "owner@example.com",
        password: "super-segreta"
      }
    });
    expect(superAdminLoginResponse.statusCode).toBe(200);
    const superAdminToken = superAdminLoginResponse.json().token as string;

    const createResponse = await app.inject({
      method: "POST",
      url: "/admin/api/users",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${superAdminToken}`
      },
      payload: {
        email: "managed.user@example.com",
        password: "managed-pass",
        role: "user"
      }
    });
    expect(createResponse.statusCode).toBe(201);
    expect(createResponse.json()).toMatchObject({
      user: {
        email: "managed.user@example.com",
        role: "user",
        isAdmin: false
      }
    });
    expect(typeof createResponse.json().recoveryCode).toBe("string");

    const createdUserId = createResponse.json().user.id as string;

    const searchResponse = await app.inject({
      method: "GET",
      url: "/admin/api/users?search=managed.user",
      headers: {
        authorization: `Bearer ${superAdminToken}`
      }
    });
    expect(searchResponse.statusCode).toBe(200);
    expect(searchResponse.json()).toMatchObject({
      items: [
        {
          id: createdUserId,
          email: "managed.user@example.com",
          role: "user"
        }
      ]
    });

    const updateResponse = await app.inject({
      method: "PATCH",
      url: `/admin/api/users/${createdUserId}`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${superAdminToken}`
      },
      payload: {
        email: "managed.updated@example.com",
        role: "admin"
      }
    });
    expect(updateResponse.statusCode).toBe(200);
    expect(updateResponse.json()).toMatchObject({
      id: createdUserId,
      email: "managed.updated@example.com",
      role: "admin",
      isAdmin: true
    });

    const deleteResponse = await app.inject({
      method: "DELETE",
      url: `/admin/api/users/${createdUserId}`,
      headers: {
        authorization: `Bearer ${superAdminToken}`
      }
    });
    expect(deleteResponse.statusCode).toBe(200);
    expect(deleteResponse.json()).toEqual({
      deleted: true,
      userId: createdUserId
    });

    const searchAfterDeleteResponse = await app.inject({
      method: "GET",
      url: "/admin/api/users?search=managed.updated",
      headers: {
        authorization: `Bearer ${superAdminToken}`
      }
    });
    expect(searchAfterDeleteResponse.statusCode).toBe(200);
    expect(searchAfterDeleteResponse.json()).toEqual({
      items: []
    });
  });

  it("allows only the super admin to create, edit and delete users", async () => {
    process.env.SUPER_ADMIN_EMAIL = "owner@example.com";
    process.env.SUPER_ADMIN_PASSWORD = "super-segreta";
    app = buildApp();

    const superAdminLoginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "owner@example.com",
        password: "super-segreta"
      }
    });
    expect(superAdminLoginResponse.statusCode).toBe(200);
    const superAdminToken = superAdminLoginResponse.json().token as string;

    const adminCandidateResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        email: "admin@example.com",
        password: "admin-password"
      }
    });
    expect(adminCandidateResponse.statusCode).toBe(201);
    const adminCandidateToken = adminCandidateResponse.json().token as string;

    const promoteResponse = await app.inject({
      method: "POST",
      url: `/admin/api/users/${adminCandidateResponse.json().user.id as string}/admin`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${superAdminToken}`
      },
      payload: {
        isAdmin: true
      }
    });
    expect(promoteResponse.statusCode).toBe(200);

    const createManagedUserResponse = await app.inject({
      method: "POST",
      url: "/admin/api/users",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${superAdminToken}`
      },
      payload: {
        email: "target.user@example.com",
        password: "target-pass",
        role: "user"
      }
    });
    expect(createManagedUserResponse.statusCode).toBe(201);
    const targetUserId = createManagedUserResponse.json().user.id as string;

    const forbiddenCreateResponse = await app.inject({
      method: "POST",
      url: "/admin/api/users",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${adminCandidateToken}`
      },
      payload: {
        email: "forbidden@example.com",
        password: "forbidden-pass",
        role: "user"
      }
    });
    expect(forbiddenCreateResponse.statusCode).toBe(403);
    expect(forbiddenCreateResponse.json()).toEqual({
      error: "Super admin required"
    });

    const forbiddenUpdateResponse = await app.inject({
      method: "PATCH",
      url: `/admin/api/users/${targetUserId}`,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${adminCandidateToken}`
      },
      payload: {
        email: "forbidden.update@example.com"
      }
    });
    expect(forbiddenUpdateResponse.statusCode).toBe(403);
    expect(forbiddenUpdateResponse.json()).toEqual({
      error: "Super admin required"
    });

    const forbiddenDeleteResponse = await app.inject({
      method: "DELETE",
      url: `/admin/api/users/${targetUserId}`,
      headers: {
        authorization: `Bearer ${adminCandidateToken}`
      }
    });
    expect(forbiddenDeleteResponse.statusCode).toBe(403);
    expect(forbiddenDeleteResponse.json()).toEqual({
      error: "Super admin required"
    });
  });
});
