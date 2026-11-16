import Phaser from "phaser";

/** Ranged prototype enemy: holds its ground and launches a slow, visible fire orb. */
export class EmberSentry {
  private readonly art: Phaser.GameObjects.Image;
  private readonly label: Phaser.GameObjects.Text;
  private readonly track: Phaser.GameObjects.Rectangle;
  private readonly fill: Phaser.GameObjects.Rectangle;
  private readonly targetMark: Phaser.GameObjects.Arc;
  private health = 5;
  private nextShotAt = 0;
  private windupUntil = 0;
  private shotTarget = new Phaser.Math.Vector2();

  constructor(
    private readonly scene: Phaser.Scene,
    x: number,
    y: number,
    private readonly onPlayerHit: () => void,
    private readonly isPlayerDodging: () => boolean,
  ) {
    this.art = scene.add.image(x, y, "ember-wisp").setDisplaySize(82, 82).setDepth(y + 5);
    this.label = scene.add.text(x, y + 45, "EMBER SENTRY · 5", {
      fontFamily: "Cinzel,serif", fontSize: "9px", color: "#ffd0a1",
      stroke: "#21172e", strokeThickness: 3,
    }).setOrigin(0.5).setDepth(y + 12);
    this.track = scene.add.rectangle(x - 27, y - 49, 54, 5, 0x21172e, 0.9).setOrigin(0, 0.5).setDepth(y + 12);
    this.fill = scene.add.rectangle(x - 25, y - 49, 50, 3, 0xf39b6b, 1).setOrigin(0, 0.5).setDepth(y + 13);
    this.targetMark = scene.add.circle(x, y, 27, 0xf59b57, 0.12)
      .setStrokeStyle(2, 0xffb36c, 0.9).setVisible(false).setDepth(5000);
    scene.tweens.add({
      targets: this.art, y: y - 10, alpha: { from: 0.84, to: 1 },
      duration: 1250, yoyo: true, repeat: -1, ease: "Sine.easeInOut",
    });
  }

  get x() { return this.art.x; }
  get y() { return this.art.y; }
  get isAlive() { return this.health > 0; }
  get currentHealth() { return this.health; }

  update(playerX: number, playerY: number) {
    if (!this.isAlive) return;
    const distance = Phaser.Math.Distance.Between(this.art.x, this.art.y, playerX, playerY);
    if (!this.windupUntil && distance < 570 && this.scene.time.now >= this.nextShotAt) {
      this.shotTarget.set(playerX, playerY);
      this.windupUntil = this.scene.time.now + 620;
      this.targetMark.setPosition(this.shotTarget.x, this.shotTarget.y).setScale(0.55).setAlpha(0.9).setVisible(true);
      this.scene.tweens.add({ targets: this.targetMark, scale: 1.25, alpha: 0.18, duration: 620, ease: "Cubic.easeOut" });
    } else if (this.windupUntil && this.scene.time.now >= this.windupUntil) {
      this.windupUntil = 0;
      this.nextShotAt = this.scene.time.now + 2350;
      this.targetMark.setVisible(false);
      this.launchFireOrb();
    }
  }

  private launchFireOrb() {
    const startX = this.art.x;
    const startY = this.art.y - 8;
    const orb = this.scene.add.circle(startX, startY, 12, 0xffa45c, 0.95)
      .setStrokeStyle(3, 0xffe1a8, 0.95).setDepth(5200);
    this.scene.add.circle(startX, startY, 22, 0xff8a45, 0.12).setDepth(5199);
    const dx = this.shotTarget.x - startX;
    const dy = this.shotTarget.y - startY;
    const duration = Phaser.Math.Clamp(Math.hypot(dx, dy) / 0.48, 420, 1050);
    this.scene.tweens.add({
      targets: orb, x: this.shotTarget.x, y: this.shotTarget.y,
      scale: 0.8, duration, ease: "Linear",
      onComplete: () => {
        const impact = this.scene.add.circle(orb.x, orb.y, 30, 0xff9a4e, 0.3).setDepth(5201);
        this.scene.tweens.add({ targets: impact, scale: 2.2, alpha: 0, duration: 260, onComplete: () => impact.destroy() });
        const closeEnough = Phaser.Math.Distance.Between(this.shotTarget.x, this.shotTarget.y, orb.x, orb.y) < 48;
        if (closeEnough && !this.isPlayerDodging()) this.onPlayerHit();
        orb.destroy();
      },
    });
  }

  damage() {
    if (!this.isAlive) return false;
    this.health -= 1;
    this.fill.setSize(50 * this.health / 5, 3);
    this.label.setText(this.health ? `EMBER SENTRY · ${this.health}` : "SENTRY DISPELLED");
    this.scene.tweens.add({ targets: this.art, alpha: 0.3, duration: 70, yoyo: true, repeat: 1 });
    if (!this.health) {
      this.targetMark.setVisible(false);
      this.scene.tweens.killTweensOf(this.targetMark);
      this.art.setAlpha(0.18);
      this.label.setAlpha(0.45);
      this.track.setAlpha(0.25);
      this.fill.setAlpha(0.25);
    }
    return true;
  }
}
