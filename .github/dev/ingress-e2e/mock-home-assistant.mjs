// Minimal stand-in for Home Assistant: a page with an ingress iframe and the ingress proxy.
// Every request outside the ingress path is recorded as a leak at /__leaks. The real UI must
// never cause one: it would land on Home Assistant instead of on NPMplus.
import http from "node:http";

const PREFIX = "/api/hassio_ingress/TESTTOKEN";
const APP_PORT = Number(process.env.APP_INGRESS_PORT ?? 5594);
// The app only accepts the Supervisor's address; the test adds it to the loopback interface.
const SUPERVISOR_ADDRESS = process.env.SUPERVISOR_ADDRESS ?? "172.30.32.2";
const leaks = [];

const proxyToApp = (request, response) => {
  const upstream = http.request({
    host: "127.0.0.1",
    port: APP_PORT,
    method: request.method,
    path: request.url.slice(PREFIX.length) || "/",
    localAddress: SUPERVISOR_ADDRESS,
    headers: { ...request.headers, "x-ingress-path": PREFIX, host: `127.0.0.1:${APP_PORT}` },
  }, (reply) => {
    response.writeHead(reply.statusCode, reply.headers);
    reply.pipe(response);
  });
  upstream.on("error", (error) => {
    response.statusCode = 502;
    response.end(String(error));
  });
  request.pipe(upstream);
};

http.createServer((request, response) => {
  if (request.url === "/") {
    response.setHeader("content-type", "text/html");
    response.end(`<!doctype html><title>Mock Home Assistant</title><iframe id="panel" src="${PREFIX}/" style="width:100%;height:95vh;border:0"></iframe>`);
  } else if (request.url === "/__leaks") {
    response.setHeader("content-type", "application/json");
    response.end(JSON.stringify(leaks));
  } else if (request.url === "/__reset") {
    leaks.length = 0;
    response.end("ok");
  } else if (request.url === PREFIX || request.url.startsWith(`${PREFIX}/`)) {
    proxyToApp(request, response);
  } else {
    leaks.push(`${request.method} ${request.url}`);
    response.statusCode = 404;
    response.end("not found");
  }
}).listen(8123, "127.0.0.1", () => console.log("mock Home Assistant on :8123"));
