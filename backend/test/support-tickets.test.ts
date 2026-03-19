import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

let app = buildApp();
let tempDirectory: string | null = null;
const originalTicketsDir = process.env.TICKETS_DIR;

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
});

describe("Support tickets", () => {
  it("serves the ticket page", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-tickets-"));
    process.env.TICKETS_DIR = tempDirectory;
    app = buildApp();

    const response = await app.inject({
      method: "GET",
      url: "/tickets"
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/html");
    expect(response.body).toContain("Invia un ticket");
    expect(response.body).toContain("Nuova funzione");
    expect(response.body).toContain("Segnala un problema che hai trovato.");
  });

  it("stores a valid support ticket on disk", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-tickets-"));
    process.env.TICKETS_DIR = tempDirectory;
    app = buildApp();

    const response = await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json",
        "user-agent": "Vitest"
      },
      payload: {
        category: "feature",
        name: "Carlo",
        email: "carlo@example.com",
        subject: "Calendario migliorato",
        message: "Vorrei una vista piu leggibile per i giorni del mese.",
        appVersion: "0.1.13"
      }
    });

    expect(response.statusCode).toBe(201);
    const body = response.json();
    expect(body.status).toBe("new");
    expect(body.id).toBeTruthy();
    expect(body.createdAt).toBeTruthy();

    const files = await readdir(tempDirectory);
    expect(files).toHaveLength(1);

    const ticket = JSON.parse(
      await readFile(path.join(tempDirectory, files[0]), "utf8")
    ) as Record<string, string>;

    expect(ticket.category).toBe("feature");
    expect(ticket.name).toBe("Carlo");
    expect(ticket.email).toBe("carlo@example.com");
    expect(ticket.subject).toBe("Calendario migliorato");
    expect(ticket.message).toContain("vista piu leggibile");
    expect(ticket.appVersion).toBe("0.1.13");
    expect(ticket.userAgent).toBe("Vitest");
  });

  it("rejects invalid tickets", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-tickets-"));
    process.env.TICKETS_DIR = tempDirectory;
    app = buildApp();

    const response = await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        category: "bug",
        message: "Manca il titolo"
      }
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "subject is required"
    });
    expect(await readdir(tempDirectory)).toHaveLength(0);
  });
});
