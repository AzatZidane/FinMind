// Генератор ассетов: AppIcon (все размеры) + LaunchLogo (2x/3x)
// Источник: AppIcon1024.png (ищем в appiconset, иначе в корне репо)
import fs from "fs";
import path from "path";
import sharp from "sharp";

const repoRoot = process.cwd();

// Автоопределение структуры: FinMind/FinMind/... или FinMind/...
const candidates = [
  path.join(repoRoot, "FinMind", "FinMind"),
  path.join(repoRoot, "FinMind"),
];
const base = candidates.find(p => fs.existsSync(path.join(p, "Assets.xcassets"))) || candidates[0];

const appIconDir    = path.join(base, "Assets.xcassets", "AppIcon.appiconset");
const launchLogoDir = path.join(base, "Assets.xcassets", "LaunchLogo.imageset");

// Источник 1024: сначала в appiconset, иначе в корне
let src1024 = path.join(appIconDir, "AppIcon1024.png");
if (!fs.existsSync(src1024)) {
  const rootCandidate = path.join(repoRoot, "AppIcon1024.png");
  if (fs.existsSync(rootCandidate)) src1024 = rootCandidate;
}
if (!fs.existsSync(src1024)) {
  console.error("Не найден AppIcon1024.png.\nПоложи его либо в:", appIconDir, "\nлибо в:", path.join(repoRoot, "AppIcon1024.png"));
  process.exit(1);
}

fs.mkdirSync(appIconDir, { recursive: true });
fs.mkdirSync(launchLogoDir, { recursive: true });

// Набор размеров
const targets = [
  // iPhone
  { idiom: "iphone", size: "20x20",    scale: "2x", px: 40,  file: "Icon-20@2x.png" },
  { idiom: "iphone", size: "20x20",    scale: "3x", px: 60,  file: "Icon-20@3x.png" },
  { idiom: "iphone", size: "29x29",    scale: "2x", px: 58,  file: "Icon-29@2x.png" },
  { idiom: "iphone", size: "29x29",    scale: "3x", px: 87,  file: "Icon-29@3x.png" },
  { idiom: "iphone", size: "40x40",    scale: "2x", px: 80,  file: "Icon-40@2x.png" },
  { idiom: "iphone", size: "40x40",    scale: "3x", px: 120, file: "Icon-40@3x.png" },
  { idiom: "iphone", size: "60x60",    scale: "2x", px: 120, file: "Icon-60@2x.png" },
  { idiom: "iphone", size: "60x60",    scale: "3x", px: 180, file: "Icon-60@3x.png" },

  // iPad
  { idiom: "ipad",   size: "20x20",    scale: "1x", px: 20,  file: "Icon-20~ipad.png" },
  { idiom: "ipad",   size: "20x20",    scale: "2x", px: 40,  file: "Icon-20@2x~ipad.png" },
  { idiom: "ipad",   size: "29x29",    scale: "1x", px: 29,  file: "Icon-29~ipad.png" },
  { idiom: "ipad",   size: "29x29",    scale: "2x", px: 58,  file: "Icon-29@2x~ipad.png" },
  { idiom: "ipad",   size: "40x40",    scale: "1x", px: 40,  file: "Icon-40~ipad.png" },
  { idiom: "ipad",   size: "40x40",    scale: "2x", px: 80,  file: "Icon-40@2x~ipad.png" },
  { idiom: "ipad",   size: "76x76",    scale: "1x", px: 76,  file: "Icon-76.png" },
  { idiom: "ipad",   size: "76x76",    scale: "2x", px: 152, file: "Icon-76@2x.png" },
  { idiom: "ipad",   size: "83.5x83.5",scale: "2x", px: 167, file: "Icon-83.5@2x~ipad.png" },

  // Marketing 1024 — оставляем исходный
  { idiom: "marketing", size: "1024x1024", scale: "1x", px: 1024, file: "AppIcon1024.png", keep: true },
];

(async () => {
  if (!fs.existsSync(path.join(appIconDir, "AppIcon1024.png"))) {
    fs.copyFileSync(src1024, path.join(appIconDir, "AppIcon1024.png"));
  }

  for (const t of targets) {
    if (t.keep) continue;
    await sharp(src1024).resize(t.px, t.px, { fit: "cover" }).png({ compressionLevel: 9 })
      .toFile(path.join(appIconDir, t.file));
    console.log("✓", t.file);
  }

  const images = targets.map(t => ({
    idiom: t.idiom, size: t.size, scale: t.scale, filename: t.file
  }));
  fs.writeFileSync(path.join(appIconDir, "Contents.json"),
    JSON.stringify({ images, info:{version:1,author:"xcode"} }, null, 2));

  await sharp(src1024).resize(512, 512).png({ compressionLevel: 9 })
    .toFile(path.join(launchLogoDir, "LaunchLogo@2x.png"));
  await sharp(src1024).resize(768, 768).png({ compressionLevel: 9 })
    .toFile(path.join(launchLogoDir, "LaunchLogo@3x.png"));
  fs.writeFileSync(path.join(launchLogoDir, "Contents.json"), JSON.stringify({
    images: [
      { idiom: "universal", filename: "LaunchLogo@2x.png", scale: "2x" },
      { idiom: "universal", filename: "LaunchLogo@3x.png", scale: "3x" }
    ],
    info: { version: 1, author: "xcode" },
    properties: { "template-rendering-intent": "original" }
  }, null, 2));

  console.log("\nВсе ассеты сгенерированы в:", base);
})();
