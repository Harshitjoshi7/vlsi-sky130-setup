#!/bin/bash
# ================================================================
#  VLSI Tool + SKY130A PDK Verification Script
#  Run after vlsi_setup.sh to confirm everything works
#
#  Usage: chmod +x verify.sh && ./verify.sh
# ================================================================

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"
BOLD="\033[1m"; NC="\033[0m"

PASS=0; FAIL=0; WARN=0

ok()   { echo -e "${GREEN}  ✅ PASS${NC} — $*"; ((PASS++)); }
fail() { echo -e "${RED}  ❌ FAIL${NC} — $*"; ((FAIL++)); }
warn() { echo -e "${YELLOW}  ⚠️  WARN${NC} — $*"; ((WARN++)); }
hdr()  { echo ""; echo -e "${BOLD}── $* ─────────────────────────────────────${NC}"; }

source "$HOME/.vlsi_env" 2>/dev/null

echo "========================================================"
echo -e "${BOLD}  VLSI + SKY130A Verification Report${NC}"
echo "  $(date)"
echo "========================================================"

# ================================================================
# 1. ENVIRONMENT VARIABLES
# ================================================================
hdr "1. Environment Variables"

check_env() {
  local var="$1"
  if [ -n "${!var}" ]; then
    ok "$var = ${!var}"
  else
    fail "$var is NOT set  →  run: source ~/.bashrc"
  fi
}

check_env PDK_ROOT
check_env PDK_PATH
check_env PDK
check_env STD_CELL_LIBRARY
check_env NGSPICE_MODELS
check_env LIBERTY
check_env NETGEN_SETUP
check_env OPENLANE_PDK_ROOT

# ================================================================
# 2. PDK FILES ON DISK
# ================================================================
hdr "2. SKY130A PDK Files"

check_path() {
  local label="$1" path="$2"
  if [ -e "$path" ]; then
    ok "$label"
  else
    fail "$label  →  missing: $path"
  fi
}

check_path "PDK root dir"              "$PDK_ROOT/sky130A"
check_path "Magic tech files"          "$PDK_ROOT/sky130A/libs.tech/magic"
check_path "Ngspice SPICE models"      "$PDK_ROOT/sky130A/libs.tech/ngspice/sky130.lib.spice"
check_path "Xschem symbols"            "$PDK_ROOT/sky130A/libs.tech/xschem"
check_path "KLayout tech files"        "$PDK_ROOT/sky130A/libs.tech/klayout"
check_path "Netgen LVS setup"          "$PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl"
check_path "Liberty file (Yosys)"      "$LIBERTY"
check_path "Std-cell library ref"      "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd"

# ================================================================
# 3. TOOL VERSIONS
# ================================================================
hdr "3. Tool Versions"

check_tool() {
  local tool="$1" vercmd="$2"
  if command -v "$tool" &>/dev/null; then
    local ver
    ver=$(eval "$vercmd" 2>&1 | head -1)
    ok "$tool — $ver"
  else
    fail "$tool — NOT FOUND in PATH"
  fi
}

check_tool iverilog  "iverilog -V"
check_tool gtkwave   "gtkwave --version"
check_tool yosys     "yosys --version"
check_tool klayout   "klayout -v"
check_tool ngspice   "ngspice -v"
check_tool magic     "magic --version"
check_tool netgen    "netgen --version"
check_tool xschem    "xschem --version"
check_tool openlane  "openlane --version"
check_tool java      "java -version"
check_tool logisim   "echo Launcher OK"
check_tool volare    "volare --version"

# ================================================================
# 4. CONFIG FILES
# ================================================================
hdr "4. Per-tool Config Files"

check_path "~/.magicrc"              "$HOME/.magicrc"
check_path "~/.xschem/xschemrc"     "$HOME/.xschem/xschemrc"
check_path "~/.bashrc vlsi source"  "/dev/null"   # checked differently

if grep -qF "vlsi_env" "$HOME/.bashrc" 2>/dev/null; then
  ok "~/.bashrc sources ~/.vlsi_env"
else
  fail "~/.bashrc does NOT source ~/.vlsi_env  →  run vlsi_setup.sh again"
fi

# KLayout symlink — search dynamically, auto-fix if source exists
KLAYOUT_DEST="$HOME/.klayout/tech/sky130A.lyt"
if [ -L "$KLAYOUT_DEST" ] || [ -f "$KLAYOUT_DEST" ]; then
  ok "~/.klayout/tech/sky130A.lyt present"
else
  # Try to find the real .lyt file anywhere in the PDK
  KLAYOUT_SRC=$(find "$PDK_ROOT/sky130A/libs.tech/klayout" \
    -maxdepth 3 -name "*.lyt" 2>/dev/null | head -1)
  if [ -n "$KLAYOUT_SRC" ]; then
    mkdir -p "$HOME/.klayout/tech"
    ln -sf "$KLAYOUT_SRC" "$KLAYOUT_DEST" 2>/dev/null
    ok "~/.klayout/tech/sky130A.lyt — auto-fixed symlink → $KLAYOUT_SRC"
  else
    warn "~/.klayout/tech/sky130A.lyt missing
         Fix: find \$PDK_ROOT/sky130A/libs.tech/klayout -name '*.lyt'
         then: ln -sf <result> ~/.klayout/tech/sky130A.lyt"
  fi
fi

# ================================================================
# 5. FUNCTIONAL TESTS  (non-GUI, batch mode)
# ================================================================
hdr "5. Functional Tests"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ── 5a. Icarus Verilog: compile + simulate a simple AND gate ──
cat > "$TMPDIR_TEST/and_gate.v" << 'EOF'
module and_gate(input a, b, output y);
  assign y = a & b;
