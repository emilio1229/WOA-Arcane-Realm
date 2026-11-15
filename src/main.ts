import Phaser from "phaser";
import "./style.css";

declare global {
  interface Window {
    arcaneMove?: { x: number; y: number };
    arcaneInteract?: () => void;
    arcaneCast?: () => void;
    /** Development-only hooks used by the headless browser smoke test. */
    arcaneTest?: {
      getPlayerPosition: () => { x: number; y: number };
      setPlayerPosition: (x: number, y: number) => void;
    };
  }
}

type NPC = { name: string; x: number; y: number; line: string; color: number };
const WORLD = { width: 1800, height: 1250 };
const NPCS: NPC[] = [
  { name: "Archmage Elowen", x: 900, y: 480, line: "Welcome, wayfarer. The Sanctuary has been waiting for someone with a spark of curiosity. Wander freely; there is much to discover here.", color: 0xd6a4ff },
  { name: "Archivist Quill", x: 650, y: 310, line: "Every stone in this square remembers something. The Grand Library keeps the stories that the world has almost forgotten.", color: 0x9fd8ee },
  { name: "Merchant Zia", x: 1190, y: 620, line: "A traveler! Lovely. My shelves are being stocked. Come back when you're ready to trade tales for treasures.", color: 0xe9c17a },
  { name: "Keeper Moth", x: 1120, y: 330, line: "Some familiars choose their wizards. You cannot rush a bond, little spark. Listen closely when the quiet magic stirs.", color: 0x9fe2c2 },
];

class SanctuaryScene extends Phaser.Scene {
  private player!: Phaser.Physics.Arcade.Image;
  private playerArt!: Phaser.GameObjects.Container;
  private wizardSprite!: Phaser.GameObjects.Image;
  private familiarArt!: Phaser.GameObjects.Image;
  private familiarGlow!: Phaser.GameObjects.Ellipse;
  private lastFacing = new Phaser.Math.Vector2(0, -1);
  private nextCastAt = 0;
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private obstacles: Phaser.Geom.Rectangle[] = [];
  private npcs: Array<{ data: NPC; art: Phaser.GameObjects.Container }> = [];
  private prompt!: Phaser.GameObjects.Text;
  private interactHandler = () => this.interact();

  constructor() { super("Sanctuary"); }

  preload() {
    this.load.svg("wizard-arcane", "/assets/characters/wizard-arcane.svg", { width: 128, height: 160 });
    this.load.svg("wizard-arcane-cast", "/assets/characters/wizard-arcane-cast.svg", { width: 128, height: 160 });
    this.load.svg("wizard-ember", "/assets/characters/wizard-ember.svg", { width: 128, height: 160 });
    this.load.svg("wizard-frost", "/assets/characters/wizard-frost.svg", { width: 128, height: 160 });
    this.load.svg("wizard-verdant", "/assets/characters/wizard-verdant.svg", { width: 128, height: 160 });
    this.load.svg("wizard-shadow", "/assets/characters/wizard-shadow.svg", { width: 128, height: 160 });
    this.load.svg("glimmer", "/assets/familiars/glimmer.svg", { width: 128, height: 128 });
    this.load.svg("verdant-sprite", "/assets/familiars/verdant-sprite.svg", { width: 128, height: 128 });
    this.load.svg("ember-wisp", "/assets/creatures/ember-wisp.svg", { width: 128, height: 128 });
    this.load.svg("frost-wisp", "/assets/creatures/frost-wisp.svg", { width: 128, height: 128 });
    this.load.svg("grand-portal", "/assets/environment/grand-portal.svg", { width: 256, height: 256 });
    this.load.svg("arcane-bolt", "/assets/vfx/arcane-bolt.svg", { width: 64, height: 64 });
    this.load.svg("arcane-impact", "/assets/vfx/arcane-impact.svg", { width: 128, height: 128 });
    this.load.svg("arcane-mote", "/assets/vfx/arcane-mote.svg", { width: 64, height: 64 });
    this.load.svg("sigil", "/assets/ui/sigil.svg", { width: 64, height: 64 });
    this.load.svg("building-library", "/assets/buildings/grand-library.svg", { width: 256, height: 256 });
    this.load.svg("building-familiar", "/assets/buildings/familiar-sanctuary.svg", { width: 256, height: 256 });
    this.load.svg("building-academy", "/assets/buildings/spell-academy.svg", { width: 256, height: 256 });
    this.load.svg("building-merchant", "/assets/buildings/merchant-hall.svg", { width: 256, height: 256 });
    this.load.svg("building-inn", "/assets/buildings/adventurer-inn.svg", { width: 256, height: 256 });
    this.load.svg("prop-lantern", "/assets/props/sanctuary-lantern.svg", { width: 64, height: 128 });
    this.load.svg("prop-obelisk", "/assets/props/rune-obelisk.svg", { width: 128, height: 128 });
    this.load.svg("prop-crystals", "/assets/props/crystal-cluster.svg", { width: 128, height: 128 });
  }

