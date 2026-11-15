// 中间帧动画帧表批量生成（agnes-image 2.0 flash，图生图）。
// 每只怪生成 2 张「四格帧表」：循环动作 + 单次动作，再由 split_anim_sheets.py 裁成单帧。
// 一次请求出多格，帧间造型一致性远好于逐帧分别生成（见 agnes-image 技能多视角经验）。
//
// 用法: NODE_OPTIONS= node tools/gen_anim_sheets.cjs
// 断点续跑：已存在的输出会跳过；失败自动退避重试（503 等 25s，429 等 55s）。
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = "C:/Users/musou/Desktop/object/spore-fall";
const NODE = "C:/Users/musou/.workbuddy/binaries/node/versions/22.22.2/node.exe";
const GEN = "C:/Users/musou/.workbuddy/skills/agnes-image/scripts/generate.cjs";
const REF = ROOT + "/build/anim_ref";
const OUT = ROOT + "/build/anim_sheets";

// 每只怪的动作语义（用于让四格姿态贴合角色设定）
const CREATURES = [
  { key: "walker",    noun: "a pale teal spore walker with a rounded hood",        move: "shambling forward with soft side-to-side sway",       act: "lunging forward to headbutt" },
  { key: "runner",    noun: "a slender fast spore runner with swept-back spines",   move: "sprinting with elongated bounding strides",           act: "coiling then snapping forward in a bite" },
  { key: "brute",     noun: "a bulky heavily armored spore brute",                  move: "heavy lumbering steps with grounded weight shifts",   act: "raising both arms then slamming down" },
  { key: "lurker",    noun: "a dark low-slung ambush spore with spiked back",       move: "slow creeping crawl close to the ground",             act: "bursting upward out of hiding with spines flared" },
  { key: "miasma",    noun: "a floating toxic mushroom-cap spore trailing mist",    move: "gently bobbing and drifting while hovering",          act: "puffing outward and releasing a toxic cloud" },
  { key: "splitter",  noun: "a jelly-like segmented spore that divides",            move: "wobbling and jiggling as it oozes forward",           act: "swelling then splitting into smaller buds" },
  { key: "spitter",   noun: "a spiny spore creature with a narrow snout",           move: "skittering with quick nervous steps",                 act: "puffing its cheeks then spitting a needle" },
  { key: "sprayer",   noun: "a bloated sac-like spore with a wide maw",             move: "squelching forward with a heavy rolling gait",        act: "inflating then spraying a fan of venom" },
  { key: "boss",      noun: "the colossal pink-violet Brood Mother nest boss",      move: "slow menacing advance with heaving mass",             act: "rearing up then unleashing a radial spore burst" },
  { key: "corroder",  noun: "an armored yellow-green plated spore with one eye",    move: "heavy plated walking gait with a low crouch",         act: "planting its feet then spewing acid forward" },
  { key: "burrower",  noun: "a violet drill-headed burrowing spore",                move: "low darting scuttle with head lowered",               act: "coiling then drilling straight upward" },
  { key: "bloom",     noun: "a glowing green umbrella-cap floating spore",          move: "slow drifting hover with pulsing cap",                 act: "flaring its cap wide and scattering spores" },
  { key: "abyss",     noun: "a colossal violet-black tentacled devourer with a cyan glowing maw", move: "heavy undulating advance with writhing tentacles", act: "opening its maw wide then unleashing a blast" },
];

const COMMON =
  "CRITICAL: the SAME creature in EVERY cell — identical size, identical centered position, " +
  "identical silhouette, identical colors, identical glowing rim outline, identical lighting. " +
  "Only the pose changes slightly between cells, like hand-drawn inbetween frames of one short animation. " +
  "Pure white background. Four evenly spaced square cells in one horizontal row with clear white gaps. " +
  "NO text, NO numbers, NO borders, NO panels, NO grid lines, NO split screen, NO extra creatures. " +
  "Game sprite animation sheet, sharp focus, clean even studio lighting.";

function buildPrompt(c, kind) {
  const lead = `Transform the reference creature (${c.noun}) into a 4-frame horizontal animation strip: `;
  if (kind === "loop") {
    return lead +
      `four consecutive LOOPING movement phases of ${c.move} — ` +
      "frame 1 neutral, frame 2 compressed/anticipation, frame 3 extended/stride, frame 4 returning to neutral " +
      "so the strip loops seamlessly. " + COMMON;
  }
  return lead +
    `four consecutive ONE-SHOT attack phases of ${c.act} — ` +
    "frame 1 neutral guard, frame 2 winding up / coiling, frame 3 peak strike / release, frame 4 recovering back to neutral. " +
    COMMON;
}

function runOne(c, kind) {
  const name = `${c.key}_${kind}.png`;
  const out = `${OUT}/${name}`;
  if (fs.existsSync(out) && fs.statSync(out).size > 20000) {
    console.log(`SKIP ${name}`);
    return true;
  }
  const ref = `${REF}/${c.key}.png`;
  if (!fs.existsSync(ref)) {
    console.log(`MISSING_REF ${ref}`);
    return false;
  }
  for (let attempt = 1; attempt <= 10; attempt++) {
    const args = [
      GEN,
      "--prompt", buildPrompt(c, kind),
      "--image", ref,
      "--size", "1536x1024",
      "--output", out,
      "--timeout", "600000",
    ];
    const res = spawnSync(NODE, args, { encoding: "utf8", maxBuffer: 1024 * 1024 * 32 });
    const log = (res.stdout || "") + (res.stderr || "");
    const ok = res.status === 0 && /"status"\s*:\s*"ok"/.test(log) &&
      fs.existsSync(out) && fs.statSync(out).size > 20000;
    if (ok) {
      console.log(`OK ${name} (attempt ${attempt})`);
      return true;
    }
    const is429 = /429|rate_limit/.test(log);
    const wait = is429 ? 55000 : 25000;
    console.log(`FAIL ${name} attempt ${attempt}; wait ${wait / 1000}s; ${log.slice(-180).replace(/\n/g, " ")}`);
    const t0 = Date.now();
    while (Date.now() - t0 < wait) { /* 同步等待，避免并发打满队列 */ }
  }
  return false;
}

function main() {
  fs.mkdirSync(OUT, { recursive: true });
  let fail = 0;
  for (const c of CREATURES) {
    for (const kind of ["loop", "act"]) {
      if (!runOne(c, kind)) fail++;
    }
  }
  console.log(`DONE failures=${fail}`);
  process.exitCode = fail > 0 ? 1 : 0;
}

main();
