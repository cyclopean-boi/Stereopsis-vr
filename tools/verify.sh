#!/usr/bin/env bash
# Headless test suite (Linux/macOS port of the Windows Verifica.cmd).
# Usage: GODOT=/path/to/godot tools/verify.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOG="$ROOT/.local"
mkdir -p "$LOG"
fail=0

run() {  # name, marker, args...
  local name="$1" marker="$2"; shift 2
  "$GODOT" --headless --path "$ROOT" --xr-mode off --log-file "$LOG/verify-$name.log" "$@" >/dev/null 2>&1
  local code=$?
  if [ $code -ne 0 ]; then echo "FAIL $name (exit $code)"; fail=1; return; fi
  if ! grep -q "$marker" "$LOG/verify-$name.log"; then echo "FAIL $name (no '$marker')"; fail=1; return; fi
  if grep -q "SCRIPT ERROR" "$LOG/verify-$name.log"; then echo "FAIL $name (SCRIPT ERROR)"; fail=1; return; fi
  echo "ok   $name"
}

run stats            "PASS:" --script res://tests/stats_test.gd
run psi              "PASS:" --script res://tests/psi_test.gd
run flow             "PASS:" --script res://tests/flow_test.gd
run autotest         "STEREOPSI_RESULT" res://scenes/main.tscn -- --autotest
run training         "PASS:" --script res://tests/training_test.gd
run bosco            "BOSCO_RESULT" res://scenes/training.tscn -- --autotest --prove=80 --blocco=2
run bosco-contrasto  "BOSCO_RESULT" res://scenes/training.tscn -- --autotest --prove=300 --blocco=2000 --sim-bias=650 --sim-contrasto=0.3
run capanna          "PASS:" --script res://tests/capanna_test.gd
run capanna-autotest "CAPANNA_RESULT" res://scenes/capanna.tscn -- --autotest
run rovine           "PASS:" --script res://tests/rovine_test.gd
run rovine-autotest  "ROVINE_RESULT" res://scenes/rovine.tscn -- --autotest --prove=200 --sim-globale=0.25
run rovine-mosaico   "ROVINE_RESULT" res://scenes/rovine.tscn -- --autotest --prove=300 --sim-mosaico=6 --sim-scuri=1
run rovine-oltre     "ROVINE_RESULT" res://scenes/rovine.tscn -- --autotest --prove=400 --sim-mosaico=15
run hub              "PASS:" --script res://tests/hub_test.gd

if [ $fail -eq 0 ]; then echo "ALL PASSED"; else echo "SOME TESTS FAILED"; exit 1; fi
