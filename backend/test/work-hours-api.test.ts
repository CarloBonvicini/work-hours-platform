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
        monday: {
          targetMinutes: 480,
          breakMinutes: 0
        }
      },
      workRules: {
        expectedDailyMinutes: 432,
        minimumBreakMinutes: 0,
        maximumDailyCreditMinutes: 1440,
        maximumDailyDebitMinutes: 1440,
        maximumMonthlyCreditMinutes: 44640,
        maximumMonthlyDebitMinutes: 44640
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
        monday: {
          targetMinutes: 480,
          breakMinutes: 0
        }
      },
      workRules: {
        expectedDailyMinutes: 432,
        minimumBreakMinutes: 0,
        maximumDailyCreditMinutes: 1440,
        maximumDailyDebitMinutes: 1440,
        maximumMonthlyCreditMinutes: 44640,
        maximumMonthlyDebitMinutes: 44640
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
    expect(registerBody.recoveryCode).toEqual(expect.any(String));

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
          weekdaySchedule: buildUniformWeekdaySchedule(480),
          workRules: {
            expectedDailyMinutes: 480,
            minimumBreakMinutes: 30,
            maximumDailyCreditMinutes: 60,
            maximumDailyDebitMinutes: 45,
            maximumMonthlyCreditMinutes: 240,
            maximumMonthlyDebitMinutes: 180
          }
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
    expect(typeof backupResponse.json().savedAt).toBe("string");
    expect(backupResponse.json().droppedItems).toEqual({
      workEntries: 0,
      leaveEntries: 0,
      scheduleOverrides: 0
    });

    const backupMetaResponse = await app.inject({
      method: "GET",
      url: "/me/backup/meta",
      headers: {
        authorization: `Bearer ${registerBody.token}`
      }
    });
    expect(backupMetaResponse.statusCode).toBe(200);
    expect(backupMetaResponse.json()).toMatchObject({
      hasBackup: true,
      updatedAt: expect.any(String)
    });

    const loginResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: {
        email: "carlo@example.com",
        password: "super-segreta"
      }
    });
    expect(loginResponse.statusCode).toBe(200);

    const setupRecoveryQuestionsResponse = await app.inject({
      method: "PUT",
      url: "/me/recovery-questions",
      headers: {
        authorization: `Bearer ${loginResponse.json().token}`
      },
      payload: {
        questionOne: "Nome del primo animale?",
        answerOne: "2",
        questionTwo: "Citta in cui sei nato?",
        answerTwo: "T"
      }
    });
    expect(setupRecoveryQuestionsResponse.statusCode).toBe(200);
    expect(setupRecoveryQuestionsResponse.json()).toMatchObject({
      success: true,
      questionOne: "Nome del primo animale?",
      questionTwo: "Citta in cui sei nato?"
    });

    const lookupQuestionsResponse = await app.inject({
      method: "POST",
      url: "/auth/recovery-questions",
      payload: {
        email: "carlo@example.com"
      }
    });
    expect(lookupQuestionsResponse.statusCode).toBe(200);
    expect(lookupQuestionsResponse.json()).toMatchObject({
      available: true,
      questionOne: "Nome del primo animale?",
      questionTwo: "Citta in cui sei nato?"
    });

    const resetResponse = await app.inject({
      method: "POST",
      url: "/auth/recover-password",
      payload: {
        email: "carlo@example.com",
        answerOne: "2",
        answerTwo: "T",
        newPassword: "nuova-password"
      }
    });
    expect(resetResponse.statusCode).toBe(200);
    expect(resetResponse.json()).toMatchObject({
      success: true,
      recoveryCode: expect.any(String)
    });

    const loginWithNewPasswordResponse = await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: {
        email: "carlo@example.com",
        password: "nuova-password"
      }
    });
    expect(loginWithNewPasswordResponse.statusCode).toBe(200);

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
          fullName: "Carlo",
          workRules: {
            expectedDailyMinutes: 480,
            minimumBreakMinutes: 30,
            maximumDailyCreditMinutes: 60,
            maximumDailyDebitMinutes: 45,
            maximumMonthlyCreditMinutes: 240,
            maximumMonthlyDebitMinutes: 180
          }
        },
        appearanceSettings: {
          themeMode: "dark"
        }
      }
    });
  });

  it("locks password recovery after too many wrong answers", async () => {
    const registerResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      payload: {
        email: "locked@example.com",
        password: "super-segreta"
      }
    });
    expect(registerResponse.statusCode).toBe(201);
    const token = registerResponse.json().token as string;

    const setupResponse = await app.inject({
      method: "PUT",
      url: "/me/recovery-questions",
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        questionOne: "Domanda uno personalizzata?",
        answerOne: "risposta uno",
        questionTwo: "Domanda due personalizzata?",
        answerTwo: "risposta due"
      }
    });
    expect(setupResponse.statusCode).toBe(200);

    for (let attempt = 1; attempt < 5; attempt += 1) {
      const response = await app.inject({
        method: "POST",
        url: "/auth/recover-password",
        payload: {
          email: "locked@example.com",
          answerOne: "sbagliata",
          answerTwo: "sbagliata",
          newPassword: "nuova-password"
        }
      });
      expect(response.statusCode).toBe(401);
    }

    const lockedResponse = await app.inject({
      method: "POST",
      url: "/auth/recover-password",
      payload: {
        email: "locked@example.com",
        answerOne: "sbagliata",
        answerTwo: "sbagliata",
        newPassword: "nuova-password"
      }
    });
    expect(lockedResponse.statusCode).toBe(429);
    expect(lockedResponse.json()).toMatchObject({
      error: "too many recovery attempts",
      retryAfterMinutes: expect.any(Number)
    });
  });

  it("keeps backup working even when some items are invalid", async () => {
    const registerResponse = await app.inject({
      method: "POST",
      url: "/auth/register",
      payload: {
        email: "sanitize@example.com",
        password: "super-segreta"
      }
    });
    expect(registerResponse.statusCode).toBe(201);
    const token = registerResponse.json().token as string;

    const backupResponse = await app.inject({
      method: "PUT",
      url: "/me/backup",
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        profile: {
          id: "local-profile",
          fullName: "Sanitize",
          useUniformDailyTarget: true,
          dailyTargetMinutes: 480,
          weekdayTargetMinutes: buildUniformWeekdayTargetMinutes(480),
          weekdaySchedule: buildUniformWeekdaySchedule(480),
          workRules: {
            expectedDailyMinutes: 480,
            minimumBreakMinutes: 0,
            maximumDailyCreditMinutes: 120,
            maximumDailyDebitMinutes: 120,
            maximumMonthlyCreditMinutes: 480,
            maximumMonthlyDebitMinutes: 480
          }
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
            id: "ok-work",
            date: "2026-03-20",
            minutes: 120
          },
          {
            id: "bad-work",
            date: "invalid-date",
            minutes: 60
          }
        ],
        leaveEntries: [
          {
            id: "ok-leave",
            date: "2026-03-20",
            minutes: 60,
            type: "permit"
          },
          {
            id: "bad-leave",
            date: "2026-03-20",
            minutes: -10,
            type: "permit"
          }
        ],
        scheduleOverrides: [
          {
            id: "ok-override",
            date: "2026-03-20",
            targetMinutes: 420,
            startTime: "08:30",
            endTime: "16:30",
            breakMinutes: 60
          },
          {
            id: "bad-override",
            date: "2026-03-20",
            targetMinutes: 420,
            startTime: "invalid",
            endTime: "16:30",
            breakMinutes: 60
          }
        ]
      }
    });

    expect(backupResponse.statusCode).toBe(200);
    expect(backupResponse.json().droppedItems).toEqual({
      workEntries: 1,
      leaveEntries: 1,
      scheduleOverrides: 1
    });

    const restoreResponse = await app.inject({
      method: "GET",
      url: "/me/backup",
      headers: {
        authorization: `Bearer ${token}`
      }
    });
    expect(restoreResponse.statusCode).toBe(200);
    expect(restoreResponse.json().bundle.workEntries).toHaveLength(1);
    expect(restoreResponse.json().bundle.leaveEntries).toHaveLength(1);
    expect(restoreResponse.json().bundle.scheduleOverrides).toHaveLength(1);
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
      },
      workRules: {
        expectedDailyMinutes: 432,
        minimumBreakMinutes: 30,
        maximumDailyCreditMinutes: 60,
        maximumDailyDebitMinutes: 90,
        maximumMonthlyCreditMinutes: 240,
        maximumMonthlyDebitMinutes: 120
      }
    };

    await app.inject({
      method: "PUT",
      url: "/profile",
      payload: {
        fullName: profile.fullName,
        useUniformDailyTarget: profile.useUniformDailyTarget,
        weekdaySchedule: profile.weekdaySchedule,
        workRules: profile.workRules
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
      rawBalanceMinutes: 960 - expectedMinutes,
      balanceMinutes: -120,
      remainingCreditMinutes: 240,
      remainingDebitMinutes: 0
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
      workRules: {
        expectedDailyMinutes: 420,
        minimumBreakMinutes: 0,
        maximumDailyCreditMinutes: 1440,
        maximumDailyDebitMinutes: 1440,
        maximumMonthlyCreditMinutes: 44640,
        maximumMonthlyDebitMinutes: 44640
      },
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
