import { buildApp } from "./app.js";
import { InMemoryStore } from "./data/in-memory-store.js";
import { PostgresStore } from "./data/postgres-store.js";
import type { AppStore } from "./data/store.js";

const host = process.env.HOST ?? "0.0.0.0";
const port = Number(process.env.PORT ?? 8080);
const dataProvider = process.env.DATA_PROVIDER ?? "memory";

async function createStore(): Promise<AppStore> {
  if (dataProvider === "postgres") {
    const connectionString = process.env.DATABASE_URL ?? "";
    return await PostgresStore.create({ connectionString });
  }

  return new InMemoryStore();
}

async function start() {
  const store = await createStore();
  const app = buildApp({ store });

  app.addHook("onClose", async () => {
    if (typeof store.close === "function") {
      await store.close();
    }
  });

  try {
    await app.listen({ host, port });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
}

start();
