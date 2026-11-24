#!/usr/bin/env bash
# ================================================================
#  synth_sky130.sh  — Yosys SKY130A synthesis helper
#
#  Usage:
#    chmod +x synth_sky130.sh
#    ./synth_sky130.sh <top_module> <file1.v> [file2.v ...]
#
#  Example:
#    ./synth_sky130.sh top design.v
#    ./synth_sky130.sh alu alu.v alu_ops.v
# ================================================================

source "$HOME/.vlsi_env" 2>/dev/null

TOP="$1"; shift
SRCS="$@"

if [ -z "$TOP" ] || [ -z "$SRCS" ]; then
  echo "Usage: $0 <top_module> <file1.v> [file2.v ...]"
  exit 1
fi

if [ ! -f "$LIBERTY" ]; then
  echo "ERROR: Liberty file not found: $LIBERTY"
  echo "       Run vlsi_setup.sh first, then source ~/.bashrc"
  exit 1
fi

echo "========================================================"
echo "  Yosys SKY130A Synthesis"
echo "  Top  : $TOP"
echo "  Src  : $SRCS"
echo "  Lib  : $LIBERTY"
echo "========================================================"

yosys -p "
  # Read all source files
  read_verilog $SRCS

  # Elaborate + synthesise
  synth -top $TOP

  # Map flip-flops to SKY130 cells
  dfflibmap -liberty $LIBERTY

  # Technology mapping with ABC
  abc -liberty $LIBERTY

  # Remove buffers and tidy up
  clean

  # Print area/cell statistics
  stat -liberty $LIBERTY

  # Write output netlist
  write_verilog -noattr ${TOP}_synth.v

  # Show schematic (opens xdot window if display available)
  show -format dot -prefix ${TOP}_schematic
"

# Also render SVG and PNG images of schematic for easy viewing anywhere
if command -v dot &>/dev/null && [ -f "${TOP}_schematic.dot" ]; then
  dot -Tsvg "${TOP}_schematic.dot" -o "${TOP}_schematic.svg" 2>/dev/null || true
  dot -Tpng "${TOP}_schematic.dot" -o "${TOP}_schematic.png" 2>/dev/null || true
fi

echo ""
echo "========================================================"
echo "  Synthesis Complete!"
echo "  Netlist   → ${TOP}_synth.v"
echo "  Schematic → ${TOP}_schematic.dot"
[ -f "${TOP}_schematic.svg" ] && echo "  SVG Image → ${TOP}_schematic.svg  (open in browser/Windows)"
[ -f "${TOP}_schematic.png" ] && echo "  PNG Image → ${TOP}_schematic.png"
echo "========================================================"
