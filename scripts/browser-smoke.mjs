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
  await page.locator("#realm-intro").waitFor({ state: "visible" });
  await page.locator("#enter-realm").waitFor({ state: "enabled", timeout: 15000 });
  await page.locator("#enter-realm").click();
  await page.locator("#realm-intro").waitFor({ state: "hidden" });
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
  await desktop.locator("#pause-game").click();
  await desktop.locator("#pause-overlay").waitFor({ state: "visible" });
  await desktop.locator("#resume-game").click();
  await desktop.locator("#pause-overlay").waitFor({ state: "hidden" });
  await desktop.setViewportSize({ width: 980, height: 720 });
  await delay(300);
  const resizedCanvas = await desktop.locator("#game canvas").evaluate(canvas => ({ width: canvas.width, height: canvas.height }));
  assert.ok(resizedCanvas.width > 0 && resizedCanvas.height > 0, "game canvas should survive a viewport resize");
  assert.notEqual(resizedCanvas.width, canvasSize.width, "game canvas should adapt to the new viewport width");
  await desktop.setViewportSize({ width: 1280, height: 800 });
  await delay(150);

  const beforeMove = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  const familiarBeforeMove = await desktop.evaluate(() => window.arcaneTest.getFamiliarPosition());
  await desktop.keyboard.down("w");
  await delay(450);
  await desktop.keyboard.up("w");
  const afterMove = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  assert.ok(
    Math.hypot(afterMove.x - beforeMove.x, afterMove.y - beforeMove.y) > 20,
    "keyboard movement should move the wizard",
  );
  await delay(250);
  const familiarAfterMove = await desktop.evaluate(() => window.arcaneTest.getFamiliarPosition());
  assert.ok(
    Math.hypot(familiarAfterMove.x - familiarBeforeMove.x, familiarAfterMove.y - familiarBeforeMove.y) > 8,
    "Glimmer should follow the moving wizard",
  );

  // Approach the Grand Library's left wall, then move parallel to it.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(560, 410));
  await desktop.keyboard.down("d");
  await delay(300);
  await desktop.keyboard.up("d");
  const atWall = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  assert.ok(atWall.x <= 567, "building collision should stop the wizard at the library wall");
  assert.ok(atWall.y > 410, "axis-separated collision should preserve movement along the wall");

  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(560, 410));
  await desktop.keyboard.down("d");
  await desktop.keyboard.down("s");
  await delay(650);
  await desktop.keyboard.up("d");
  await desktop.keyboard.up("s");
  const afterCollision = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  assert.ok(afterCollision.x < 575, "wall sliding should keep the wizard outside the library footprint");
  assert.ok(afterCollision.y > 450, "the wizard should travel along the library wall");

  // Exercise casting from a neutral spot, away from the practice target so
  // this smoke check cannot consume one of its three test health points.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(900, 480));
  await desktop.keyboard.press("Space");
  await delay(500);
  await desktop.keyboard.down("e");
  await delay(120);
  await desktop.keyboard.up("e");
  await desktop.locator("#dialogue").waitFor({ state: "visible" });
  assert.equal(await desktop.locator("#npc-name").textContent(), "Archmage Elowen");

  // Aimed Arcane Bolts damage the Ember Wisp practice target and update its health.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(470, 760, 0, -1));
  const wispHealthBefore = await desktop.evaluate(() => window.arcaneTest.getPracticeWispHealth());
  assert.equal(wispHealthBefore, 3, "practice wisp should start with three health");
  for (let hit = 0; hit < 3; hit++) {
    await desktop.keyboard.down("Space");
    await delay(120);
    await desktop.keyboard.up("Space");
    await delay(650);
  }
  const wispHealthAfter = await desktop.evaluate(() => window.arcaneTest.getPracticeWispHealth());
  assert.equal(wispHealthAfter, 0, "three aimed Arcane Bolts should dispel the Ember Wisp");
  await delay(3700);
  const wispHealthRespawned = await desktop.evaluate(() => window.arcaneTest.getPracticeWispHealth());
  assert.equal(wispHealthRespawned, 3, "the practice wisp should respawn with full health");

  // The Frost Wisp's melee tell is escapable: it pauses pursuit and misses
  // when the wizard steps outside contact range before the 700ms windup ends.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(1450, 690, 0, 1));
  await delay(180);
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(1450, 710, 0, 1));
  await delay(620);
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getPlayerHealth()), 5,
    "the Frost Wisp should miss when the player leaves its contact radius during the tell");

  // The Frost Wisp should then pursue, land a fair close-range strike, and be
  // dispellable by aimed Arcane Bolts.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(1450, 760, 0, -1));
  await delay(2400); // Allow pursuit, the next telegraph, and the attack to resolve.
  const hostileHealthBefore = await desktop.evaluate(() => window.arcaneTest.getHostileWispHealth());
  assert.equal(hostileHealthBefore, 4, "hostile Frost Wisp should begin with four health");
  const healthBeforeFrostDefeat = await desktop.evaluate(() => window.arcaneTest.getPlayerHealth());
  assert.ok(healthBeforeFrostDefeat < 5, "the hostile Wisp should land its telegraphed attack before it is defeated");
  assert.ok(await desktop.evaluate(() => window.arcaneTest.getHitRecoveryMs()) > 0,
    "a successful enemy hit should start the player recovery window");
  assert.match(await desktop.locator("#health-status").textContent(), /HIT RECOVERY/,
    "the vitality HUD should clearly show hit recovery");

  const healthDuringRecovery = await desktop.evaluate(() => window.arcaneTest.getPlayerHealth());
  await desktop.evaluate(() => { window.arcaneTest.forcePlayerHit(); window.arcaneTest.forcePlayerHit(); });
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getPlayerHealth()), healthDuringRecovery,
    "overlapping hits should not remove multiple health during recovery");
  await delay(700);
  await desktop.evaluate(() => window.arcaneTest.forcePlayerHit());
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getPlayerHealth()), healthDuringRecovery - 1,
    "a new hit should be accepted after recovery expires");
  await delay(700);
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getHitRecoveryMs()), 0,
    "the recovery window should expire cleanly");
  for (let hit = 0; hit < 4; hit++) {
    await desktop.keyboard.down("Space");
    await delay(120);
    await desktop.keyboard.up("Space");
    await delay(650);
  }
  const hostileHealthAfter = await desktop.evaluate(() => window.arcaneTest.getHostileWispHealth());
  assert.equal(hostileHealthAfter, 0, "four aimed Arcane Bolts should dispel the Frost Wisp");
  // The dodge burst should move the wizard, grant a cooldown, and avoid the Sentry's aimed fire orb.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(340, 900, 0, 1));
  const healthBeforeFireOrb = await desktop.evaluate(() => window.arcaneTest.getPlayerHealth());
  await delay(760); // 620ms telegraph plus a short projectile travel window.
  const beforeDodge = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  await desktop.evaluate(() => window.arcaneTest.performDodge());
  await delay(120);
  const afterDodge = await desktop.evaluate(() => window.arcaneTest.getPlayerPosition());
  assert.ok(Math.hypot(afterDodge.x - beforeDodge.x, afterDodge.y - beforeDodge.y) > 30, "dodge should create a noticeable movement burst");
  const dodgeCooldown = await desktop.evaluate(() => window.arcaneTest.getDodgeCooldownMs());
  assert.ok(dodgeCooldown > 900, "dodge should start a meaningful cooldown");
  await delay(500);
  const healthAfterFireOrb = await desktop.evaluate(() => window.arcaneTest.getPlayerHealth());
  assert.equal(healthAfterFireOrb, healthBeforeFireOrb, "a correctly timed dodge should evade the Ember Sentry fire orb");

  // Stand just outside the Sentry's aggro radius while remaining within
  // Arcane Bolt range, so its return fire cannot interrupt the targetability check.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(440, 900, -1, 0));
  for (let hit = 0; hit < 5; hit++) {
    await desktop.keyboard.down("Space");
    await delay(120);
    await desktop.keyboard.up("Space");
    await delay(650);
  }
  const sentryHealthAfter = await desktop.evaluate(() => window.arcaneTest.getEmberSentryHealth());
  assert.equal(sentryHealthAfter, 0, "five aimed Arcane Bolts should dispel the Ember Sentry");

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
  await mobile.locator("#dodge").waitFor({ state: "visible" });
  await mobile.locator("#dodge").click();
  const mobileDodgeCooldown = await mobile.evaluate(() => window.arcaneTest.getDodgeCooldownMs());
  assert.ok(mobileDodgeCooldown > 0, "mobile dodge button should activate the dodge cooldown");
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

  console.log("Browser play test passed: canvas, keyboard movement, familiar following, building collision, spell cast, NPC dialogue, mobile controls.");
} finally {
  if (browser) await browser.close();
  server.kill("SIGTERM");
}
