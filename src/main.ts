import Phaser from "phaser";
import { HostileWisp } from "./game/HostileWisp";
import { EmberSentry } from "./game/EmberSentry";
import "./style.css";

declare global {
  interface Window {
    arcaneMove?: { x: number; y: number };
    arcaneInteract?: () => void;
    arcaneCast?: () => void;
    arcaneDodge?: () => void;
    arcaneSetCharacter?: (tradition: string, magicColor: string) => void;
    /** Development-only hooks used by the headless browser smoke test. */
    arcaneTest?: {
      getPlayerPosition: () => { x: number; y: number };
      getFamiliarPosition: () => { x: number; y: number };
      getPracticeWispHealth: () => number;
      getHostileWispHealth: () => number;
      getEmberSentryHealth: () => number;
      getPlayerHealth: () => number;
      getDodgeCooldownMs: () => number;
      getHitRecoveryMs: () => number;
      getWizardFrame: () => number;
      getWizardTexture: () => string;
      getMovementSpeed: () => number;
      getNearestTownLocation: () => string | null;
      getBuildingDetailsLoaded: () => boolean;
      performDodge: () => void;
      forcePlayerHit: () => void;
      setPlayerPosition: (x: number, y: number, facingX?: number, facingY?: number) => void;
    };
  }
}

