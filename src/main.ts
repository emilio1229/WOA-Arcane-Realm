import Phaser from "phaser";
import "./style.css";

declare global {
  interface Window {
    arcaneMove?: { x: number; y: number };
    arcaneInteract?: () => void;
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
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private obstacles: Phaser.Geom.Rectangle[] = [];
  private npcs: Array<{ data: NPC; art: Phaser.GameObjects.Container }> = [];
  private prompt!: Phaser.GameObjects.Text;
  private interactHandler = () => this.interact();

  constructor() { super("Sanctuary"); }

  create() {
    this.cameras.main.setBackgroundColor("#182335");
    this.drawWorld();
    this.createBuildings();
    this.createNPCs();

    this.player = this.physics.add.image(900, 760, "__WHITE");
    this.player.setDisplaySize(18, 18).setTint(0xffffff).setAlpha(0);
    this.player.body!.setCircle(9, 0, 0);
    this.player.setCollideWorldBounds(true);
    this.playerArt = this.add.container(this.player.x, this.player.y).setDepth(900);
    this.drawWizard(this.playerArt);
    this.cameras.main.setBounds(0, 0, WORLD.width, WORLD.height);
    this.cameras.main.startFollow(this.player, true, 0.08, 0.08);
    this.cameras.main.setZoom(Math.min(1, this.scale.width / 1100));
    this.physics.world.setBounds(70, 70, WORLD.width - 140, WORLD.height - 140);

    this.keys = this.input.keyboard!.addKeys("W,A,S,D,UP,DOWN,LEFT,RIGHT,E,ENTER") as Record<string, Phaser.Input.Keyboard.Key>;
    this.prompt = this.add.text(0, 0, "E  SPEAK", {
      fontFamily: "Manrope, sans-serif", fontSize: "11px", color: "#fff4d9",
      backgroundColor: "#2c1e40", padding: { x: 9, y: 6 }, stroke: "#d5a5ef", strokeThickness: 1,
    }).setOrigin(0.5, 1).setDepth(3000).setVisible(false).setScrollFactor(0);

    this.input.on("pointerdown", (pointer: Phaser.Input.Pointer) => {
      if (pointer.wasTouch && pointer.x > this.scale.width * 0.58 && pointer.y > this.scale.height * 0.55) this.interact();
    });
    window.arcaneInteract = this.interactHandler;
    this.events.once("shutdown", () => { window.arcaneInteract = undefined; });
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
    const g = this.add.graphics().setDepth(100);
    g.fillStyle(0x20182e); g.fillEllipse(x, y + 65, 180, 56);
    g.lineStyle(18, 0x5e3c80, 1); g.strokeEllipse(x, y, 116, 166);
    g.lineStyle(7, 0xd3a0fa, 0.9); g.strokeEllipse(x, y, 96, 148);
    g.fillStyle(0x8e62ba, 0.26); g.fillEllipse(x, y, 90, 142);
    g.lineStyle(2, 0xf1d5ff, 0.8); g.strokeEllipse(x, y, 90, 142);
    for (let i = 0; i < 8; i++) {
      const a = i * Math.PI / 4;
      g.fillStyle(0xe7c27e); g.fillCircle(x + Math.cos(a) * 66, y + Math.sin(a) * 85, 4);
    }
    this.tweens.add({ targets: g, alpha: { from: 0.78, to: 1 }, duration: 1700, yoyo: true, repeat: -1 });
  }

  private createBuildings() {
    this.building(650, 440, "GRAND LIBRARY", 0x45365d, 0x9e80c5);
    this.building(1160, 450, "FAMILIAR SANCTUARY", 0x34574d, 0x7eb99c);
    this.building(560, 760, "SPELL ACADEMY", 0x4c365e, 0xb18bd4);
    this.building(1240, 820, "MERCHANT", 0x655039, 0xe0b978);
    this.building(900, 1000, "ADVENTURER'S INN", 0x59413d, 0xc58a78);
  }

  private building(x: number, y: number, label: string, wall: number, roof: number) {
    const g = this.add.graphics().setDepth(y);
    g.fillStyle(0x151522, 0.42); g.fillEllipse(x, y + 34, 240, 100);
    g.fillStyle(wall); g.fillRect(x - 76, y - 88, 152, 112);
    g.fillStyle(Phaser.Display.Color.IntegerToColor(wall).darken(18).color); g.fillRect(x - 76, y - 88, 18, 112);
    g.fillStyle(roof); g.fillTriangle(x - 100, y - 88, x, y - 160, x + 100, y - 88);
    g.fillStyle(0xf2d39b, 0.95); g.fillRect(x - 9, y - 52, 18, 44);
    g.fillStyle(0xffd995, 0.75); g.fillRoundedRect(x - 47, y - 61, 18, 28, 5);
    g.fillStyle(0xffd995, 0.75); g.fillRoundedRect(x + 29, y - 61, 18, 28, 5);
    this.add.text(x, y + 52, label, { fontFamily: "Cinzel, serif", fontSize: "10px", color: "#f3e3ff", stroke: "#1a1424", strokeThickness: 3, letterSpacing: 1 }).setOrigin(0.5).setDepth(y + 5);
    this.obstacles.push(new Phaser.Geom.Rectangle(x - 75, y - 85, 150, 105));
  }

  private createNPCs() {
    for (const npc of NPCS) {
      const art = this.add.container(npc.x, npc.y).setDepth(npc.y + 10);
      const shadow = this.add.ellipse(0, 20, 34, 12, 0x080b12, 0.42);
      const robe = this.add.triangle(0, 3, -15, 20, 15, 20, 0, -17, npc.color);
      const head = this.add.circle(0, -17, 9, 0xe7c5a9);
      const hood = this.add.arc(0, -18, 12, 180, 360, false, 0x49345f).setClosePath(true);
      const glow = this.add.circle(0, -4, 23, npc.color, 0.08);
      art.add([glow, shadow, robe, head, hood]);
      this.add.text(npc.x, npc.y + 35, npc.name, { fontFamily: "Cinzel,serif", fontSize: "10px", color: "#fff0d9", stroke: "#21172e", strokeThickness: 3 }).setOrigin(0.5).setDepth(npc.y + 15);
      this.npcs.push({ data: npc, art });
      this.tweens.add({ targets: art, y: npc.y - 3, duration: 1400 + Math.random() * 500, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
  }

  private drawWizard(container: Phaser.GameObjects.Container) {
    const shadow = this.add.ellipse(0, 17, 31, 11, 0x080b12, 0.5);
    const robe = this.add.triangle(0, 2, -16, 20, 16, 20, 0, -17, 0x8e62bd);
    const trim = this.add.triangle(0, 5, -8, 16, 8, 16, 0, -12, 0xd5a5f3);
    const head = this.add.circle(0, -18, 9, 0xe8c9ad);
    const hat = this.add.triangle(0, -30, -12, -13, 12, -13, 0, -34, 0x30203f);
    const star = this.add.star(0, -33, 4, 2, 5, 0xf1d28e);
    container.add([shadow, robe, trim, head, hat, star]);
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
    const nextX = this.player.x + vector.x * speed * (1 / 60);
    const nextY = this.player.y + vector.y * speed * (1 / 60);
    const candidate = new Phaser.Geom.Circle(nextX, nextY, 9);
    const blocked = this.obstacles.some(rect => Phaser.Geom.Intersects.CircleToRectangle(candidate, rect));
    if (!blocked) this.player.setVelocity(vector.x * speed, vector.y * speed);
    else this.player.setVelocity(0, 0);
    if (blocked && !this.obstacles.some(rect => Phaser.Geom.Intersects.CircleToRectangle(new Phaser.Geom.Circle(this.player.x + vector.x * 3, this.player.y, 9), rect))) this.player.setVelocityX(vector.x * speed);
    if (blocked && !this.obstacles.some(rect => Phaser.Geom.Intersects.CircleToRectangle(new Phaser.Geom.Circle(this.player.x, this.player.y + vector.y * 3, 9), rect))) this.player.setVelocityY(vector.y * speed);
    this.playerArt.setPosition(this.player.x, this.player.y);
    this.playerArt.setDepth(this.player.y + 20);
    this.npcs.forEach(n => n.art.setDepth(n.data.y + 10));
    const nearby = this.nearestNPC();
    this.prompt.setVisible(Boolean(nearby));
    if (nearby) {
      this.prompt.setPosition(this.scale.width / 2, this.scale.height - 105);
    }
    if (Phaser.Input.Keyboard.JustDown(keyboard.E) || Phaser.Input.Keyboard.JustDown(keyboard.ENTER)) this.interact();
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
document.querySelector("#close-dialogue")?.addEventListener("click", () => document.querySelector("#dialogue")?.classList.add("hidden"));
window.addEventListener("beforeunload", () => game.destroy(true));
