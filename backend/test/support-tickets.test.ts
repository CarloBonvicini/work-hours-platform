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
    expect(response.body).toContain("/admin");
    expect(response.body).toContain("Area admin");
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
    expect(Array.isArray(body.replies)).toBe(true);

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

  it("stores screenshot attachments and serves them back", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-tickets-"));
    process.env.TICKETS_DIR = tempDirectory;
    app = buildApp();

    const screenshotBytes = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0uoAAAAASUVORK5CYII=",
      "base64"
    );

    const response = await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json"
      },
      payload: {
        category: "bug",
        subject: "Screenshot allegato",
        message: "Ti mando uno screenshot del problema.",
        attachments: [
          {
            fileName: "errore-marzo.png",
            contentType: "image/png",
            base64Data: screenshotBytes.toString("base64")
          }
        ]
      }
    });

    expect(response.statusCode).toBe(201);
    const ticket = response.json() as {
      id: string;
      attachments: Array<{
        id: string;
        fileName: string;
        contentType: string;
        sizeBytes: number;
        downloadPath: string;
      }>;
    };
    expect(ticket.attachments).toHaveLength(1);
    expect(ticket.attachments[0]?.fileName).toBe("errore-marzo.png");
    expect(ticket.attachments[0]?.contentType).toBe("image/png");
    expect(ticket.attachments[0]?.downloadPath).toContain(
      `/tickets/${ticket.id}/attachments/`
    );

    const savedTicket = JSON.parse(
      await readFile(path.join(tempDirectory, `${ticket.id}.json`), "utf8")
    ) as {
      attachments: Array<{ storedFileName: string }>;
    };
    expect(savedTicket.attachments).toHaveLength(1);

    const attachmentResponse = await app.inject({
      method: "GET",
      url: ticket.attachments[0]!.downloadPath
    });

    expect(attachmentResponse.statusCode).toBe(200);
    expect(attachmentResponse.headers["content-type"]).toContain("image/png");
  });

  it("returns a public ticket thread and persists user replies", async () => {
    tempDirectory = await mkdtemp(path.join(os.tmpdir(), "work-hours-tickets-"));
    process.env.TICKETS_DIR = tempDirectory;
    app = buildApp();

    const createResponse = await app.inject({
      method: "POST",
      url: "/tickets",
      headers: {
        "content-type": "application/json",
        "user-agent": "Vitest"
      },
      payload: {
        category: "support",
        name: "Carlo",
        subject: "Serve aiuto",
        message: "Vorrei controllare il thread ticket."
      }
    });

    expect(createResponse.statusCode).toBe(201);
    const createdTicket = createResponse.json();

    const fetchResponse = await app.inject({
      method: "GET",
      url: `/tickets/${createdTicket.id}`
    });

    expect(fetchResponse.statusCode).toBe(200);
    expect(fetchResponse.json()).toMatchObject({
      id: createdTicket.id,
      status: "new",
      subject: "Serve aiuto",
      replies: []
    });

    const replyResponse = await app.inject({
      method: "POST",
      url: `/tickets/${createdTicket.id}/replies`,
      headers: {
        "content-type": "application/json"
      },
      payload: {
        message: "Aggiungo un dettaglio in piu."
      }
    });

    expect(replyResponse.statusCode).toBe(200);
    expect(replyResponse.json()).toMatchObject({
      id: createdTicket.id,
      status: "in_progress"
    });
    expect(replyResponse.json().replies).toHaveLength(1);
    expect(replyResponse.json().replies[0]).toMatchObject({
      author: "user",
      message: "Aggiungo un dettaglio in piu."
    });
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
