/** Typed runtime loader for WOA Arcane Realm concept art. */
interface ZipEntry { dir: boolean; name: string; async(type: "blob"): Promise<Blob>; }
interface ZipArchive { files: Record<string, ZipEntry>; }
interface JSZipConstructor { loadAsync(data: ArrayBuffer): Promise<ZipArchive>; }
interface CropRect { x: number; y: number; w: number; h: number; }
interface WoaArtWindow extends Window {
  JSZip?: JSZipConstructor;
  woaArtReady?: Promise<boolean>;
  woaArtPortraits?: { masculine: string | null; feminine: string | null };
  woaRuntimeSprites?: Record<string, string | null>;
  woaConceptArt?: Record<string, string>;
}
const artWindow = window as WoaArtWindow;
const archiveUrl = "https://raw.githubusercontent.com/emilio1229/WOA-Arcane-Realm/main/assets/art-source/woa_arcane_realm_asset_starter.zip";
const categories: ReadonlyArray<readonly [string, string]> = [
  ["characters","01_player_characters_and_classes.png"],["animations","02_player_animations.png"],
  ["directions","03_directional_facing_and_actions.png"],["portraits","04_portraits_and_class_outfits.png"],
  ["spells","05_spell_and_combat_effects.png"],["mathias","06_mathias_supporting_character.png"],
  ["enemies","07_enemies.png"],["familiars","08_familiars_and_pets.png"],
  ["equipment","09_equipment_and_items.png"],["world","10_world_environment.png"],
  ["ui","11_ui_elements_and_palette.png"],["branding","12_woa_branding.png"]
];
function findEntry(zip: ZipArchive, filename: string): ZipEntry | undefined {
  return Object.values(zip.files).find(entry => !entry.dir && entry.name.endsWith(filename));
}
async function imageFromEntry(entry: ZipEntry | undefined): Promise<HTMLImageElement | null> {
  if (!entry) return null;
  const blob = await entry.async("blob");
  const url = URL.createObjectURL(blob);
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("Could not decode concept image: " + entry.name));
    image.src = url;
  });
}
function cropImage(image: HTMLImageElement | null, rect: CropRect): string | null {
  if (!image) return null;
  const canvas = document.createElement("canvas");
  canvas.width = rect.w; canvas.height = rect.h;
  const context = canvas.getContext("2d");
  if (!context) return null;
  context.drawImage(image, rect.x, rect.y, rect.w, rect.h, 0, 0, rect.w, rect.h);
  return canvas.toDataURL("image/png");
}
function makeTransparentSprite(image: HTMLImageElement | null, rect: CropRect): string | null {
  if (!image) return null;
  const canvas = document.createElement("canvas");
  canvas.width = rect.w; canvas.height = rect.h;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) return null;
  context.drawImage(image, rect.x, rect.y, rect.w, rect.h, 0, 0, rect.w, rect.h);
  const frame = context.getImageData(0, 0, rect.w, rect.h), pixels = frame.data;
  // Remove only background pixels connected to the crop's border. The earlier
  // global purple color-key erased purple highlights from the actual characters.
  const width = rect.w, height = rect.h, visited = new Uint8Array(width * height);
  const queue = new Int32Array(width * height);
  let head = 0, tail = 0;
  const isBackground = (index: number): boolean => {
    const p = index * 4, red = pixels[p], green = pixels[p + 1], blue = pixels[p + 2];
    // Purple gradient used on the concept sheets; keep the test broad enough
    // for edge pixels, but flood-fill connectivity protects the artwork.
    return blue > 55 && red > 35 && blue > green * 1.25 && red > green * 1.15;
  };
  const enqueue = (x: number, y: number): void => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const index = y * width + x;
    if (visited[index] || !isBackground(index)) return;
    visited[index] = 1; queue[tail++] = index;
  };
  for (let x = 0; x < width; x++) { enqueue(x, 0); enqueue(x, height - 1); }
  for (let y = 0; y < height; y++) { enqueue(0, y); enqueue(width - 1, y); }
  while (head < tail) {
    const index = queue[head++], x = index % width, y = Math.floor(index / width);
    pixels[index * 4 + 3] = 0;
    enqueue(x - 1, y); enqueue(x + 1, y); enqueue(x, y - 1); enqueue(x, y + 1);
  }
  context.putImageData(frame, 0, 0);
  return canvas.toDataURL("image/png");
}
async function loadConceptArchive(): Promise<boolean> {
  try {
    const zipLibrary = artWindow.JSZip;
    if (!zipLibrary) throw new Error("ZIP reader unavailable");
    const response = await fetch(archiveUrl, { cache: "force-cache" });
    if (!response.ok) throw new Error("Art ZIP returned " + response.status);
    const zip = await zipLibrary.loadAsync(await response.arrayBuffer());
    const portraits = await imageFromEntry(findEntry(zip, "04_portraits_and_class_outfits.png"));
    if (portraits) artWindow.woaArtPortraits = {
      masculine: cropImage(portraits, {x:18,y:46,w:136,h:108}),
      feminine: cropImage(portraits, {x:176,y:46,w:135,h:108})
    };
    const familiar = await imageFromEntry(findEntry(zip, "08_familiars_and_pets.png"));
    const enemy = await imageFromEntry(findEntry(zip, "07_enemies.png"));
    const mathias = await imageFromEntry(findEntry(zip, "06_mathias_supporting_character.png"));
    const spell = await imageFromEntry(findEntry(zip, "05_spell_and_combat_effects.png"));
    const sprites: Record<string, string | null> = {};
    if (familiar) {
      sprites.familiarRaven = makeTransparentSprite(familiar,{x:18,y:55,w:45,h:38});
      sprites.familiarWolf = makeTransparentSprite(familiar,{x:10,y:108,w:56,h:39});
      sprites.familiarDragon = makeTransparentSprite(familiar,{x:10,y:164,w:48,h:43});
      sprites.familiarElemental = makeTransparentSprite(familiar,{x:7,y:219,w:49,h:48});
    }
    if (enemy) {
      // Tight, individually keyed enemy silhouettes from each labeled enemy row.
      sprites.shadowWraith = makeTransparentSprite(enemy,{x:3,y:42,w:48,h:49});
      sprites.darkAnimus = makeTransparentSprite(enemy,{x:8,y:112,w:52,h:49});
      sprites.corruptedBeast = makeTransparentSprite(enemy,{x:3,y:176,w:55,h:49});
      sprites.arcaneGolem = makeTransparentSprite(enemy,{x:4,y:238,w:58,h:58});
    }
    if (mathias) {
      // The concept panel labels seven distinct poses across its top row.
      // These remain single-frame action poses, not a fabricated walk cycle.
      sprites.mathias = makeTransparentSprite(mathias,{x:18,y:43,w:37,h:52});
      sprites.mathiasWalk = makeTransparentSprite(mathias,{x:58,y:43,w:34,h:52});
      sprites.mathiasRun = makeTransparentSprite(mathias,{x:100,y:43,w:34,h:52});
      sprites.mathiasAttack = makeTransparentSprite(mathias,{x:143,y:43,w:34,h:52});
      sprites.mathiasCast = makeTransparentSprite(mathias,{x:186,y:43,w:34,h:52});
      sprites.mathiasHurt = makeTransparentSprite(mathias,{x:229,y:43,w:34,h:52});
      sprites.mathiasDeath = makeTransparentSprite(mathias,{x:273,y:43,w:38,h:52});
    }
    if (spell) sprites.arcaneBlast = makeTransparentSprite(spell,{x:109,y:48,w:84,h:43});
    artWindow.woaRuntimeSprites = {...(artWindow.woaRuntimeSprites || {}),...sprites};
    const conceptArt: Record<string,string> = {};
    for (const [category, filename] of categories) {
      const entry = findEntry(zip, filename);
      if (entry) conceptArt[category] = URL.createObjectURL(await entry.async("blob"));
    }
    artWindow.woaConceptArt = conceptArt;
    document.documentElement.dataset.woaArtLoaded = "true";
    return true;
  } catch (error) {
    console.warn("WoA concept art archive could not be loaded; using built-in game sprites.", error);
    return false;
  }
}
artWindow.woaArtReady = loadConceptArchive();
