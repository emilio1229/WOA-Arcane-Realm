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
  await page.waitForFunction(() => document.querySelector("#enter-realm")?.disabled === false, { timeout: 15000 });
  await page.locator("#enter-realm").click();
  await page.locator("#creator-screen").waitFor({ state: "visible" });
  await page.locator("#character-name").fill("Playtester");
  await page.locator("#begin-journey").click();
  await page.waitForFunction(() => document.querySelector("#realm-intro")?.classList.contains("dismissed"));
}

try {
  await waitForServer();
  browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_BIN,
    args: ["--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows"],
  });

  const desktop = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const pageErrors = [];
  desktop.on("pageerror", error => pageErrors.push(error.message));
  await waitForGame(desktop);

  const canvasSize = await desktop.locator("#game canvas").evaluate(canvas => ({
    width: canvas.width,
    height: canvas.height,
  }));
  assert.ok(canvasSize.width > 0 && canvasSize.height > 0, "game canvas should have a real drawing surface");
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getBuildingDetailsLoaded()), true,
    "all detailed building overlays and the Moonwell fountain should be loaded into the Sanctuary scene");
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getTownPropsLoaded()), true,
    "the noticeboard and signpost props should be loaded into the Sanctuary scene");

  // Every tradition must retain its own robe palette while idle. A previous
  // regression reset every idle wizard to the first sprite-sheet row.
  const traditions = ["storm-herald", "ember-mage", "frostweaver", "verdant-warden", "voidcaller", "sigilbinder"];
  for (let index = 0; index < traditions.length; index++) {
    await desktop.evaluate(name => window.arcaneSetCharacter(name, "#b98bea"), traditions[index]);
    await delay(80);
    assert.equal(await desktop.evaluate(() => window.arcaneTest.getWizardTexture()), "wizard-traditions-walk");
    assert.equal(await desktop.evaluate(() => window.arcaneTest.getWizardFrame()), index * 4,
      `${traditions[index]} should display its own idle sprite row`);
  }
  await desktop.evaluate(() => window.arcaneSetCharacter("storm-herald", "#b98bea"));

  // Verify the live movement controller reaches the same world-space speed
  // for a cardinal and a diagonal input. This avoids timing noise from CI FPS.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(900, 760));
  await desktop.evaluate(() => { window.arcaneMove = { x: 0, y: -1 }; });
  await desktop.waitForFunction(() => window.arcaneTest.getMovementSpeed() > 180, { timeout: 3000, polling: 50 });
  const cardinalSpeed = await desktop.evaluate(() => window.arcaneTest.getMovementSpeed());
  await desktop.evaluate(() => { window.arcaneMove = { x: 0, y: 0 }; });
  await desktop.waitForFunction(() => window.arcaneTest.getMovementSpeed() < 1, { timeout: 3000, polling: 50 });
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(900, 760));
  await desktop.evaluate(() => { window.arcaneMove = { x: 1, y: -1 }; });
  await desktop.waitForFunction(() => window.arcaneTest.getMovementSpeed() > 180, { timeout: 3000, polling: 50 });
  const diagonalSpeed = await desktop.evaluate(() => window.arcaneTest.getMovementSpeed());
  await desktop.evaluate(() => { window.arcaneMove = { x: 0, y: 0 }; });
  await desktop.waitForFunction(() => window.arcaneTest.getMovementSpeed() < 1, { timeout: 3000, polling: 50 });
  assert.ok(Math.abs(cardinalSpeed - diagonalSpeed) < 2,
    "cardinal and diagonal movement should have the same world-space speed");

  // The mobile joystick is analog: half deflection should produce about half speed.
  await desktop.evaluate(() => { window.arcaneMove = { x: 0, y: -0.5 }; });
  await desktop.waitForFunction(() => window.arcaneTest.getMovementSpeed() > 85 && window.arcaneTest.getMovementSpeed() < 105,
    { timeout: 3000, polling: 50 });
  const halfStickSpeed = await desktop.evaluate(() => window.arcaneTest.getMovementSpeed());
  assert.ok(Math.abs(halfStickSpeed / cardinalSpeed - 0.5) < 0.08,
    "half joystick deflection should produce approximately half movement speed");
  await desktop.evaluate(() => { window.arcaneMove = { x: 0, y: 0 }; });
  await desktop.waitForFunction(() => window.arcaneTest.getMovementSpeed() < 1, { timeout: 3000, polling: 50 });

  await desktop.locator("#pause-game").click();
  await desktop.locator("#pause-overlay").waitFor({ state: "visible" });
  await desktop.locator("[data-menu-tab=journal]").click();
  await desktop.waitForFunction(() => document.querySelector("[data-menu-page=journal]")?.classList.contains("hidden") === false);
  assert.equal(await desktop.locator("[data-menu-tab=journal]").getAttribute("aria-selected"), "true");
  await desktop.locator("[data-menu-tab=controls]").click();
  await desktop.waitForFunction(() => document.querySelector("[data-menu-page=controls]")?.classList.contains("hidden") === false);
  assert.equal(await desktop.locator("[data-menu-tab=controls]").getAttribute("aria-selected"), "true");
  await desktop.locator("#resume-journey").click();
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
  // Town landmarks have contextual interactions, not just decorative labels.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(650, 510));
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getNearestTownLocation()), "Grand Library");
  await desktop.keyboard.press("e");
  await desktop.locator("#dialogue").waitFor({ state: "visible" });
  assert.equal(await desktop.locator("#npc-name").textContent(), "Grand Library");
  assert.ok((await desktop.locator("#npc-line").textContent()).includes("sealed atlas room"));
  await desktop.locator("#close-dialogue").click();

  // Academy interaction repairs the practice target; the inn is a real safe-rest point.
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(560, 835));
  await desktop.evaluate(() => { window.arcaneTest.damagePracticeWisp(); window.arcaneTest.damagePracticeWisp(); });
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getPracticeWispHealth()), 1);
  await desktop.keyboard.press("e");
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getPracticeWispHealth()), 3,
    "Spell Academy interaction should restore the training target");
  await desktop.locator("#close-dialogue").click();

  await desktop.evaluate(() => window.arcaneTest.forcePlayerHit());
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getPlayerHealth()), 4);
  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(900, 1080));
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getNearestTownLocation()), "Adventurer's Inn");
  await desktop.keyboard.press("e");
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getPlayerHealth()), 5,
    "resting at the Adventurer's Inn should restore full vitality");
  assert.equal(await desktop.evaluate(() => window.arcaneTest.getHitRecoveryMs()), 0,
    "resting at the Inn should clear hit recovery");
  await desktop.locator("#close-dialogue").click();

  await desktop.evaluate(() => window.arcaneTest.setPlayerPosition(900, 480));
  await desktop.locator("#cast-spell").click();
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
  // Wait for the actual attack rather than assuming a fixed number of headless frames.
  await desktop.waitForFunction(() => window.arcaneTest.getPlayerHealth() < 5, undefined, { timeout: 6000, polling: 50 });
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
  const mobilePresentation = await mobile.evaluate(() => ({
    zoom: window.arcaneTest.getCameraZoom(),
    screenSpeed: window.arcaneTest.getScreenMovementSpeed(),
    viewportHeight: document.querySelector("#app").getBoundingClientRect().height,
    documentHeight: document.documentElement.clientHeight,
    stick: document.querySelector("#stick").getBoundingClientRect().toJSON(),
    interact: document.querySelector("#interact").getBoundingClientRect().toJSON(),
    cast: document.querySelector("#cast").getBoundingClientRect().toJSON(),
    dodge: document.querySelector("#dodge").getBoundingClientRect().toJSON(),
  }));
  assert.ok(mobilePresentation.zoom >= 0.8, "iPhone camera should keep the wizard at a readable scale");
  assert.ok(mobilePresentation.viewportHeight <= mobilePresentation.documentHeight + 1,
    "mobile layout should fit the visible viewport without page overflow");
  for (const [name, rect] of Object.entries({
    stick: mobilePresentation.stick, interact: mobilePresentation.interact,
    cast: mobilePresentation.cast, dodge: mobilePresentation.dodge,
  })) {
    assert.ok(rect.width >= 48 && rect.height >= 48, `${name} should meet the minimum touch target size`);
  }
  await mobile.evaluate(() => { window.arcaneMove = { x: 0, y: -1 }; });
  await mobile.waitForFunction(() => window.arcaneTest.getScreenMovementSpeed() > 160, { timeout: 3000, polling: 50 });
  await mobile.evaluate(() => { window.arcaneMove = { x: 0, y: 0 }; });
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
