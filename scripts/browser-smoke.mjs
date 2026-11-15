import { chromium } from "playwright";
import { spawn } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";
import assert from "node:assert/strict";

const origin = "http://127.0.0.1:5173";
const server = spawn("npm", ["run", "dev", "--", "--host", "127.0.0.1"], {
  stdio: "ignore",
  shell: process.platform === "win32",
});
let browser;

async function waitForServer() {
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const response = await fetch(origin);
      if (response.ok) return;
    } catch {}
    await delay(250);
  }
  throw new Error("Vite development server did not become ready");
}

async function waitForGame(page) {
  await page.goto(origin, { waitUntil: "domcontentloaded" });
  await page.waitForSelector("#game canvas", { state: "visible", timeout: 15000 });
  await page.waitForFunction(() => Boolean(window.arcaneTest), { timeout: 15000 });
}

try {
  await waitForServer();
  browser = await chromium.launch({ headless: true, executablePath: process.env.CHROME_BIN });

  const desktop = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const pageErrors = [];
  desktop.on("pageerror", error => pageErrors.push(error.message));
  await waitForGame(desktop);

  const canvasSize = await desktop.locator("#game canvas").evaluate(canvas => ({
    width: canvas.width,
    height: canvas.height,
  }));
  assert.ok(canvasSize.width > 0 && canvasSize.height > 0, "game canvas should have a real drawing surface");

  const beforeMove = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  await desktop.keyboard.down("w");
  await delay(450);
  await desktop.keyboard.up("w");
  const afterMove = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  assert.ok(
    Math.hypot(afterMove.x - beforeMove.x, afterMove.y - beforeMove.y) > 20,
    "keyboard movement should move the wizard",
  );

  // Walk into the Grand Library footprint and confirm the wizard slides along its edge.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(560, 410));
  await desktop.keyboard.down("d");
  await delay(650);
  await desktop.keyboard.up("d");
  const afterCollision = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  assert.ok(afterCollision.x < 575, "building collision should prevent walking through the library wall");
  assert.ok(afterCollision.y > 410, "axis-separated collision should allow sliding along the wall");

  await desktop.keyboard.press("Space");
  await delay(500);
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(900, 480));
  await desktop.keyboard.down("e");
  await delay(120);
  await desktop.keyboard.up("e");
  await desktop.locator("#dialogue").waitFor({ state: "visible" });
  assert.equal(await desktop.locator("#npc-name").textContent(), "Archmage Elowen");
  assert.deepEqual(pageErrors, [], "desktop play session should not throw browser errors");

  const mobile = await browser.newPage({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    isMobile: true,
    hasTouch: true,
  });
  const mobileErrors = [];
  mobile.on("pageerror", error => mobileErrors.push(error.message));
  await waitForGame(mobile);
  await mobile.locator("#stick").waitFor({ state: "visible" });
  await mobile.locator("#cast").click();
  await mobile.evaluate(() => window.arcaneTest.setPlayerPosition(900, 480));
  await mobile.locator("#interact").click();
  await mobile.locator("#dialogue").waitFor({ state: "visible" });
  assert.equal(await mobile.locator("#npc-name").textContent(), "Archmage Elowen");

  const stick = await mobile.locator("#stick").boundingBox();
  assert.ok(stick, "mobile movement stick should be visible");
  const start = { x: stick.x + stick.width / 2, y: stick.y + stick.height / 2 };
  const beforeStick = await mobile.evaluate(() => window.arcaneTest.getPlayerPosition());
  await mobile.mouse.move(start.x, start.y);
  await mobile.mouse.down();
  await mobile.mouse.move(start.x + 26, start.y - 22, { steps: 6 });
  await delay(450);
  await mobile.mouse.up();
  const afterStick = await mobile.evaluate(() => window.arcaneTest.getPlayerPosition());
  assert.ok(
    Math.hypot(afterStick.x - beforeStick.x, afterStick.y - beforeStick.y) > 10,
    "mobile virtual joystick should move the wizard",
  );
  assert.deepEqual(mobileErrors, [], "mobile play session should not throw browser errors");

  console.log("Browser smoke test passed: canvas, keyboard movement, spell cast, NPC dialogue, mobile controls.");
} finally {
  if (browser) await browser.close();
  server.kill("SIGTERM");
}
