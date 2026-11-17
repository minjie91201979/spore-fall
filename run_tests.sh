#!/usr/bin/env bash
# 《孢城 SPORE FALL》回归测试聚合入口
# 用法：
#   bash run_tests.sh            # 跑全套 headless 探针，汇总 PASS / FAIL
#   bash run_tests.sh wave       # 只跑名字含 'wave' 的探针
#   bash run_tests.sh boss_w3    # 只跑织理者完整机制探针
#   bash run_tests.sh --render   # 追加真渲染专属探针（需桌面/OpenGL，无头环境跳过）
#
# 说明：
#   - 只收 extends SceneTree 的功能探针（可 --script 独立运行）。
#     extends Node 的探针（probe_pool / probe_pickup / probe_frame / probe_attacks 等）
#     是截图/临时探针，需挂到场景里跑，不在此入口内。
#   - probe_upgrade_click 必须真渲染跑：headless 下 dummy 字体度量把卡片撑高，
#     点击坐标从 y≈365 漂到 y≈617 必然打空（测试环境差异，非 UI bug）。
#     用 --render 参数单独以非 --headless 模式运行它。
#   - 每个探针带 60s 超时，防止交互类探针挂死拖垮整批。
#   - 兼容两种探针汇总格式：`PREFIX_PASS=n FAIL=m`（精确断言计数）
#     与 `PROBE_RESULT=PASS/FAIL`（布尔式探针）。

set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-./godot.exe}"
RENDER_MODE=0
FILTER=""
for arg in "$@"; do
  case "$arg" in
    --render) RENDER_MODE=1 ;;
    *) FILTER="$arg" ;;
  esac
done

# 稳定 headless 功能探针清单（全部 extends SceneTree）
PROBES=(
  "probe_aim"
  "probe_bullet_layer"
  "probe_wave"
  "probe_wave3"
  "probe_wave_timing"
  "probe_linkline"
  "probe_loom_phase"
  "probe_boss_w3"
  "probe_frames"
  "probe_boss"
  "probe_burst"
  "probe_career"
  "probe_death"
  "probe_deathfx"
  "probe_variants"
  "probe_quality"
  "probe_nav"
  "probe_story"
  "probe_title"
  "probe_touch"
  "probe_upgrade"
)

total_pass=0
total_fail=0
ran=0
skipped=0
failed_probes=0

printf "%-20s %-8s %-10s %-4s\n" "PROBE" "RESULT" "ASSERTS" "ERR"
printf "%s\n" "--------------------------------------------------"

for name in "${PROBES[@]}"; do
  if [[ -n "$FILTER" && "$name" != *"$FILTER"* ]]; then
    skipped=$((skipped + 1))
    continue
  fi
  if [[ ! -f "tests/$name.gd" ]]; then
    printf "%-20s %-8s %-10s %-4s\n" "$name" "MISSING" "-" "-"
    failed_probes=$((failed_probes + 1))
    continue
  fi

  out=$(timeout 60s "$GODOT" --headless --path . --script "tests/$name.gd" 2>&1)
  rc=$?
  # 精确断言汇总：抓最后一条 Xxx_PASS=n FAIL=m
  summary=$(printf "%s\n" "$out" | grep -E "[A-Z0-9_]+_PASS=[0-9]+ FAIL=[0-9]+" | tail -1)
  # 布尔式汇总：PROBE_RESULT=PASS/FAIL
  bres=$(printf "%s\n" "$out" | grep -oE "PROBE_RESULT=[[:space:]]*(PASS|FAIL)" | tail -1 | grep -oE "(PASS|FAIL)")
  errs=$(printf "%s\n" "$out" | grep -ciE "SCRIPT ERROR|Parse Error")

  is_fail=0
  asserts="-"
  if [[ -n "$summary" ]]; then
    p=$(printf "%s" "$summary" | sed -E "s/.*_PASS=([0-9]+).*/\1/")
    f=$(printf "%s" "$summary" | sed -E "s/.*FAIL=([0-9]+).*/\1/")
    asserts="${p}/${f}"
    total_pass=$((total_pass + p))
    total_fail=$((total_fail + f))
    [[ "$f" -gt 0 ]] && is_fail=1
  elif [[ -n "$bres" ]]; then
    asserts="BOOL"
    [[ "$bres" == "FAIL" ]] && is_fail=1
  fi
  [[ "$errs" -gt 0 ]] && is_fail=1
  [[ "$rc" -ne 0 ]] && is_fail=1   # 124=超时 / 1=崩溃

  if [[ "$is_fail" -eq 1 ]]; then
    result="FAIL"; failed_probes=$((failed_probes + 1))
  else
    result="OK"
  fi
  printf "%-20s %-8s %-10s %-4s\n" "$name" "$result" "$asserts" "$errs"
  ran=$((ran + 1))
done

# ---- 真渲染专属探针：headless 下字体度量不同会误报，故默认跳过，--render 才跑 ----
if [[ "$RENDER_MODE" -eq 1 && ( -z "$FILTER" || "probe_upgrade_click" == *"$FILTER"* ) ]]; then
  name="probe_upgrade_click"
  echo ""; echo "[render-only] $name（非 headless，真实 OpenGL 字体度量）"
  out=$(timeout 60s "$GODOT" --path . --script "tests/$name.gd" 2>&1)
  rc=$?
  bres=$(printf "%s\n" "$out" | grep -oE "PROBE_RESULT=[[:space:]]*(PASS|FAIL)" | tail -1 | grep -oE "(PASS|FAIL)")
  errs=$(printf "%s\n" "$out" | grep -ciE "SCRIPT ERROR|Parse Error")
  if [[ "$bres" == "PASS" && "$errs" -eq 0 && "$rc" -eq 0 ]]; then
    printf "%-20s %-8s %-10s %-4s\n" "$name" "OK" "BOOL" "$errs"
    ran=$((ran + 1))
  else
    printf "%-20s %-8s %-10s %-4s\n" "$name" "FAIL" "BOOL" "$errs"
    printf "%s\n" "$out" | grep -E "CLICK|PROBE_RESULT" | tail -3
    failed_probes=$((failed_probes + 1)); ran=$((ran + 1))
  fi
else
  skipped=$((skipped + 1))   # probe_upgrade_click 未跑（需 --render）
fi

printf "%s\n" "--------------------------------------------------"
printf "PROBES_RUN=%d SKIPPED=%d FAILED_PROBES=%d\n" "$ran" "$skipped" "$failed_probes"
printf "TOTAL_ASSERTIONS_PASS=%d TOTAL_ASSERTIONS_FAIL=%d\n" "$total_pass" "$total_fail"
if [[ "$failed_probes" -eq 0 && "$total_fail" -eq 0 ]]; then
  echo "ALL GREEN"
  exit 0
else
  echo "REGRESSION DETECTED"
  exit 1
fi
