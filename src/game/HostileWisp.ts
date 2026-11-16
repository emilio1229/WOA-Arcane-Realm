import Phaser from "phaser";

/** Local prototype enemy. Valuable rewards remain disabled until a trusted backend exists. */
export class HostileWisp {
  private readonly art: Phaser.GameObjects.Image;
  private readonly label: Phaser.GameObjects.Text;
  private readonly track: Phaser.GameObjects.Rectangle;
  private readonly fill: Phaser.GameObjects.Rectangle;
  private readonly warning: Phaser.GameObjects.Arc;
  private health = 4;
  private nextAttackAt = 0;
  private windupUntil = 0;
  private respawnAt = 0;

  constructor(private readonly scene: Phaser.Scene, x: number, y: number, private readonly onPlayerHit: () => void) {
    this.art = scene.add.image(x, y, "frost-wisp").setDisplaySize(78, 78).setDepth(y + 5);
    this.label = scene.add.text(x, y + 43, "FROST WISP · 4", {
      fontFamily: "Cinzel,serif", fontSize: "9px", color: "#c8f5ff", stroke: "#21172e", strokeThickness: 3,
    }).setOrigin(0.5).setDepth(y + 12);
    this.track = scene.add.rectangle(x - 25, y - 48, 50, 5, 0x21172e, 0.9).setOrigin(0, 0.5).setDepth(y + 12);
    this.fill = scene.add.rectangle(x - 23, y - 48, 46, 3, 0x8bd9ee, 1).setOrigin(0, 0.5).setDepth(y + 13);
    this.warning = scene.add.circle(x, y, 46, 0x8bd9ee, 0.08).setStrokeStyle(2, 0x9be8ff, 0.9).setVisible(false).setDepth(y + 2);
    scene.tweens.add({ targets: this.art, y: y - 14, alpha: { from: 0.82, to: 1 }, duration: 1450, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
  }

  get x() { return this.art.x; }
  get y() { return this.art.y; }
  get isAlive() { return this.health > 0; }
  get currentHealth() { return this.health; }

  update(playerX: number, playerY: number, delta: number) {
    if (!this.isAlive) {
      if (this.respawnAt && this.scene.time.now >= this.respawnAt) this.reset();
      return;
    }
    const dx = playerX - this.art.x;
    const dy = playerY - this.art.y;
    const distance = Math.hypot(dx, dy);
    if (distance < 430 && distance > 54) {
      const step = Math.min(distance - 54, 68 * delta);
      this.art.x += dx / distance * step;
      this.art.y += dy / distance * step;
    } else if (distance <= 54) {
      if (!this.windupUntil && this.scene.time.now >= this.nextAttackAt) {
        this.windupUntil = this.scene.time.now + 700;
        this.warning.setPosition(this.art.x, this.art.y + 12).setScale(0.55).setAlpha(0.9).setVisible(true);
        this.scene.tweens.add({ targets: this.warning, scale: 1.15, alpha: 0.18, duration: 700, ease: "Cubic.easeOut" });
      } else if (this.windupUntil && this.scene.time.now >= this.windupUntil) {
        this.windupUntil = 0;
        this.nextAttackAt = this.scene.time.now + 1600;
        this.warning.setVisible(false);
        this.onPlayerHit();
      }
    } else if (distance > 78 && this.windupUntil) {
      this.windupUntil = 0;
      this.warning.setVisible(false);
      this.scene.tweens.killTweensOf(this.warning);
    }
    this.warning.setPosition(this.art.x, this.art.y + 12);
    this.warning.setDepth(this.art.y + 2);
    this.label.setPosition(this.art.x, this.art.y + 43);
    this.track.setPosition(this.art.x - 25, this.art.y - 48);
    this.fill.setPosition(this.art.x - 23, this.art.y - 48);
    this.art.setDepth(this.art.y + 5);
    this.label.setDepth(this.art.y + 12);
    this.track.setDepth(this.art.y + 12);
    this.fill.setDepth(this.art.y + 13);
  }

  damage() {
    if (!this.isAlive) return false;
    this.health -= 1;
    this.fill.setSize(46 * this.health / 4, 3);
    this.label.setText(this.health ? `FROST WISP · ${this.health}` : "WISP DISPELLED");
    this.scene.tweens.add({ targets: this.art, alpha: 0.35, duration: 70, yoyo: true, repeat: 1 });
    if (!this.health) {
      this.respawnAt = this.scene.time.now + 5000;
      this.art.setAlpha(0.18);
      this.label.setAlpha(0.45);
      this.track.setAlpha(0.25);
      this.fill.setAlpha(0.25);
      this.warning.setVisible(false);
      this.scene.tweens.killTweensOf(this.warning);
    }
    return true;
  }

  private reset() {
    this.health = 4;
    this.respawnAt = 0;
    this.fill.setSize(46, 3).setAlpha(1);
    this.label.setText("FROST WISP · 4").setAlpha(1);
    this.track.setAlpha(1);
    this.windupUntil = 0;
    this.warning.setVisible(false).setPosition(1450, 652).setScale(1);
    this.art.setAlpha(1).setPosition(1450, 640);
  }
}
