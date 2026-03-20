import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

let app = buildApp();
let tempDirectory: string | null = null;
const originalTicketsDir = process.env.TICKETS_DIR;
const originalAdminToken = process.env.ADMIN_DASHBOARD_TOKEN;

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
    expect(response.body).toContain("Panoramica rapida per manutenzione, release e ticket.");
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
        bug: 1
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
});
