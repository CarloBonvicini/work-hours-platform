import { buildApp } from "./app.js";

const app = buildApp();
const host = process.env.HOST ?? "0.0.0.0";
const port = Number(process.env.PORT ?? 8080);

async function start() {
  try {
    await app.listen({ host, port });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
}

start();