  create() {
    this.cameras.main.setBackgroundColor("#182335");
    this.drawWorld();
    this.createBuildings();
    this.createNPCs();
    this.createAssetShowcase();
    this.createAmbientMagic();

    this.player = this.physics.add.image(900, 760, "__WHITE");
    this.player.setDisplaySize(18, 18).setTint(0xffffff).setAlpha(0);
    this.player.body!.setCircle(9, 0, 0);
    this.player.setCollideWorldBounds(true);
    this.playerArt = this.add.container(this.player.x, this.player.y).setDepth(900);
    this.drawWizard(this.playerArt);
    this.familiarGlow = this.add.ellipse(this.player.x - 8, this.player.y + 34, 54, 30, 0xb98bea, 0.13).setDepth(this.player.y + 12);
    this.familiarArt = this.add.image(this.player.x - 8, this.player.y + 24, "glimmer")
      .setDisplaySize(42, 42).setDepth(this.player.y + 18);
    this.cameras.main.setBounds(0, 0, WORLD.width, WORLD.height);
    this.cameras.main.startFollow(this.player, true, 0.08, 0.08);
    this.cameras.main.setZoom(Math.min(1, this.scale.width / 1100));
    this.physics.world.setBounds(70, 70, WORLD.width - 140, WORLD.height - 140);

    this.keys = this.input.keyboard!.addKeys("W,A,S,D,UP,DOWN,LEFT,RIGHT,E,ENTER,SPACE") as Record<string, Phaser.Input.Keyboard.Key>;
    this.prompt = this.add.text(0, 0, "E  SPEAK", {
      fontFamily: "Manrope, sans-serif", fontSize: "11px", color: "#fff4d9",
      backgroundColor: "#2c1e40", padding: { x: 9, y: 6 }, stroke: "#d5a5ef", strokeThickness: 1,
    }).setOrigin(0.5, 1).setDepth(3000).setVisible(false).setScrollFactor(0);

    this.input.on("pointerdown", (pointer: Phaser.Input.Pointer) => {
      if (pointer.wasTouch && pointer.x > this.scale.width * 0.58 && pointer.y > this.scale.height * 0.55) this.interact();
    });
    window.arcaneInteract = this.interactHandler;
    window.arcaneCast = () => this.castSpell();
    if (import.meta.env.DEV) {
      window.arcaneTest = {
        getPlayerPosition: () => ({ x: this.player.x, y: this.player.y }),
        setPlayerPosition: (x, y) => {
          this.player.setVelocity(0, 0);
          this.player.setPosition(x, y);
          this.player.body!.reset(x, y);
          this.playerArt.setPosition(x, y);
        },
      };
    }
    this.events.once("shutdown", () => {
      window.arcaneInteract = undefined;
      window.arcaneCast = undefined;
      window.arcaneTest = undefined;
    });
    this.scale.on("resize", (size: Phaser.Structs.Size) => this.cameras.main.setZoom(Math.min(1, size.width / 1100)));
  }

