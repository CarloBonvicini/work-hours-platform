import { afterAll, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

const app = buildApp();

describe("GET /health", () => {
  it("returns service health info", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/health"
    });

    expect(response.statusCode).toBe(200);

    const body = response.json();
    expect(body.status).toBe("ok");
    expect(body.service).toBe("work-hours-backend");
    expect(typeof body.timestamp).toBe("string");
  });
});

afterAll(async () => {
  await app.close();
});

