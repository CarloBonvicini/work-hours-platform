interface ReleaseMetadataSnapshot {
  tag: string;
  version: string;
  buildNumber: string;
  fileName: string;
  publishedAt?: string;
}

interface ReleaseStatusSnapshot {
  state: "publishing";
  tag: string;
  version: string;
  buildNumber: string;
  startedAt?: string;
}

interface TicketSnapshot {
  category: "bug" | "feature" | "support";
  status: "new" | "in_progress" | "answered" | "closed";
  createdAt: string;
  updatedAt: string;
}

export interface BuildAdminOverviewOptions {
  baseUrl: string;
  latestRelease: ReleaseMetadataSnapshot | null;
  releaseStatus: ReleaseStatusSnapshot | null;
  tickets: TicketSnapshot[];
}

function countTicketsByStatus(
  tickets: TicketSnapshot[],
  status: TicketSnapshot["status"]
) {
  return tickets.filter((ticket) => ticket.status === status).length;
}

function countTicketsByCategory(
  tickets: TicketSnapshot[],
  category: TicketSnapshot["category"]
) {
  return tickets.filter((ticket) => ticket.category === category).length;
}

function buildTicketStats(tickets: TicketSnapshot[]) {
  const waitingCount = countTicketsByStatus(tickets, "new");
  const inProgressCount = countTicketsByStatus(tickets, "in_progress");
  const answeredCount = countTicketsByStatus(tickets, "answered");
  const closedCount = countTicketsByStatus(tickets, "closed");

  return {
    total: tickets.length,
    waiting: waitingCount,
    inProgress: inProgressCount,
    answered: answeredCount,
    closed: closedCount,
    active: waitingCount + inProgressCount,
    resolved: answeredCount + closedCount,
    bug: countTicketsByCategory(tickets, "bug"),
    feature: countTicketsByCategory(tickets, "feature"),
    support: countTicketsByCategory(tickets, "support"),
    latestCreatedAt: tickets[0]?.createdAt ?? null,
    latestUpdatedAt: tickets[0]?.updatedAt ?? null
  };
}

export function buildAdminOverview(options: BuildAdminOverviewOptions) {
  const { baseUrl, latestRelease, releaseStatus, tickets } = options;
  const ticketStats = buildTicketStats(tickets);

  return {
    generatedAt: new Date().toISOString(),
    service: "work-hours-backend",
    dataProvider: process.env.DATA_PROVIDER ?? "memory",
    links: {
      landing: `${baseUrl}/`,
      publicTickets: `${baseUrl}/tickets`,
      health: `${baseUrl}/health`,
      releaseFeed: `${baseUrl}/mobile-updates/latest.json`
    },
    release: {
      current: latestRelease
        ? {
            version: latestRelease.version,
            tag: latestRelease.tag,
            publishedAt: latestRelease.publishedAt ?? null,
            fileName: latestRelease.fileName
          }
        : null,
      publishing: releaseStatus
        ? {
            version: releaseStatus.version,
            tag: releaseStatus.tag,
            startedAt: releaseStatus.startedAt ?? null
          }
        : null
    },
    tickets: ticketStats
  };
}
