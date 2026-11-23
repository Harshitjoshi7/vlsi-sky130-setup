#!/usr/bin/env bash
# ================================================================
#  run_openlane.sh — Run OpenLane 2 (Synthesis or full RTL-to-GDS)
#
#  Usage:
#    ./run_openlane.sh [config.json] [extra_flags]
#
#  Examples:
#    # 1. Full RTL to GDS II using the official container:
#    ./run_openlane.sh examples/and_gate/config.json --dockerized
#
#    # 2. Run synthesis only:
#    ./run_openlane.sh examples/and_gate/config.json --dockerized --to Yosys.Synthesis
# ================================================================

source "$HOME/.vlsi_env" 2>/dev/null

CONFIG="${1:-examples/and_gate/config.json}"
shift || true

if [ ! -f "$CONFIG" ]; then
  echo "Error: Config file '$CONFIG' not found."
  echo "Usage: $0 [path/to/config.json] [openlane_options...]"
  exit 1
fi

echo "========================================================"
echo "  OpenLane 2 Runner"
echo "  Config : $CONFIG"
echo "  PDK    : $PDK_PATH (using local PDK via --manual-pdk)"
echo "========================================================"

# In OpenLane 2, --dockerized MUST precede all other options!
if [[ " $* " =~ " --dockerized " ]] || [ -z "$*" ]; then
  # Strip --dockerized from extra arguments if passed
  EXTRA_ARGS=()
  for arg in "$@"; do
    if [ "$arg" != "--dockerized" ]; then
      EXTRA_ARGS+=("$arg")
    fi
  done
  echo "  Engine : Docker container (efabless/openlane2)"
  openlane --dockerized --manual-pdk "$CONFIG" "${EXTRA_ARGS[@]}"
else
  echo "  Engine : Bare-metal local tools"
  openlane --manual-pdk "$CONFIG" "$@"
fi

echo ""
echo "========================================================"
echo "  Run completed! Check the 'runs/' folder inside your design."
echo "========================================================"
