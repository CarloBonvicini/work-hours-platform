import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";
import {
  buildExpectedMinutes,
  buildUniformWeekdayTargetMinutes
} from "../src/domain/monthly-summary.js";

let app = buildApp();

afterEach(async () => {
  await app.close();
  app = buildApp();
});

describe("Profile API", () => {
  it("updates and returns profile", async () => {
    const updateResponse = await app.inject({
      method: "PUT",
      url: "/profile",
      payload: {
        fullName: "Carlo Bonvicini",
        useUniformDailyTarget: false,
        weekdayTargetMinutes: {
          monday: 480,
          tuesday: 360,
          wednesday: 360,
          thursday: 480,
          friday: 480,
          saturday: 0,
          sunday: 0
        }
      }
    });

    expect(updateResponse.statusCode).toBe(200);
    expect(updateResponse.json()).toMatchObject({
      id: "default-profile",
      fullName: "Carlo Bonvicini",
      useUniformDailyTarget: false,
      weekdayTargetMinutes: {
        monday: 480,
        tuesday: 360,
        wednesday: 360,
        thursday: 480,
        friday: 480,
        saturday: 0,
        sunday: 0
      }
    });

    const profileResponse = await app.inject({
      method: "GET",
      url: "/profile"
    });

    expect(profileResponse.statusCode).toBe(200);
    expect(profileResponse.json()).toMatchObject({
      id: "default-profile",
      fullName: "Carlo Bonvicini",
      useUniformDailyTarget: false,
      weekdayTargetMinutes: {
        monday: 480,
        tuesday: 360,
        wednesday: 360,
        thursday: 480,
        friday: 480,
        saturday: 0,
        sunday: 0
      }
    });
  });
});

describe("Work and leave entries API", () => {
  it("creates entries, stores schedule overrides and computes monthly summary", async () => {
    const profile = {
      id: "default-profile",
      fullName: "Carlo Bonvicini",
      useUniformDailyTarget: false,
      dailyTargetMinutes: 432,
      weekdayTargetMinutes: {
        monday: 480,
        tuesday: 360,
        wednesday: 360,
        thursday: 480,
        friday: 480,
        saturday: 0,
        sunday: 0
      }
    };

    await app.inject({
      method: "PUT",
      url: "/profile",
      payload: {
        fullName: profile.fullName,
        useUniformDailyTarget: profile.useUniformDailyTarget,
        weekdayTargetMinutes: profile.weekdayTargetMinutes
      }
    });

    const workEntryA = await app.inject({
      method: "POST",
      url: "/work-entries",
      payload: {
        date: "2026-03-02",
        minutes: 480,
        note: "Giornata piena"
      }
    });
    expect(workEntryA.statusCode).toBe(201);

    const workEntryB = await app.inject({
      method: "POST",
      url: "/work-entries",
      payload: {
        date: "2026-03-03",
        minutes: 420
      }
    });
    expect(workEntryB.statusCode).toBe(201);

    const leaveEntry = await app.inject({
      method: "POST",
      url: "/leave-entries",
      payload: {
        date: "2026-03-04",
        minutes: 60,
        type: "permit"
      }
    });
    expect(leaveEntry.statusCode).toBe(201);

    const overrideEntry = await app.inject({
      method: "POST",
      url: "/schedule-overrides",
      payload: {
        date: "2026-03-03",
        targetMinutes: 480,
        note: "Scambio turno"
      }
    });
    expect(overrideEntry.statusCode).toBe(201);

    const listWorkEntries = await app.inject({
      method: "GET",
      url: "/work-entries?month=2026-03"
    });
    expect(listWorkEntries.statusCode).toBe(200);
    expect(listWorkEntries.json().items).toHaveLength(2);

    const listLeaveEntries = await app.inject({
      method: "GET",
      url: "/leave-entries?month=2026-03"
    });
    expect(listLeaveEntries.statusCode).toBe(200);
    expect(listLeaveEntries.json().items).toHaveLength(1);

    const listOverrides = await app.inject({
      method: "GET",
      url: "/schedule-overrides?month=2026-03"
    });
    expect(listOverrides.statusCode).toBe(200);
    expect(listOverrides.json().items).toEqual([
      {
        id: expect.any(String),
        date: "2026-03-03",
        targetMinutes: 480,
        note: "Scambio turno"
      }
    ]);

    const summaryResponse = await app.inject({
      method: "GET",
      url: "/monthly-summary/2026-03"
    });

    expect(summaryResponse.statusCode).toBe(200);
    const summary = summaryResponse.json();

    const expectedMinutes = buildExpectedMinutes("2026-03", profile, [
      {
        id: "override-1",
        date: "2026-03-03",
        targetMinutes: 480,
        note: "Scambio turno"
      }
    ]);
    expect(summary).toEqual({
      month: "2026-03",
      expectedMinutes,
      workedMinutes: 900,
      leaveMinutes: 60,
      balanceMinutes: 960 - expectedMinutes
    });
  });

  it("supports uniform profile payload for backward compatibility", async () => {
    const updateResponse = await app.inject({
      method: "PUT",
      url: "/profile",
      payload: {
        fullName: "Uniforme",
        useUniformDailyTarget: true,
        dailyTargetMinutes: 420
      }
    });

    expect(updateResponse.statusCode).toBe(200);
    expect(updateResponse.json()).toMatchObject({
      fullName: "Uniforme",
      useUniformDailyTarget: true,
      dailyTargetMinutes: 420,
      weekdayTargetMinutes: buildUniformWeekdayTargetMinutes(420)
    });
  });

  it("rejects invalid month query", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/work-entries?month=2026-13"
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "month must be in YYYY-MM format"
    });
  });

  it("removes a schedule override by date", async () => {
    await app.inject({
      method: "POST",
      url: "/schedule-overrides",
      payload: {
        date: "2026-03-05",
        targetMinutes: 300
      }
    });

    const deleteResponse = await app.inject({
      method: "DELETE",
      url: "/schedule-overrides/2026-03-05"
    });

    expect(deleteResponse.statusCode).toBe(204);
  });
});
