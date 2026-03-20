import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";
import {
  buildExpectedMinutes,
  buildUniformWeekdaySchedule,
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
      },
      weekdaySchedule: {
        monday: {
          targetMinutes: 480,
          breakMinutes: 0
        }
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
      },
      weekdaySchedule: {
        monday: {
          targetMinutes: 480,
          breakMinutes: 0
        }
      }
    });
  });
});

describe("Auth and cloud backup API", () => {
  it("registers, logs in and saves a cloud backup bundle", async () => {
    const registerResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      payload: {
        email: "carlo@example.com",
        password: "super-segreta"
      }
    });

    expect(registerResponse.statusCode).toBe(201);
    const registerBody = registerResponse.json();
    expect(registerBody.user).toMatchObject({
      email: "carlo@example.com"
    });
    expect(registerBody.token).toEqual(expect.any(String));

    const backupResponse = await app.inject({
      method: "PUT",
      url: "/me/backup",
      headers: {
        authorization: `Bearer ${registerBody.token}`
      },
      payload: {
        profile: {
          id: "local-profile",
          fullName: "Carlo",
          useUniformDailyTarget: true,
          dailyTargetMinutes: 480,
          weekdayTargetMinutes: buildUniformWeekdayTargetMinutes(480),
          weekdaySchedule: buildUniformWeekdaySchedule(480)
        },
        appearanceSettings: {
          themeMode: "dark",
          primaryColor: 123,
          secondaryColor: 456,
          textColor: 789,
          fontFamily: "system",
          textScale: 1
        },
        workEntries: [
          {
            id: "work-1",
            date: "2026-03-20",
            minutes: 300
          }
        ],
        leaveEntries: [
          {
            id: "leave-1",
            date: "2026-03-20",
            minutes: 60,
            type: "permit"
          }
        ],
        scheduleOverrides: [
          {
            id: "override-1",
            date: "2026-03-20",
            targetMinutes: 420,
            startTime: "08:30",
            endTime: "16:30",
            breakMinutes: 60
          }
        ]
      }
    });

    expect(backupResponse.statusCode).toBe(200);
    expect(backupResponse.json().bundle.profile.fullName).toBe("Carlo");

    const loginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: {
        email: "carlo@example.com",
        password: "super-segreta"
      }
    });
    expect(loginResponse.statusCode).toBe(200);

    const meResponse = await app.inject({
      method: "GET",
      url: "/auth/me",
      headers: {
        authorization: `Bearer ${loginResponse.json().token}`
      }
    });
    expect(meResponse.statusCode).toBe(200);
    expect(meResponse.json()).toMatchObject({
      email: "carlo@example.com"
    });

    const restoreResponse = await app.inject({
      method: "GET",
      url: "/me/backup",
      headers: {
        authorization: `Bearer ${loginResponse.json().token}`
      }
    });
    expect(restoreResponse.statusCode).toBe(200);
    expect(restoreResponse.json()).toMatchObject({
      hasBackup: true,
      bundle: {
        profile: {
          fullName: "Carlo"
        },
        appearanceSettings: {
          themeMode: "dark"
        }
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
      },
      weekdaySchedule: {
        monday: { targetMinutes: 480, startTime: "08:30", endTime: "17:00", breakMinutes: 30 },
        tuesday: { targetMinutes: 360, startTime: "08:30", endTime: "15:00", breakMinutes: 30 },
        wednesday: { targetMinutes: 360, startTime: "08:30", endTime: "15:00", breakMinutes: 30 },
        thursday: { targetMinutes: 480, startTime: "08:30", endTime: "17:00", breakMinutes: 30 },
        friday: { targetMinutes: 480, startTime: "08:30", endTime: "17:00", breakMinutes: 30 },
        saturday: { targetMinutes: 0, breakMinutes: 0 },
        sunday: { targetMinutes: 0, breakMinutes: 0 }
      }
    };

    await app.inject({
      method: "PUT",
      url: "/profile",
      payload: {
        fullName: profile.fullName,
        useUniformDailyTarget: profile.useUniformDailyTarget,
        weekdaySchedule: profile.weekdaySchedule
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
        startTime: "08:30",
        endTime: "17:30",
        breakMinutes: 60,
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
        startTime: "08:30",
        endTime: "17:30",
        breakMinutes: 60,
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
        startTime: "08:30",
        endTime: "17:30",
        breakMinutes: 60,
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
      weekdayTargetMinutes: buildUniformWeekdayTargetMinutes(420),
      weekdaySchedule: {
        monday: { targetMinutes: 420, breakMinutes: 0 },
        friday: { targetMinutes: 420, breakMinutes: 0 },
        saturday: { targetMinutes: 0, breakMinutes: 0 },
        sunday: { targetMinutes: 0, breakMinutes: 0 }
      }
    });
  });

  it("rejects schedule override when target does not match timing minus break", async () => {
    const response = await app.inject({
      method: "POST",
      url: "/schedule-overrides",
      payload: {
        date: "2026-03-05",
        targetMinutes: 360,
        startTime: "08:30",
        endTime: "17:00",
        breakMinutes: 30
      }
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "targetMinutes must match startTime/endTime minus breakMinutes"
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
