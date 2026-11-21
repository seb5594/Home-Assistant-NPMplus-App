// Drives the admin UI through the mock ingress with Chromium: first-run setup, every menu entry,
// a reload, logout and login. Fails on any request that escapes the ingress path.
const { chromium } = require("playwright");
const assert = require("node:assert/strict");

const MOCK = "http://127.0.0.1:8123";
const PREFIX = "/api/hassio_ingress/TESTTOKEN";
const ADMIN = { name: "Test Admin", email: "admin@example.org", password: "correct-horse-battery-staple" };
const step = (message) => console.log(`- ${message}`);

(async () => {
  await fetch(`${MOCK}/__reset`);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const problems = [];
  page.on("pageerror", (error) => problems.push(`page error: ${error.message}`));
  page.on("console", (message) => {
    // Expected while logged out or before the setup: 401 and 403 answers of the API.
    if (message.type() === "error" && !/status of 40[134]/.test(message.text())) {
      problems.push(`console: ${message.text()}`);
    }
  });
  await page.goto(`${MOCK}/`);
  const frame = page.frameLocator("#panel");
  const panelUrl = () => page.frames().find((candidate) => candidate.url().includes(PREFIX)).url();

  await frame.getByPlaceholder("Full Name").fill(ADMIN.name);
  await frame.getByPlaceholder("Email address").fill(ADMIN.email);
  await frame.getByPlaceholder("New Password").fill(ADMIN.password);
  await frame.getByRole("button", { name: "Save" }).click();
  await frame.locator("footer.footer .npmplus-app-footer").waitFor({ timeout: 20000 });
  step("setup finished, dashboard and app footer visible");
  const footer = await frame.locator(".npmplus-app-footer").innerText();
  assert.match(footer, /NPMplus for Home Assistant \d/);
  assert.match(footer, /Made with \u2764\uFE0F in Germany \uD83C\uDDE9\uD83C\uDDEA/);
  assert.match(footer, /Support my work \u2615\uD83C\uDF7A/);
  step("footer texts are right");
  assert.equal(await page.evaluate(() => document.querySelector("#panel").contentDocument.body.dataset.theme), "dark");
  step("dark theme is the default");
  await page.screenshot({ path: "ingress-dashboard.png" });

  const links = await frame.locator("a.nav-link, .dropdown-item[href]").evaluateAll((elements, prefix) =>
    [...new Set(elements.map((element) => element.getAttribute("href")))]
      .filter((href) => href?.startsWith(prefix) && !/locale/.test(href)), PREFIX);
  for (const href of links) {
    // Menu entries sit in closed dropdowns, so they are clicked programmatically.
    await frame.locator(`a[href="${href}"]`).first().evaluate((element) => element.click());
    await page.waitForTimeout(1200);
    assert.ok(panelUrl().includes(PREFIX), `left the ingress path: ${panelUrl()}`);
    assert.ok((await frame.locator("#root").innerText()).length > 20, `empty page at ${href}`);
  }
  step(`visited ${links.length} pages`);

  await page.frames().find((candidate) => candidate.url().includes(PREFIX)).evaluate(() => window.location.reload());
  await frame.locator("footer.footer").waitFor({ timeout: 20000 });
  step("reload stays inside the UI");

  await frame.locator('[data-translation-id="user.logout"]').evaluate((element) => element.click());
  await frame.getByPlaceholder(/email/i).waitFor({ timeout: 20000 });
  assert.ok(panelUrl().includes(PREFIX), `logout left the frame: ${panelUrl()}`);
  await frame.getByPlaceholder(/email/i).fill(ADMIN.email);
  await frame.getByPlaceholder(/password/i).fill(ADMIN.password);
  await frame.getByRole("button", { name: /sign in|log ?in/i }).click();
  await frame.locator("footer.footer").waitFor({ timeout: 20000 });
  step("logout and login work");

  const leaks = await (await fetch(`${MOCK}/__leaks`)).json();
  assert.deepEqual(leaks, [], "requests escaped the ingress path");
  assert.deepEqual(problems, [], "the browser reported problems");
  await browser.close();
  console.log("Ingress flow passed");
})().catch((error) => {
  console.error(`Ingress flow FAILED: ${error.message}`);
  process.exit(1);
});