  private drawWorld() {
    const g = this.add.graphics();
    const tileW = 96, tileH = 48, cols = 28, rows = 28;
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        const x = 90 + (col - row) * tileW / 2 + WORLD.width / 2 - cols * tileW / 4;
        const y = 80 + (col + row) * tileH / 2;
        const plaza = col > 8 && col < 20 && row > 8 && row < 20;
        const color = plaza ? ((col + row) % 3 === 0 ? 0x66537a : 0x594b6e) : ((col + row) % 2 ? 0x294b43 : 0x315448);
        g.fillStyle(color, 1);
        g.lineStyle(1, 0x8c83a0, 0.16);
        g.beginPath(); g.moveTo(x, y - tileH / 2); g.lineTo(x + tileW / 2, y); g.lineTo(x, y + tileH / 2); g.lineTo(x - tileW / 2, y); g.closePath(); g.fillPath(); g.strokePath();
      }
    }
    // Garden beds and lantern-lit paths.
    for (const [x, y] of [[360, 470], [1430, 470], [440, 930], [1370, 930]]) {
      g.fillStyle(0x203a34); g.fillEllipse(x, y, 160, 72);
      g.fillStyle(0x3e7658); g.fillEllipse(x, y - 4, 130, 55);
      for (let i = 0; i < 7; i++) { g.fillStyle(i % 2 ? 0xd5a0f0 : 0xeac77f); g.fillCircle(x - 48 + i * 16, y - 8 + Math.sin(i) * 10, 3); }
    }
    this.add.circle(900, 600, 130, 0x302444, 0.35).setDepth(1);
    this.add.circle(900, 600, 96, 0x9d73c9, 0.08).setDepth(1);
    // Central fountain.
    g.fillStyle(0x28243c); g.fillEllipse(900, 620, 170, 82);
    g.fillStyle(0xb9a4d4); g.fillEllipse(900, 610, 132, 60);
    g.fillStyle(0x5799ad); g.fillEllipse(900, 604, 112, 46);
    g.fillStyle(0xc7b4dc); g.fillEllipse(900, 585, 35, 20);
    g.fillStyle(0x8fe6e7, 0.8); g.fillCircle(900, 573, 8);
    this.add.circle(900, 573, 25, 0x7edce8, 0.12).setDepth(2);
    // Grand portal.
    this.drawPortal(900, 270);
  }

  private drawPortal(x: number, y: number) {
    const portal = this.add.image(x, y, "grand-portal").setDisplaySize(250, 250).setDepth(100).setAlpha(0.92);
    this.tweens.add({ targets: portal, alpha: { from: 0.78, to: 1 }, scale: { from: 0.97, to: 1.02 }, duration: 2100, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });

    const orbit = { angle: 0 };
    const glyphs = [0, 1, 2, 3].map(index =>
      this.add.image(x, y, "sigil").setDisplaySize(25, 25).setAlpha(0.72).setDepth(105 + index)
    );
    this.tweens.add({
      targets: orbit, angle: 360, duration: 24000, repeat: -1, ease: "Linear",
      onUpdate: () => glyphs.forEach((glyph, index) => {
        const angle = Phaser.Math.DegToRad(orbit.angle + index * 90);
        glyph.setPosition(x + Math.cos(angle) * 104, y + Math.sin(angle) * 72);
        glyph.setRotation(angle + Math.PI / 2);
      }),
    });
  }

  private createBuildings() {
    this.building(650, 440, "GRAND LIBRARY", "building-library");
    this.building(1160, 450, "FAMILIAR SANCTUARY", "building-familiar");
    this.building(560, 760, "SPELL ACADEMY", "building-academy");
    this.building(1240, 820, "MERCHANT", "building-merchant");
    this.building(900, 1000, "ADVENTURER'S INN", "building-inn");
  }

  private building(x: number, y: number, label: string, texture: string) {
    this.add.image(x, y + 22, texture).setDisplaySize(255, 255).setOrigin(0.5, 1).setDepth(y);
    this.add.text(x, y + 52, label, { fontFamily: "Cinzel, serif", fontSize: "10px", color: "#f3e3ff", stroke: "#1a1424", strokeThickness: 3, letterSpacing: 1 }).setOrigin(0.5).setDepth(y + 5);
    this.obstacles.push(new Phaser.Geom.Rectangle(x - 75, y - 85, 150, 105));
  }

  private createNPCs() {
    const looks = ["wizard-arcane", "wizard-frost", "wizard-ember", "wizard-verdant"];
    NPCS.forEach((npc, index) => {
      const art = this.add.container(npc.x, npc.y).setDepth(npc.y + 10);
      const portrait = this.add.image(0, 0, looks[index]).setDisplaySize(70, 88).setOrigin(0.5, 0.9);
      art.add(portrait);
      this.add.text(npc.x, npc.y + 35, npc.name, { fontFamily: "Cinzel,serif", fontSize: "10px", color: "#fff0d9", stroke: "#21172e", strokeThickness: 3 }).setOrigin(0.5).setDepth(npc.y + 15);
      this.npcs.push({ data: npc, art });
      this.tweens.add({ targets: art, y: npc.y - 3, duration: 1500 + index * 170, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    });
  }

  private createAssetShowcase() {
    const glimmer = this.add.image(1165, 285, "glimmer").setDisplaySize(76, 76).setDepth(330);
    this.tweens.add({ targets: glimmer, y: 267, angle: { from: -7, to: 7 }, duration: 1700, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    this.add.text(1165, 324, "GLIMMER", { fontFamily: "Cinzel,serif", fontSize: "9px", color: "#e9dcff", stroke: "#21172e", strokeThickness: 3 }).setOrigin(0.5).setDepth(340);

    const sprite = this.add.image(1380, 285, "verdant-sprite").setDisplaySize(66, 66).setDepth(330);
    this.tweens.add({ targets: sprite, y: 267, angle: { from: 5, to: -5 }, duration: 1900, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    this.add.text(1380, 324, "VERDANT SPRITE", { fontFamily: "Cinzel,serif", fontSize: "8px", color: "#c9ffd0", stroke: "#21172e", strokeThickness: 3 }).setOrigin(0.5).setDepth(340);

    const wisp = this.add.image(470, 635, "ember-wisp").setDisplaySize(74, 74).setDepth(645);
    this.tweens.add({ targets: wisp, y: 618, alpha: { from: 0.82, to: 1 }, duration: 1250, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    this.add.text(470, 674, "EMBER WISP", { fontFamily: "Cinzel,serif", fontSize: "9px", color: "#ffd0a1", stroke: "#21172e", strokeThickness: 3 }).setOrigin(0.5).setDepth(650);

    const frostWisp = this.add.image(1450, 640, "frost-wisp").setDisplaySize(70, 70).setDepth(650);
    this.tweens.add({ targets: frostWisp, y: 621, alpha: { from: 0.78, to: 1 }, duration: 1600, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    this.add.text(1450, 678, "FROST WISP", { fontFamily: "Cinzel,serif", fontSize: "9px", color: "#c8f5ff", stroke: "#21172e", strokeThickness: 3 }).setOrigin(0.5).setDepth(655);

    for (const [x, y] of [[365, 620], [1450, 620], [405, 1000], [1390, 1030]]) {
      const lantern = this.add.image(x, y, "prop-lantern").setDisplaySize(48, 96).setOrigin(0.5, 0.88).setDepth(y);
      this.tweens.add({ targets: lantern, alpha: { from: 0.82, to: 1 }, duration: 1900, yoyo: true, repeat: -1 });
    }
    const obelisk = this.add.image(760, 670, "prop-obelisk").setDisplaySize(92, 92).setDepth(680);
    this.add.image(1455, 900, "prop-crystals").setDisplaySize(112, 112).setDepth(910);
    this.tweens.add({ targets: obelisk, alpha: { from: 0.86, to: 1 }, duration: 2200, yoyo: true, repeat: -1 });
  }


  private drawWizard(container: Phaser.GameObjects.Container) {
    this.wizardSprite = this.add.image(0, 0, "wizard-arcane").setDisplaySize(78, 98).setOrigin(0.5, 0.9);
    container.add(this.wizardSprite);
  }

  private createAmbientMagic() {
    for (let i = 0; i < 16; i++) {
      const x = Phaser.Math.Between(500, 1300);
      const y = Phaser.Math.Between(360, 920);
      const mote = this.add.image(x, y, "arcane-mote")
        .setDisplaySize(Phaser.Math.Between(10, 20), Phaser.Math.Between(10, 20))
        .setAlpha(Phaser.Math.FloatBetween(0.25, 0.6))
        .setDepth(y + 2);
      this.tweens.add({
        targets: mote, y: y - Phaser.Math.Between(22, 58), alpha: 0.08,
        duration: Phaser.Math.Between(1800, 3600), delay: Phaser.Math.Between(0, 1800),
        yoyo: true, repeat: -1, ease: "Sine.easeInOut",
      });
    }
  }

  private castSpell() {
    // A small local cooldown keeps the prototype readable and prevents a pile-up of tweens.
    if (this.time.now < this.nextCastAt) return;
    this.nextCastAt = this.time.now + 350;
    const startX = this.player.x + this.lastFacing.x * 30;
    const startY = this.player.y - 28 + this.lastFacing.y * 30;
    const bolt = this.add.image(startX, startY, "arcane-bolt")
      .setDisplaySize(42, 42)
      .setDepth(this.player.y + 80)
      .setRotation(Math.atan2(this.lastFacing.y, this.lastFacing.x) + Math.PI / 2);
    const targetX = startX + this.lastFacing.x * 270;
    const targetY = startY + this.lastFacing.y * 270;
    this.tweens.add({
      targets: bolt, x: targetX, y: targetY, alpha: 0.25, scale: 0.45,
      duration: 390, ease: "Cubic.easeOut",
      onComplete: () => {
        bolt.destroy();
        const impact = this.add.image(targetX, targetY, "arcane-impact")
          .setDisplaySize(18, 18).setDepth(targetY + 90).setAlpha(0.95);
        this.tweens.add({
          targets: impact, displayWidth: 112, displayHeight: 112, alpha: 0,
          angle: 35, duration: 320, ease: "Cubic.easeOut",
          onComplete: () => impact.destroy(),
        });
      },
    });
    this.wizardSprite.setTexture("wizard-arcane-cast").setTint(0xe9d2ff);
    this.time.delayedCall(250, () => this.wizardSprite.setTexture("wizard-arcane"));
    this.tweens.add({
      targets: this.wizardSprite, alpha: 0.65, duration: 90, yoyo: true,
      onComplete: () => this.wizardSprite.clearTint(),
    });
  }

  private interact() {
    const nearby = this.nearestNPC();
    if (nearby) this.showDialogue(nearby.data);
  }

  private nearestNPC() {
    let best: { data: NPC; distance: number } | undefined;
    for (const npc of this.npcs) {
      const distance = Phaser.Math.Distance.Between(this.player.x, this.player.y, npc.data.x, npc.data.y);
      if (distance < 92 && (!best || distance < best.distance)) best = { data: npc.data, distance };
    }
    return best;
  }

  private showDialogue(npc: NPC) {
    const name = document.querySelector("#npc-name");
    const line = document.querySelector("#npc-line");
    const panel = document.querySelector("#dialogue");
    if (name) name.textContent = npc.name;
    if (line) line.textContent = npc.line;
    panel?.classList.remove("hidden");
  }

  update() {
    const keyboard = this.keys;
    let x = Number(keyboard.A.isDown || keyboard.LEFT.isDown) * -1 + Number(keyboard.D.isDown || keyboard.RIGHT.isDown);
    let y = Number(keyboard.W.isDown || keyboard.UP.isDown) * -1 + Number(keyboard.S.isDown || keyboard.DOWN.isDown);
    x += window.arcaneMove?.x ?? 0;
    y += window.arcaneMove?.y ?? 0;
    const vector = new Phaser.Math.Vector2((x - y) * 0.7071, (x + y) * 0.5);
    if (vector.length() > 1) vector.normalize();
    const speed = 190;
    const delta = Math.min(this.game.loop.delta, 50) / 1000;
    if (vector.lengthSq() > 0.001) this.lastFacing.copy(vector).normalize();
    const radius = 9;
    const minX = 70 + radius, maxX = WORLD.width - 70 - radius;
    const minY = 70 + radius, maxY = WORLD.height - 70 - radius;
    const collidesAt = (x: number, y: number) => {
      const circle = new Phaser.Geom.Circle(x, y, radius);
      return this.obstacles.some(rect => Phaser.Geom.Intersects.CircleToRectangle(circle, rect));
    };

    // Resolve each axis independently. This gives the player a reliable slide along
    // building footprints instead of freezing on a diagonal corner.
    const wantedX = Phaser.Math.Clamp(this.player.x + vector.x * speed * delta, minX, maxX);
    const wantedY = Phaser.Math.Clamp(this.player.y + vector.y * speed * delta, minY, maxY);
    let resolvedX = this.player.x;
    let resolvedY = this.player.y;
    if (!collidesAt(wantedX, resolvedY)) resolvedX = wantedX;
    if (!collidesAt(resolvedX, wantedY)) resolvedY = wantedY;

    // This is a kinematic character controller: physics supplies the body, while
    // movement and collision resolution stay deterministic across frame rates.
    this.player.setVelocity(0, 0);
    this.player.setPosition(resolvedX, resolvedY);
    this.player.body!.reset(resolvedX, resolvedY);
    this.playerArt.setPosition(resolvedX, resolvedY);
    this.wizardSprite.setRotation(vector.lengthSq() > 0.001 ? Math.sin(this.time.now / 75) * 0.035 : Math.sin(this.time.now / 520) * 0.012);
    this.playerArt.setDepth(this.player.y + 20);
    // Glimmer trails the wizard, eases into turns, and floats independently.
    const familiarTargetX = this.player.x - this.lastFacing.x * 44 - 8;
    const familiarTargetY = this.player.y - this.lastFacing.y * 34 + 18;
    const followEase = Phaser.Math.Clamp(delta * 5.5, 0, 1);
    this.familiarArt.x = Phaser.Math.Linear(this.familiarArt.x, familiarTargetX, followEase);
    this.familiarArt.y = Phaser.Math.Linear(this.familiarArt.y, familiarTargetY, followEase) + Math.sin(this.time.now / 260) * 3;
    this.familiarGlow.setPosition(this.familiarArt.x, this.familiarArt.y + 10);
    this.familiarGlow.setDepth(this.familiarArt.y + 12);
    this.familiarArt.setDepth(this.familiarArt.y + 18);
    this.npcs.forEach(n => n.art.setDepth(n.data.y + 10));
    const nearby = this.nearestNPC();
    this.prompt.setVisible(Boolean(nearby));
    if (nearby) {
      this.prompt.setPosition(this.scale.width / 2, this.scale.height - 105);
    }
    if (Phaser.Input.Keyboard.JustDown(keyboard.E) || Phaser.Input.Keyboard.JustDown(keyboard.ENTER)) this.interact();
    if (Phaser.Input.Keyboard.JustDown(keyboard.SPACE)) this.castSpell();
  }
}

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  backgroundColor: "#182335",
  scale: { mode: Phaser.Scale.RESIZE, width: "100%", height: "100%" },
  physics: { default: "arcade", arcade: { debug: false } },
  render: { antialias: true, pixelArt: false, roundPixels: false },
  scene: [SanctuaryScene],
});

const stick = document.querySelector<HTMLElement>("#stick");
const knob = document.querySelector<HTMLElement>("#stick-knob");
if (stick && knob) {
  let pointerId: number | null = null;
  const updateStick = (event: PointerEvent) => {
    const rect = stick!.getBoundingClientRect();
    const dx = event.clientX - (rect.left + rect.width / 2);
    const dy = event.clientY - (rect.top + rect.height / 2);
    const length = Math.max(1, Math.hypot(dx, dy));
    const radius = rect.width * 0.34;
    const scale = Math.min(1, radius / length);
    const nx = dx / length * scale;
    const ny = dy / length * scale;
    knob!.style.transform = `translate(${nx * radius}px,${ny * radius}px)`;
    window.arcaneMove = { x: nx, y: ny };
  };
  stick.addEventListener("pointerdown", event => { pointerId = event.pointerId; stick.setPointerCapture(pointerId); updateStick(event); });
  stick.addEventListener("pointermove", event => { if (event.pointerId === pointerId) updateStick(event); });
  const release = (event: PointerEvent) => { if (event.pointerId !== pointerId) return; pointerId = null; window.arcaneMove = { x: 0, y: 0 }; knob!.style.transform = "translate(0,0)"; };
  stick.addEventListener("pointerup", release);
  stick.addEventListener("pointercancel", release);
}
document.querySelector("#interact")?.addEventListener("click", () => window.arcaneInteract?.());
document.querySelector("#cast")?.addEventListener("click", () => window.arcaneCast?.());
document.querySelector("#close-dialogue")?.addEventListener("click", () => document.querySelector("#dialogue")?.classList.add("hidden"));
window.addEventListener("beforeunload", () => game.destroy(true));
