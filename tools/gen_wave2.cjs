// Wave 2 concept renders via agnes-image, with 503/429 retry + backoff.
// Usage: node tools/gen_wave2.cjs
const { spawnSync } = require("child_process");

const NODE = "C:/Users/musou/.workbuddy/binaries/node/versions/22.22.2/node.exe";
const GEN = "C:/Users/musou/.workbuddy/skills/agnes-image/scripts/generate.cjs";
const OUT = "C:/Users/musou/Desktop/object/spore-fall/build/sprites_raw";

const JOBS = [
  {
    name: "corroder",
    prompt: "A menacing armored fungal spore monster called Corroder, chitin-plated carapace dripping acid, sickly yellow-green bioluminescent shell, single glowing eye, bulbous spore body with armor plates, creature design reference, plain white background, the ONLY subject in image, game enemy concept art, sharp focus, clean lighting",
    output: OUT + "/corroder.png",
  },
  {
    name: "burrower",
    prompt: "A subterranean ambush fungal spore monster called Burrower, sharp drill-like head, digging limbs, deep violet carapace, only spiked back and head visible as if half-buried, creature design reference, plain white background, the ONLY subject in image, game enemy concept art, sharp focus, clean lighting",
    output: OUT + "/burrower.png",
  },
  {
    name: "bloom",
    prompt: "A floating toxic spore-bloom fungal monster called Bloom, umbrella-shaped mushroom cap glowing toxic green, emitting luminous floating spores, delicate tentacle roots, creature design reference, plain white background, the ONLY subject in image, game enemy concept art, sharp focus, clean lighting",
    output: OUT + "/bloom.png",
  },
  {
    name: "abyss",
    prompt: "A colossal abyssal devourer boss monster called Abyssal Devourer, gaping maw with bioluminescent cyan-green inner glow, writhing tentacles, abyssal violet-black body, terrifying fungal entity, boss design reference, plain white background, the ONLY subject in image, game boss concept art, epic, sharp focus, clean lighting",
    output: OUT + "/abyss.png",
  },
];

function runJob(job) {
  const args = [
    GEN,
    "--prompt", job.prompt,
    "--size", "1024x1024",
    "--output", job.output,
    "--timeout", "600000",
  ];
  const res = spawnSync(NODE, args, { encoding: "utf8", maxBuffer: 1024 * 1024 * 32 });
  const out = (res.stdout || "") + (res.stderr || "");
  const ok = res.status === 0 && /"status"\s*:\s*"ok"/.test(out) && !/503|429/.test(out);
  return { ok, out };
}

function backoff(attempt) {
  // 503 -> wait longer; generic increasing
  return Math.min(60000, 15000 + attempt * 12000);
}

// 非忙等阻塞（让出线程，避免后台任务空转吃掉一个核心）
function sleep(ms) {
  const sab = new SharedArrayBuffer(4);
  const i32 = new Int32Array(sab);
  Atomics.wait(i32, 0, 0, ms);
}

let failures = 0;
for (const job of JOBS) {
  let attempt = 0;
  let done = false;
  while (attempt < 10 && !done) {
    attempt++;
    process.stdout.write(`\n=== [${job.name}] attempt ${attempt} ===\n`);
    const { ok, out } = runJob(job);
    if (ok) {
      process.stdout.write(`OK ${job.name}\n`);
      done = true;
    } else {
      const why = /503/.test(out) ? "queue-full(503)" : /429/.test(out) ? "rate-limit(429)" : "error";
      const wait = backoff(attempt);
      process.stdout.write(`FAIL ${job.name} (${why}); retry in ${(wait/1000)|0}s\n`);
      if (attempt < 10) {
        sleep(wait);
      }
    }
  }
  if (!done) { failures++; process.stdout.write(`GAVE UP ${job.name}\n`); }
}

process.stdout.write(`\nDONE. failures=${failures}\n`);