type NPC = { name: string; x: number; y: number; line: string; color: number };
type TownLocation = { name: string; x: number; y: number; line: string; prompt: string }; 
const TOWN_LOCATIONS: TownLocation[] = [
  { name: "Grand Library", x: 650, y: 510, prompt: "E  EXPLORE", line: "The Grand Library rises in tiers of old stone and moonlit glass. Its sealed atlas room holds maps of places that no longer appear on ordinary charts. The Archivist may know which volume has begun whispering again." },
  { name: "Familiar Sanctuary", x: 1160, y: 520, prompt: "E  VISIT", line: "Soft wings stir behind the sanctuary's arched windows. Familiars are not summoned here; they arrive when a bond is ready. Keeper Moth tends the quiet rooms and records every first meeting." },
  { name: "Spell Academy", x: 560, y: 835, prompt: "E  TRAIN", line: "The academy's practice hall is etched with protective circles. Students learn to shape a spell safely before taking it beyond the Sanctuary walls. The duelling floor is reserved for supervised trials." },
  { name: "Merchant Hall", x: 1240, y: 895, prompt: "E  BROWSE", line: "Copper bells mark the Merchant Hall's doorway. Shelves are being arranged and the trade ledger is not yet open, but Zia's catalogue already lists curiosities from the outer reaches." },
  { name: "Adventurer's Inn", x: 900, y: 1080, prompt: "E  REST", line: "The inn smells of cedar, spiced tea, and rain-damp cloaks. Wayfarers leave messages for one another on the common-room board. The rooms are quiet tonight, though the road beyond the portal is not." },
];
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
  private wizardSprite!: Phaser.GameObjects.Sprite;
  private familiarArt!: Phaser.GameObjects.Image;
  private familiarGlow!: Phaser.GameObjects.Ellipse;
  private practiceWisp!: Phaser.GameObjects.Container;
  private practiceWispArt!: Phaser.GameObjects.Image;
  private practiceWispHealth = 3;
  private practiceWispFill!: Phaser.GameObjects.Rectangle;
  private practiceWispLabel!: Phaser.GameObjects.Text;
  private hostileWisp!: HostileWisp;
  private emberSentry!: EmberSentry;
  private playerHealth = 5;
  private lastFacing = new Phaser.Math.Vector2(0, -1);
  private dodgeVector = new Phaser.Math.Vector2(0, -1);
  private movementVelocity = new Phaser.Math.Vector2(0, 0);
  private dodgeUntil = 0;
  private invulnerableUntil = 0;
  private hitRecoveryUntil = 0;
  private nextDodgeAt = 0;
  private nextCastAt = 0;
  private currentTradition = "storm-herald";
  private currentTraditionIndex = 0;
  private magicColor = "#b98bea";
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private obstacles: Phaser.Geom.Rectangle[] = [];
  private npcs: Array<{ data: NPC; art: Phaser.GameObjects.Container }> = [];
  private townLocations = TOWN_LOCATIONS;
  private prompt!: Phaser.GameObjects.Text;
  private interactHandler = () => this.interact();

  constructor() { super("Sanctuary"); }

  preload() {
    this.load.on("progress", (value: number) => window.dispatchEvent(new CustomEvent("arcane:loading", { detail: value })));
    this.load.svg("wizard-arcane", "/assets/characters/wizard-arcane.svg", { width: 128, height: 160 });
    this.load.svg("wizard-arcane-cast", "/assets/characters/wizard-arcane-cast.svg", { width: 128, height: 160 });
    this.load.spritesheet("wizard-arcane-walk", "/assets/characters/wizard-arcane-walk.svg", { frameWidth: 256, frameHeight: 320 });
    this.load.spritesheet("wizard-traditions-walk", "/assets/characters/wizard-traditions-walk.svg", { frameWidth: 256, frameHeight: 320 });
    this.load.spritesheet("wizard-traditions-cast", "/assets/characters/wizard-traditions-cast.svg", { frameWidth: 256, frameHeight: 320 });
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
    this.load.svg("detail-library", "/assets/buildings/detail-library.svg", { width: 512, height: 512 });
    this.load.svg("detail-familiar", "/assets/buildings/detail-familiar.svg", { width: 512, height: 512 });
    this.load.svg("detail-academy", "/assets/buildings/detail-academy.svg", { width: 512, height: 512 });
    this.load.svg("detail-merchant", "/assets/buildings/detail-merchant.svg", { width: 512, height: 512 });
    this.load.svg("detail-inn", "/assets/buildings/detail-inn.svg", { width: 512, height: 512 });
    this.load.svg("prop-lantern", "/assets/props/sanctuary-lantern.svg", { width: 64, height: 128 });
    this.load.svg("prop-obelisk", "/assets/props/rune-obelisk.svg", { width: 128, height: 128 });
    this.load.svg("prop-crystals", "/assets/props/crystal-cluster.svg", { width: 128, height: 128 });
    this.load.svg("prop-noticeboard", "/assets/props/sanctuary-noticeboard.svg", { width: 320, height: 320 });
    this.load.svg("prop-signpost", "/assets/props/sanctuary-signpost.svg", { width: 256, height: 320 });
    this.load.svg("sanctuary-ground", "/assets/environment/sanctuary-ground.svg", { width: 1800, height: 1250 });
    this.load.svg("sanctuary-dressing", "/assets/environment/sanctuary-dressing.svg", { width: 1800, height: 1250 });
    this.load.svg("sanctuary-atmosphere", "/assets/environment/sanctuary-atmosphere.svg", { width: 1800, height: 1250 });
    this.load.svg("sanctuary-townlife", "/assets/environment/sanctuary-townlife.svg", { width: 1800, height: 1250 });
    this.load.svg("sanctuary-fountain", "/assets/environment/sanctuary-fountain.svg", { width: 512, height: 512 });
    this.load.svg("portal-rune-crown", "/assets/environment/portal-rune-crown.svg", { width: 512, height: 512 });
    this.load.spritesheet("arcane-burst", "/assets/vfx/arcane-burst-sheet.svg", { frameWidth: 96, frameHeight: 96 });
  }

  create() {
    this.cameras.main.setBackgroundColor("#182335");
    this.drawWorld();
    this.createBuildings();
    this.createNPCs();
    this.createAssetShowcase();
    this.createAmbientMagic();
    this.anims.create({ key: "arcane-impact-burst", frames: this.anims.generateFrameNumbers("arcane-burst", { start: 0, end: 5 }), frameRate: 15, repeat: 0 });
    this.anims.create({ key: "wizard-arcane-walk-cycle", frames: this.anims.generateFrameNumbers("wizard-arcane-walk", { start: 0, end: 3 }), frameRate: 8, repeat: -1 });
    ["storm-herald","ember-mage","frostweaver","verdant-warden","voidcaller","sigilbinder"].forEach((name,index) => this.anims.create({ key: `wizard-${name}-walk-cycle`, frames: this.anims.generateFrameNumbers("wizard-traditions-walk", { start: index * 4, end: index * 4 + 3 }), frameRate: 8, repeat: -1 }));

    this.player = this.physics.add.image(900, 760, "__WHITE");
    this.player.setDisplaySize(18, 18).setTint(0xffffff).setAlpha(0);
    this.player.body!.setCircle(9, 0, 0);
    this.player.setCollideWorldBounds(true);
    this.playerArt = this.add.container(this.player.x, this.player.y).setDepth(900);
    this.drawWizard(this.playerArt);
    this.familiarGlow = this.add.ellipse(this.player.x - 8, this.player.y + 34, 54, 30, 0xb98bea, 0.13).setDepth(this.player.y + 12);
    this.familiarArt = this.add.image(this.player.x - 8, this.player.y + 24, "glimmer")
      .setDisplaySize(42, 42).setDepth(this.player.y + 18);
    this.hostileWisp = new HostileWisp(this, 1450, 640, () => this.damagePlayer());
    this.emberSentry = new EmberSentry(
      this, 180, 900,
      () => this.damagePlayer(),
      () => this.time.now < Math.max(this.invulnerableUntil, this.hitRecoveryUntil),
      () => ({ x: this.player.x, y: this.player.y }),
    );
    this.cameras.main.setBounds(0, 0, WORLD.width, WORLD.height);
    this.cameras.main.startFollow(this.player, true, 0.08, 0.08);
    this.cameras.main.setZoom(Math.min(1, this.scale.width / 1100));
    this.physics.world.setBounds(70, 70, WORLD.width - 140, WORLD.height - 140);

    this.keys = this.input.keyboard!.addKeys("W,A,S,D,UP,DOWN,LEFT,RIGHT,E,ENTER,SPACE,SHIFT,ONE") as Record<string, Phaser.Input.Keyboard.Key>;
    this.prompt = this.add.text(0, 0, "E  SPEAK", {
      fontFamily: "Manrope, sans-serif", fontSize: "11px", color: "#fff4d9",
      backgroundColor: "#2c1e40", padding: { x: 9, y: 6 }, stroke: "#d5a5ef", strokeThickness: 1,
    }).setOrigin(0.5, 1).setDepth(3000).setVisible(false).setScrollFactor(0);

    this.input.on("pointerdown", (pointer: Phaser.Input.Pointer) => {
      if (pointer.wasTouch && pointer.x > this.scale.width * 0.58 && pointer.y > this.scale.height * 0.55) this.interact();
    });
    window.arcaneInteract = this.interactHandler;
    window.arcaneCast = () => this.castSpell();
    window.arcaneDodge = () => this.dodge();
    window.arcaneSetCharacter = (tradition, magicColor) => this.setCharacter(tradition, magicColor);
    if (import.meta.env.DEV) {
      window.arcaneTest = {
        getPlayerPosition: () => ({ x: this.player.x, y: this.player.y }),
        getFamiliarPosition: () => ({ x: this.familiarArt.x, y: this.familiarArt.y }),
        getPracticeWispHealth: () => this.practiceWispHealth,
        getHostileWispHealth: () => this.hostileWisp.currentHealth,
        getEmberSentryHealth: () => this.emberSentry.currentHealth,
        getPlayerHealth: () => this.playerHealth,
        getDodgeCooldownMs: () => Math.max(0, this.nextDodgeAt - this.time.now),
        getHitRecoveryMs: () => Math.max(0, this.hitRecoveryUntil - this.time.now),
        getWizardFrame: () => Number(this.wizardSprite.frame.name),
        getWizardTexture: () => this.wizardSprite.texture.key,
        getMovementSpeed: () => this.movementVelocity.length(),
        getNearestTownLocation: () => this.nearestTownLocation()?.name ?? null,
        getBuildingDetailsLoaded: () => ["detail-library","detail-familiar","detail-academy","detail-merchant","detail-inn","sanctuary-fountain"].every(key => this.textures.exists(key)),
        performDodge: () => this.dodge(),
        forcePlayerHit: () => this.damagePlayer(),
        setPlayerPosition: (x, y, facingX = 0, facingY = -1) => {
          this.player.setVelocity(0, 0);
          this.movementVelocity.set(0, 0);
          this.player.setPosition(x, y);
          this.player.body!.reset(x, y);
          this.playerArt.setPosition(x, y);
          this.lastFacing.set(facingX, facingY).normalize();
        },
      };
    }
    this.events.once("shutdown", () => {
      window.arcaneInteract = undefined;
      window.arcaneCast = undefined;
      window.arcaneDodge = undefined;
      window.arcaneSetCharacter = undefined;
      window.arcaneTest = undefined;
    });
    this.scale.on("resize", (size: Phaser.Structs.Size) => this.cameras.main.setZoom(Math.min(1, size.width / 1100)));
    this.game.events.emit("arcane:ready");
  }

  private drawWorld() {
    const g = this.add.graphics();
    const tileW = 96, tileH = 48, cols = 28, rows = 28;
    this.add.image(0, 0, "sanctuary-ground").setOrigin(0).setDisplaySize(WORLD.width, WORLD.height).setDepth(-1);
    this.add.image(0, 0, "sanctuary-dressing").setOrigin(0).setDisplaySize(WORLD.width, WORLD.height).setDepth(-0.5);
    this.add.image(0, 0, "sanctuary-atmosphere").setOrigin(0).setDisplaySize(WORLD.width, WORLD.height).setDepth(-0.25);
    this.add.image(0, 0, "sanctuary-townlife").setOrigin(0).setDisplaySize(WORLD.width, WORLD.height).setDepth(0.5);
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        const x = 90 + (col - row) * tileW / 2 + WORLD.width / 2 - cols * tileW / 4;
        const y = 80 + (col + row) * tileH / 2;
        const plaza = col > 8 && col < 20 && row > 8 && row < 20;
        if (!plaza && (col * 13 + row * 7) % 9 === 0) {
          g.fillStyle(0x8ce6b8, 0.18);
          g.fillCircle(x + ((col * 11) % 19) - 9, y + ((row * 5) % 9) - 4, 2);
        }
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
    // Sculpted moonwell fountain replaces the temporary flat ellipse stack.
    const fountain = this.add.image(900, 620, "sanctuary-fountain")
      .setDisplaySize(220, 220).setOrigin(0.5, 0.9).setDepth(620);
    this.tweens.add({ targets: fountain, alpha: { from: 0.94, to: 1 }, duration: 2600, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    for (const [x, y] of [[850, 566], [900, 548], [950, 566], [875, 590], [925, 590]]) {
      const glint = this.add.image(x, y, "arcane-mote").setDisplaySize(12, 12).setAlpha(0.5).setDepth(645);
      this.tweens.add({ targets: glint, y: y - 12, alpha: 0.08, duration: 1300 + (x % 3) * 170, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
    // Grand portal.
    this.drawPortal(900, 270);
  }

  private drawPortal(x: number, y: number) {
    const portal = this.add.image(x, y, "grand-portal").setDisplaySize(250, 250).setDepth(100).setAlpha(0.92);
    const runeCrown = this.add.image(x, y, "portal-rune-crown").setDisplaySize(282, 282).setDepth(101).setAlpha(0.82);
    this.tweens.add({ targets: runeCrown, angle: { from: -1.5, to: 1.5 }, alpha: { from: 0.68, to: 0.9 }, duration: 6800, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
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
    const detailKey: Record<string, string> = {
      "building-library": "detail-library",
      "building-familiar": "detail-familiar",
      "building-academy": "detail-academy",
      "building-merchant": "detail-merchant",
      "building-inn": "detail-inn",
    };
    const detail = detailKey[texture];
    if (detail) this.add.image(x, y + 22, detail).setDisplaySize(255, 255).setOrigin(0.5, 1).setDepth(y + 1);
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
    const sprite = this.add.image(1380, 285, "verdant-sprite").setDisplaySize(66, 66).setDepth(330);
    this.tweens.add({ targets: sprite, y: 267, angle: { from: 5, to: -5 }, duration: 1900, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    this.add.text(1380, 324, "VERDANT SPRITE", { fontFamily: "Cinzel,serif", fontSize: "8px", color: "#c9ffd0", stroke: "#21172e", strokeThickness: 3 }).setOrigin(0.5).setDepth(340);

    this.practiceWisp = this.add.container(470, 635).setDepth(645);
    this.practiceWispArt = this.add.image(0, 0, "ember-wisp").setDisplaySize(74, 74);
    this.practiceWispLabel = this.add.text(0, 39, "EMBER WISP · 3", {
      fontFamily: "Cinzel,serif", fontSize: "9px", color: "#ffd0a1", stroke: "#21172e", strokeThickness: 3,
    }).setOrigin(0.5);
    const healthTrack = this.add.rectangle(-26, -48, 52, 5, 0x21172e, 0.9).setOrigin(0, 0.5);
    this.practiceWispFill = this.add.rectangle(-24, -48, 48, 3, 0xf39b6b, 1).setOrigin(0, 0.5);
    this.practiceWisp.add([this.practiceWispArt, healthTrack, this.practiceWispFill, this.practiceWispLabel]);
    this.tweens.add({ targets: this.practiceWispArt, y: -17, alpha: { from: 0.82, to: 1 }, duration: 1250, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });

    for (const [x, y] of [[365, 620], [1450, 620], [405, 1000], [1390, 1030]]) {
      const lantern = this.add.image(x, y, "prop-lantern").setDisplaySize(48, 96).setOrigin(0.5, 0.88).setDepth(y);
      this.tweens.add({ targets: lantern, alpha: { from: 0.82, to: 1 }, duration: 1900, yoyo: true, repeat: -1 });
    }
    const obelisk = this.add.image(760, 670, "prop-obelisk").setDisplaySize(92, 92).setDepth(680);
    const signpost = this.add.image(410, 550, "prop-signpost").setDisplaySize(92, 115).setDepth(550);
    const noticeboard = this.add.image(900, 1080, "prop-noticeboard").setDisplaySize(112, 112).setDepth(1080);
    this.add.image(1455, 900, "prop-crystals").setDisplaySize(112, 112).setDepth(910);
    this.obstacles.push(new Phaser.Geom.Rectangle(390, 540, 40, 28), new Phaser.Geom.Rectangle(875, 1072, 50, 20));
    this.tweens.add({ targets: obelisk, alpha: { from: 0.86, to: 1 }, duration: 2200, yoyo: true, repeat: -1 });
  }


  private setCharacter(tradition: string, magicColor: string) {
    const names = ["storm-herald","ember-mage","frostweaver","verdant-warden","voidcaller","sigilbinder"];
    const index = names.indexOf(tradition);
    if (index < 0) return;
    this.currentTradition = tradition;
    this.currentTraditionIndex = index;
    this.magicColor = /^#[0-9a-fA-F]{6}$/.test(magicColor) ? magicColor : "#b98bea";
    if (this.wizardSprite) { this.wizardSprite.anims.stop(); this.wizardSprite.setTexture("wizard-traditions-walk", index * 4).clearTint(); }
    localStorage.setItem("arcane.character.tradition", tradition);
    localStorage.setItem("arcane.character.magicColor", this.magicColor);
  }

  private drawWizard(container: Phaser.GameObjects.Container) {
    const names = ["storm-herald","ember-mage","frostweaver","verdant-warden","voidcaller","sigilbinder"];
    this.currentTradition = localStorage.getItem("arcane.character.tradition") || "storm-herald";
    this.currentTraditionIndex = Math.max(0, names.indexOf(this.currentTradition));
    const savedMagicColor = localStorage.getItem("arcane.character.magicColor") || "#b98bea";
    this.magicColor = /^#[0-9a-fA-F]{6}$/.test(savedMagicColor) ? savedMagicColor : "#b98bea";
    this.wizardSprite = this.add.sprite(0, 0, "wizard-traditions-walk", this.currentTraditionIndex * 4).setDisplaySize(78, 98).setOrigin(0.5, 0.9);
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
    const startY = this.player.y - 12 + this.lastFacing.y * 30;
    const bolt = this.add.image(startX, startY, "arcane-bolt")
      .setTint(Phaser.Display.Color.HexStringToColor(this.magicColor).color)
      .setDisplaySize(42, 42)
      .setDepth(this.player.y + 80)
      .setRotation(Math.atan2(this.lastFacing.y, this.lastFacing.x) + Math.PI / 2);
    const targetX = startX + this.lastFacing.x * 270;
    const targetY = startY + this.lastFacing.y * 270;
    const enemyDx = this.practiceWisp.x - startX;
    const enemyDy = this.practiceWisp.y - startY;
    const alongShot = enemyDx * this.lastFacing.x + enemyDy * this.lastFacing.y;
    const offShot = Math.abs(enemyDx * this.lastFacing.y - enemyDy * this.lastFacing.x);
    const hitsPracticeWisp = this.practiceWispHealth > 0 && alongShot >= 0 && alongShot <= 270 && offShot <= 38;
    const hostileDx = this.hostileWisp.x - startX;
    const hostileDy = this.hostileWisp.y - startY;
    const hostileAlong = hostileDx * this.lastFacing.x + hostileDy * this.lastFacing.y;
    const hostileOff = Math.abs(hostileDx * this.lastFacing.y - hostileDy * this.lastFacing.x);
    const hitsHostileWisp = this.hostileWisp.isAlive && hostileAlong >= 0 && hostileAlong <= 270 && hostileOff <= 42;
    const sentryDx = this.emberSentry.x - startX;
    const sentryDy = this.emberSentry.y - startY;
    const sentryAlong = sentryDx * this.lastFacing.x + sentryDy * this.lastFacing.y;
    const sentryOff = Math.abs(sentryDx * this.lastFacing.y - sentryDy * this.lastFacing.x);
    const hitsSentry = this.emberSentry.isAlive && sentryAlong >= 0 && sentryAlong <= 270 && sentryOff <= 44;
    const hitSentryFirst = hitsSentry && (!hitsHostileWisp || sentryAlong < hostileAlong) && (!hitsPracticeWisp || sentryAlong < alongShot);
    const hitHostileFirst = hitsHostileWisp && (!hitsSentry || hostileAlong < sentryAlong) && (!hitsPracticeWisp || hostileAlong < alongShot);
    const impactX = hitSentryFirst ? this.emberSentry.x : hitHostileFirst ? this.hostileWisp.x : hitsPracticeWisp ? this.practiceWisp.x : targetX;
    const impactY = hitSentryFirst ? this.emberSentry.y : hitHostileFirst ? this.hostileWisp.y : hitsPracticeWisp ? this.practiceWisp.y : targetY;
    this.tweens.add({
      targets: bolt, x: impactX, y: impactY, alpha: 0.25, scale: 0.45,
      duration: 390, ease: "Cubic.easeOut",
      onComplete: () => {
        bolt.destroy();
        const impact = this.add.sprite(impactX, impactY, "arcane-burst", 0)
          .setDisplaySize(112, 112).setDepth(impactY + 90).setAlpha(0.95)
          .setTint(Phaser.Display.Color.HexStringToColor(this.magicColor).color);
        impact.play("arcane-impact-burst");
        impact.once(Phaser.Animations.Events.ANIMATION_COMPLETE, () => impact.destroy());
        if (hitSentryFirst) this.emberSentry.damage();
        else if (hitHostileFirst) this.hostileWisp.damage();
        else if (hitsPracticeWisp) this.damagePracticeWisp();
      },
    });
    this.wizardSprite.anims.stop();
    this.wizardSprite.setTexture("wizard-traditions-cast", this.currentTraditionIndex).setTint(0xffffff);
    this.time.delayedCall(250, () => this.wizardSprite.setTexture("wizard-traditions-walk", this.currentTraditionIndex * 4));
    this.tweens.add({
      targets: this.wizardSprite, alpha: 0.65, duration: 90, yoyo: true,
      onComplete: () => this.wizardSprite.clearTint(),
    });
  }

  private dodge() {
    if (this.time.now < this.nextDodgeAt) return;
    let x = Number(this.keys.A.isDown || this.keys.LEFT.isDown) * -1 + Number(this.keys.D.isDown || this.keys.RIGHT.isDown);
    let y = Number(this.keys.W.isDown || this.keys.UP.isDown) * -1 + Number(this.keys.S.isDown || this.keys.DOWN.isDown);
    x += window.arcaneMove?.x ?? 0;
    y += window.arcaneMove?.y ?? 0;
    const direction = new Phaser.Math.Vector2((x - y) * 0.7071, (x + y) * 0.5);
    if (direction.lengthSq() > 0.001) this.dodgeVector.copy(direction).normalize();
    else this.dodgeVector.copy(this.lastFacing);
    this.lastFacing.copy(this.dodgeVector);
    this.dodgeUntil = this.time.now + 210;
    this.invulnerableUntil = this.time.now + 310;
    this.nextDodgeAt = this.time.now + 1250;
    this.wizardSprite.setTint(0xc8a7ff);
    this.cameras.main.flash(65, 165, 120, 255, false);
    this.updateDodgeHud();
    this.time.delayedCall(230, () => this.wizardSprite.clearTint());
  }

  private updateCastHud() {
    const status = document.querySelector<HTMLElement>("#cast-status");
    const slot = document.querySelector<HTMLButtonElement>("#cast-spell");
    const remaining = Math.max(0, this.nextCastAt - this.time.now);
    if (status) status.textContent = remaining > 0 ? `RECHARGING · ${(remaining / 1000).toFixed(1)}s` : "READY · SPACE / 1";
    slot?.classList.toggle("recharging", remaining > 0);
    slot?.classList.toggle("ready", remaining <= 0);
  }

  private updateDodgeHud() {
    const fill = document.querySelector<HTMLElement>("#dodge-fill");
    const label = document.querySelector<HTMLElement>("#dodge-label");
    const remaining = Math.max(0, this.nextDodgeAt - this.time.now);
    if (fill) fill.style.width = `${(1 - remaining / 1250) * 100}%`;
    if (label) label.textContent = remaining > 0 ? `DODGE · ${(remaining / 1000).toFixed(1)}s` : "DODGE READY";
  }

  private damagePlayer() {
    // A successful hit grants a short recovery window. This prevents two
    // overlapping enemy callbacks from draining multiple hearts at once.
    if (this.playerHealth <= 0 || this.time.now < Math.max(this.invulnerableUntil, this.hitRecoveryUntil)) return;
    this.hitRecoveryUntil = this.time.now + 650;
    this.playerHealth = Math.max(0, this.playerHealth - 1);
    this.updateHealthHud();
    this.updateRecoveryHud();
    this.cameras.main.shake(120, 0.003);
    this.wizardSprite.setTint(0xff8c9d);
    this.time.delayedCall(180, () => this.wizardSprite.clearTint());
    if (this.playerHealth === 0) {
      this.player.setPosition(900, 760);
      this.player.body!.reset(900, 760);
      this.playerArt.setPosition(900, 760);
      this.playerHealth = 5;
      this.time.delayedCall(300, () => this.updateHealthHud());
    }
  }

  private updateHealthHud() {
    const menuValue = document.querySelector("#menu-health");
    const menuFill = document.querySelector<HTMLElement>("#menu-health-fill");
    if (menuValue) menuValue.textContent = `${this.playerHealth} / 5`;
    if (menuFill) menuFill.style.width = `${this.playerHealth * 20}%`;
    const value = document.querySelector("#player-health");
    const fill = document.querySelector<HTMLElement>("#health-fill");
    if (value) value.textContent = `${this.playerHealth} / 5`;
    if (fill) fill.style.width = `${this.playerHealth * 20}%`;
  }

  private updateRecoveryHud() {
    const status = document.querySelector("#health-status");
    const remaining = Math.max(0, this.hitRecoveryUntil - this.time.now);
    if (status) {
      status.textContent = remaining > 0
        ? `HIT RECOVERY · ${(remaining / 1000).toFixed(1)}s`
        : "Sanctuary ward";
      status.classList.toggle("recovering", remaining > 0);
    }
  }

  private damagePracticeWisp() {
    if (this.practiceWispHealth <= 0) return;
    this.practiceWispHealth -= 1;
    this.practiceWispFill.setSize(48 * this.practiceWispHealth / 3, 3);
    this.practiceWispLabel.setText(this.practiceWispHealth > 0 ? `EMBER WISP · ${this.practiceWispHealth}` : "WISP DISPELLED");
    this.tweens.add({ targets: this.practiceWispArt, alpha: 0.3, duration: 65, yoyo: true, repeat: 1 });
    if (this.practiceWispHealth === 0) {
      this.practiceWisp.setAlpha(0.22);
      this.time.delayedCall(3500, () => {
        this.practiceWispHealth = 3;
        this.practiceWispFill.setSize(48, 3);
        this.practiceWispLabel.setText("EMBER WISP · 3");
        this.practiceWisp.setAlpha(1);
      });
    }
  }

  private interact() {
    const nearby = this.nearestNPC();
    if (nearby) { this.showDialogue(nearby.data); return; }
    const location = this.nearestTownLocation();
    if (location) this.showLocationDialogue(location);
  }

  private nearestTownLocation() {
    let best: { name: string; line: string; distance: number; prompt: string } | undefined;
    for (const location of this.townLocations) {
      const distance = Phaser.Math.Distance.Between(this.player.x, this.player.y, location.x, location.y);
      if (distance < 104 && (!best || distance < best.distance)) best = { ...location, distance };
    }
    return best;
  }

  private showLocationDialogue(location: { name: string; line: string }) {
    const name = document.querySelector("#npc-name");
    const line = document.querySelector("#npc-line");
    const panel = document.querySelector("#dialogue");
    if (name) name.textContent = location.name;
    if (line) line.textContent = location.line;
    panel?.classList.remove("hidden");
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
    this.hostileWisp.update(this.player.x, this.player.y, Math.min(this.game.loop.delta, 50) / 1000);
    this.emberSentry.update(this.player.x, this.player.y);
    this.updateDodgeHud();
    this.updateCastHud();
    this.updateRecoveryHud();
    let x = Number(keyboard.A.isDown || keyboard.LEFT.isDown) * -1 + Number(keyboard.D.isDown || keyboard.RIGHT.isDown);
    let y = Number(keyboard.W.isDown || keyboard.UP.isDown) * -1 + Number(keyboard.S.isDown || keyboard.DOWN.isDown);
    x += window.arcaneMove?.x ?? 0;
    y += window.arcaneMove?.y ?? 0;
    const inputStrength = Phaser.Math.Clamp(Math.hypot(x, y), 0, 1);
    const vector = new Phaser.Math.Vector2((x - y) * 0.7071, (x + y) * 0.5);
    // Normalize direction after projection, then restore analog stick magnitude.
    // Keyboard input remains full speed; a gently tilted stick stays gently paced.
    if (vector.lengthSq() > 0.001) vector.normalize().scale(inputStrength);
    const isDodging = this.time.now < this.dodgeUntil;
    const delta = Math.min(this.game.loop.delta, 100) / 1000;
    const speed = isDodging ? 470 : 190;
    const desiredVelocity = isDodging
      ? this.dodgeVector.clone().scale(speed)
      : vector.clone().scale(speed);
    // Exponential acceleration/deceleration is frame-rate independent and
    // makes keyboard and touch movement feel less abrupt without adding drift.
    const response = 1 - Math.exp(-delta * (vector.lengthSq() > 0.001 ? 16 : 20));
    if (isDodging) this.movementVelocity.copy(desiredVelocity);
    else this.movementVelocity.lerp(desiredVelocity, response);
    const radius = 9;
    const minX = 70 + radius, maxX = WORLD.width - 70 - radius;
    const minY = 70 + radius, maxY = WORLD.height - 70 - radius;
    const collidesAt = (x: number, y: number) => {
      const circle = new Phaser.Geom.Circle(x, y, radius);
      return this.obstacles.some(rect => Phaser.Geom.Intersects.CircleToRectangle(circle, rect));
    };

    // Resolve each axis independently. This gives the player a reliable slide along
    // building footprints instead of freezing on a diagonal corner.
    const startX = this.player.x;
    const startY = this.player.y;
    let resolvedX = startX;
    let resolvedY = startY;
    // Preserve elapsed time during slow frames, but resolve the path in <= 1/60s
    // slices so the character cannot tunnel through a building footprint.
    const collisionSteps = Math.max(1, Math.ceil(delta / (1 / 60)));
    const stepDelta = delta / collisionSteps;
    for (let step = 0; step < collisionSteps; step++) {
      const wantedX = Phaser.Math.Clamp(resolvedX + this.movementVelocity.x * stepDelta, minX, maxX);
      const wantedY = Phaser.Math.Clamp(resolvedY + this.movementVelocity.y * stepDelta, minY, maxY);
      if (!collidesAt(wantedX, resolvedY)) resolvedX = wantedX;
      else this.movementVelocity.x = 0;
      if (!collidesAt(resolvedX, wantedY)) resolvedY = wantedY;
      else this.movementVelocity.y = 0;
    }

    // This is a kinematic character controller: physics supplies the body, while
    // movement and collision resolution stay deterministic across frame rates.
    this.player.setVelocity(0, 0);
    this.player.setPosition(resolvedX, resolvedY);
    this.player.body!.reset(resolvedX, resolvedY);
    this.playerArt.setPosition(resolvedX, resolvedY);
    const movedX = resolvedX - startX;
    const movedY = resolvedY - startY;
    const isWalking = Math.hypot(movedX, movedY) > 0.1 && this.wizardSprite.texture.key === "wizard-traditions-walk";
    if (isWalking) this.lastFacing.set(movedX, movedY).normalize();
    if (this.wizardSprite.texture.key === "wizard-traditions-walk") {
      if (isWalking) {
        if (this.wizardSprite.anims.currentAnim?.key !== `wizard-${this.currentTradition}-walk-cycle`) this.wizardSprite.play(`wizard-${this.currentTradition}-walk-cycle`);
      } else {
        this.wizardSprite.anims.stop();
        this.wizardSprite.setFrame(this.currentTraditionIndex * 4);
      }
    }
    if (Math.abs(movedX) > 0.01 && this.wizardSprite.texture.key === "wizard-traditions-walk") this.wizardSprite.setFlipX(movedX < 0);
    this.wizardSprite.setRotation(isWalking ? Math.sin(this.time.now / 75) * 0.012 : Math.sin(this.time.now / 520) * 0.008);
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
    const location = nearby ? undefined : this.nearestTownLocation();
    this.prompt.setVisible(Boolean(nearby || location));
    if (nearby || location) {
      this.prompt.setText(nearby ? "E  SPEAK" : location!.prompt);
      this.prompt.setPosition(this.scale.width / 2, this.scale.height - 105);
    }
    if (Phaser.Input.Keyboard.JustDown(keyboard.E) || Phaser.Input.Keyboard.JustDown(keyboard.ENTER)) this.interact();
    if (Phaser.Input.Keyboard.JustDown(keyboard.SPACE) || Phaser.Input.Keyboard.JustDown(keyboard.ONE)) this.castSpell();
    if (Phaser.Input.Keyboard.JustDown(keyboard.SHIFT)) this.dodge();
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

const intro = document.querySelector<HTMLElement>("#realm-intro");
const enterRealm = document.querySelector<HTMLButtonElement>("#enter-realm");
const loadingFill = document.querySelector<HTMLElement>("#loading-fill");
const loadingPercent = document.querySelector<HTMLElement>("#loading-percent");
const loadingLabel = document.querySelector<HTMLElement>("#loading-label");
const loadingNote = document.querySelector<HTMLElement>("#loading-note");
window.addEventListener("arcane:loading", event => {
  const progress = Phaser.Math.Clamp((event as CustomEvent<number>).detail, 0, 1);
  if (loadingFill) loadingFill.style.width = `${Math.round(progress * 100)}%`;
  if (loadingPercent) loadingPercent.textContent = `${Math.round(progress * 100)}%`;
  if (loadingLabel) loadingLabel.textContent = progress < 1 ? "AWAKENING THE SANCTUARY" : "SETTING THE FINAL SIGILS";
});
game.events.once("arcane:ready", () => {
  if (loadingFill) loadingFill.style.width = "100%";
  if (loadingPercent) loadingPercent.textContent = "100%";
  if (loadingLabel) loadingLabel.textContent = "THE PORTAL IS OPEN";
  if (loadingNote) loadingNote.textContent = "Your path is ready. The Sanctuary awaits.";
  if (enterRealm) enterRealm.disabled = false;
});
const pauseButton = document.querySelector<HTMLButtonElement>("#pause-game");
const pauseOverlay = document.querySelector<HTMLElement>("#pause-overlay");
const setPaused = (paused: boolean) => {
  if (!pauseOverlay) return;
  pauseOverlay.classList.toggle("hidden", !paused);
  pauseOverlay.setAttribute("aria-hidden", String(!paused));
  pauseButton?.setAttribute("aria-expanded", String(paused));
  if (paused) game.scene.pause("Sanctuary"); else game.scene.resume("Sanctuary");
};
pauseButton?.addEventListener("click", () => setPaused(pauseOverlay?.classList.contains("hidden") ?? true));
document.querySelector("#resume-game")?.addEventListener("click", () => setPaused(false));
const menuTabs = document.querySelectorAll<HTMLButtonElement>("[data-menu-tab]");
const menuPages = document.querySelectorAll<HTMLElement>("[data-menu-page]");
const setMenuPage = (page: string) => {
  menuTabs.forEach(tab => {
    const active = tab.dataset.menuTab === page;
    tab.classList.toggle("active", active);
    tab.setAttribute("aria-selected", String(active));
  });
  menuPages.forEach(panel => panel.classList.toggle("hidden", panel.dataset.menuPage !== page));
};
menuTabs.forEach(tab => tab.addEventListener("click", () => setMenuPage(tab.dataset.menuTab || "character")));
document.querySelector("#resume-journey")?.addEventListener("click", () => setPaused(false));
window.addEventListener("keydown", event => {
  if (event.key !== "Escape" || !intro?.classList.contains("dismissed")) return;
  const dialogue = document.querySelector<HTMLElement>("#dialogue");
  if (dialogue && !dialogue.classList.contains("hidden")) { dialogue.classList.add("hidden"); return; }
  setPaused(pauseOverlay?.classList.contains("hidden") ?? true);
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
document.querySelector("#dodge")?.addEventListener("click", () => window.arcaneDodge?.());
document.querySelector("#close-dialogue")?.addEventListener("click", () => document.querySelector("#dialogue")?.classList.add("hidden"));
window.addEventListener("beforeunload", () => game.destroy(true));

const creator = document.querySelector<HTMLElement>("#creator-screen");
const characterNameInput = document.querySelector<HTMLInputElement>("#character-name");
const magicColorInput = document.querySelector<HTMLInputElement>("#magic-color");
let selectedTradition = localStorage.getItem("arcane.character.tradition") || "storm-herald";
let selectedGender = localStorage.getItem("arcane.character.gender") || "male";
let selectedDiscipline = localStorage.getItem("arcane.character.discipline") || "arcanist";
const savedCharacterName = localStorage.getItem("arcane.character.name") || "Wayfarer";
if (characterNameInput) characterNameInput.value = savedCharacterName;
if (magicColorInput) magicColorInput.value = localStorage.getItem("arcane.character.magicColor") || "#b98bea";
const setChoice = (selector: string, key: string, value: string) => {
  document.querySelectorAll<HTMLButtonElement>(selector).forEach(button => {
    const active = button.dataset[key] === value;
    button.classList.toggle("selected", active);
    button.setAttribute("aria-pressed", String(active));
  });
};
setChoice("[data-tradition]", "tradition", selectedTradition);
setChoice("[data-gender]", "gender", selectedGender);
setChoice("[data-discipline]", "discipline", selectedDiscipline);
document.querySelectorAll<HTMLButtonElement>("[data-tradition]").forEach(button => button.addEventListener("click", () => { selectedTradition = button.dataset.tradition || "storm-herald"; setChoice("[data-tradition]", "tradition", selectedTradition); }));
document.querySelectorAll<HTMLButtonElement>("[data-gender]").forEach(button => button.addEventListener("click", () => { selectedGender = button.dataset.gender || "male"; setChoice("[data-gender]", "gender", selectedGender); }));
document.querySelectorAll<HTMLButtonElement>("[data-discipline]").forEach(button => button.addEventListener("click", () => { selectedDiscipline = button.dataset.discipline || "arcanist"; setChoice("[data-discipline]", "discipline", selectedDiscipline); }));
enterRealm?.addEventListener("click", () => {
  if (enterRealm.disabled || !creator) return;
  creator.classList.remove("hidden");
  characterNameInput?.focus();
});
document.querySelector("#begin-journey")?.addEventListener("click", () => {
  const name = (characterNameInput?.value || "").trim().slice(0,18);
  if (!name) { characterNameInput?.focus(); if (loadingNote) loadingNote.textContent = "Choose a name before entering the realm."; return; }
  const magicColor = magicColorInput?.value || "#b98bea";
  localStorage.setItem("arcane.character.name", name);
  localStorage.setItem("arcane.character.gender", selectedGender);
  localStorage.setItem("arcane.character.tradition", selectedTradition);
  localStorage.setItem("arcane.character.discipline", selectedDiscipline);
  localStorage.setItem("arcane.character.magicColor", magicColor);
  window.arcaneSetCharacter?.(selectedTradition, magicColor);
  const title = selectedTradition.split("-").map(part => part[0].toUpperCase()+part.slice(1)).join(" ");
  document.querySelector("#profile-name")!.textContent = name;
  document.querySelector("#menu-character-name")!.textContent = name;
  document.querySelector("#menu-tradition")!.textContent = title;
  document.querySelector("#profile-class")!.textContent = `${selectedDiscipline[0].toUpperCase()+selectedDiscipline.slice(1)} · Level 1`;
  creator?.classList.add("hidden");
  intro?.classList.add("dismissed");
  intro?.setAttribute("aria-hidden", "true");
});
