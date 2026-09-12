import type { FastifyInstance } from "fastify";
import type { AppStore } from "../data/store.js";
import { parseLeaveEntryPayload, parseWorkEntryPayload } from "../domain/entry-payloads.js";

interface EntryParams {
  id: string;
}

/**
 * Modifica e cancellazione di voci di lavoro e causali. Le route restano
 * sottili: validazione del corpo, chiamata allo store, codici HTTP.
 */
export function registerEntryMutationRoutes(app: FastifyInstance, store: AppStore): void {
  app.put<{ Params: EntryParams }>("/work-entries/:id", async (request, reply) => {
    const parsed = parseWorkEntryPayload(request.body);
    if (parsed.error !== undefined) {
      return reply.code(400).send({ error: parsed.error });
    }

    const updated = await store.updateWorkEntry({ id: request.params.id, ...parsed.value });
    if (!updated) {
      return reply.code(404).send({ error: "work entry not found" });
    }

    return updated;
  });

  app.delete<{ Params: EntryParams }>("/work-entries/:id", async (request, reply) => {
    const deleted = await store.deleteWorkEntry(request.params.id);
    if (!deleted) {
      return reply.code(404).send({ error: "work entry not found" });
    }

    return reply.code(204).send();
  });

  app.put<{ Params: EntryParams }>("/leave-entries/:id", async (request, reply) => {
    const parsed = parseLeaveEntryPayload(request.body);
    if (parsed.error !== undefined) {
      return reply.code(400).send({ error: parsed.error });
    }

    const updated = await store.updateLeaveEntry({ id: request.params.id, ...parsed.value });
    if (!updated) {
      return reply.code(404).send({ error: "leave entry not found" });
    }

    return updated;
  });

  app.delete<{ Params: EntryParams }>("/leave-entries/:id", async (request, reply) => {
    const deleted = await store.deleteLeaveEntry(request.params.id);
    if (!deleted) {
      return reply.code(404).send({ error: "leave entry not found" });
    }

    return reply.code(204).send();
  });
}