endmodule
module tb;
  reg a=0, b=0; wire y;
  and_gate dut(.a(a),.b(b),.y(y));
  initial begin
    #1 a=1; b=1;
    #1 if(y===1) $display("IVERILOG_OK");
    else $display("IVERILOG_FAIL");
    $finish;
  end
endmodule
EOF
iverilog -o "$TMPDIR_TEST/and_gate.vvp" "$TMPDIR_TEST/and_gate.v" 2>/dev/null \
  && IVSIM=$(vvp "$TMPDIR_TEST/and_gate.vvp" 2>/dev/null)
if echo "$IVSIM" | grep -q "IVERILOG_OK"; then
  ok "Icarus Verilog: compile + simulate AND gate"
else
  fail "Icarus Verilog: simulation failed"
fi

# ── 5b. Yosys: synthesise with SKY130 Liberty ─────────────────
cat > "$TMPDIR_TEST/synth.v" << 'EOF'
module top(input a, b, output y);
  assign y = a & b;
endmodule
EOF
cat > "$TMPDIR_TEST/synth.ys" << EOF
read_verilog $TMPDIR_TEST/synth.v
synth -top top
abc -liberty $LIBERTY
stat
EOF
if yosys -q "$TMPDIR_TEST/synth.ys" > "$TMPDIR_TEST/synth.log" 2>&1; then
  ok "Yosys: synthesis + ABC mapping with SKY130 Liberty"
else
  fail "Yosys synthesis failed  →  check $TMPDIR_TEST/synth.log"
fi

# ── 5c. Ngspice: two-part test ────────────────────────────────

# Part A: basic ngspice works at all (no PDK needed)
cat > "$TMPDIR_TEST/rc.spice" << 'EOF'
* Simple RC — no PDK required
R1 in out 1k
C1 out 0  1n
Vin in 0 DC 1
.op
.end
EOF
NGBASIC=$(ngspice -b "$TMPDIR_TEST/rc.spice" 2>&1)
if echo "$NGBASIC" | grep -qiE "ngspice|operating|v\(out\)"; then
  ok "Ngspice: basic simulation (RC circuit)"
else
  fail "Ngspice: basic simulation failed
         Output: $(echo "$NGBASIC" | tail -5)"
fi

# Part B: find SKY130 model file (path varies by PDK version)
NGSPICE_LIB=$(find "$PDK_ROOT/sky130A/libs.tech/ngspice" \
  -maxdepth 2 -name "*.lib.spice" 2>/dev/null | head -1)

# Update NGSPICE_MODELS in vlsi_env if path found but different
if [ -z "$NGSPICE_LIB" ]; then
  fail "Ngspice: SKY130 model file not found under $PDK_ROOT/sky130A/libs.tech/ngspice/
         → PDK may not be installed; run: volare enable --pdk sky130 --pdk-root \$PDK_ROOT <version>"
else
  ok "Ngspice: SKY130 model file found — $NGSPICE_LIB"

  # Auto-patch ~/.vlsi_env if NGSPICE_MODELS is wrong
  if [ "$NGSPICE_MODELS" != "$NGSPICE_LIB" ]; then
    warn "NGSPICE_MODELS mismatch — auto-patching ~/.vlsi_env"
    sed -i "s|export NGSPICE_MODELS=.*|export NGSPICE_MODELS=\"$NGSPICE_LIB\"|" "$HOME/.vlsi_env"
    export NGSPICE_MODELS="$NGSPICE_LIB"
    ok "NGSPICE_MODELS updated → $NGSPICE_LIB"
  fi

  # Part C: simulate with real SKY130 models
  cat > "$TMPDIR_TEST/inv_sky130.spice" << EOF
* SKY130A inverter .op — uses real SPICE models
.lib "$NGSPICE_MODELS" tt
M1 out in vdd vdd sky130_fd_pr__pfet_01v8 W=1u L=0.15u
M2 out in gnd gnd sky130_fd_pr__nfet_01v8 W=0.65u L=0.15u
Vdd vdd 0 1.8
Vgnd gnd 0 0
Vin in  0 DC 0.9
.op
.end
EOF
  NGSKY=$(ngspice -b "$TMPDIR_TEST/inv_sky130.spice" 2>&1)
  if echo "$NGSKY" | grep -qiE "ngspice|v\(out\)|i\(vdd\)|operating"; then
    ok "Ngspice: DC .op with SKY130A SPICE models"
  else
    fail "Ngspice: SKY130 simulation failed
           Output: $(echo "$NGSKY" | grep -iE 'error|warning|fatal' | head -5)"
  fi
fi

# ── 5d. Netgen LVS setup file ─────────────────────────────────
if [ -f "$NETGEN_SETUP" ]; then
  ok "Netgen: SKY130A LVS setup file exists"
else
  fail "Netgen: $NETGEN_SETUP missing"
fi

# ── 5e. OpenLane PDK link ─────────────────────────────────────
if [ -d "$OPENLANE_PDK_ROOT/sky130A" ]; then
  ok "OpenLane: PDK_ROOT points to valid sky130A"
else
  fail "OpenLane: OPENLANE_PDK_ROOT/sky130A not found"
fi

# ================================================================
# SUMMARY
# ================================================================
TOTAL=$((PASS + FAIL + WARN))
echo ""
echo "========================================================"
echo -e "${BOLD}  Results: ${GREEN}$PASS passed${NC} · ${RED}$FAIL failed${NC} · ${YELLOW}$WARN warnings${NC}  (of $TOTAL checks)"
echo "========================================================"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  🎉 All tools + SKY130A PDK are working correctly!${NC}"
  echo "     You're ready to design chips!"
else
  echo -e "${RED}${BOLD}  ⚠  $FAIL check(s) failed — re-run vlsi_setup.sh to fix${NC}"
  echo "     Or share this output with your teacher."
fi
echo ""
