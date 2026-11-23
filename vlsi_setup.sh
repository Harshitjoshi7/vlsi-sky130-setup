#!/bin/bash
# ================================================================
#  VLSI Full Setup Script — WSL Ubuntu 24
#  Tools : Icarus Verilog, GTKWave, Yosys, KLayout, Ngspice,
#          Magic VLSI, Netgen, Xschem, OpenLane 2, Logisim
#  PDK   : SkyWater SKY130A via volare
#
#  Run   : chmod +x vlsi_setup.sh && ./vlsi_setup.sh
#  After : source ~/.bashrc
#
#  ✅ SAFE TO RE-RUN — skips anything already installed
#  ✅ IDEMPOTENT     — no errors if run multiple times
#  ✅ SCHOOL-READY   — works on any fresh or partial install
# ================================================================

# ── NO set -e  (we handle errors per-phase, never abort whole script) ──
LOGFILE="$HOME/vlsi_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

# ── Colour helpers ────────────────────────────────────────────
GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; NC="\033[0m"
ok()   { echo -e "${GREEN}  ✓ $*${NC}"; }
skip() { echo -e "${YELLOW}  ⟳ $* — already installed, skipping${NC}"; }
warn() { echo -e "${RED}  ✗ $*${NC}"; }
phase(){ echo ""; echo "── $* ──────────────────────────────────────────"; }

# ── Helpers ───────────────────────────────────────────────────
has_cmd() { command -v "$1" &>/dev/null; }

# Clone a git repo OR pull if the directory already exists
# Usage: git_clone_or_pull <url> <dir>
git_clone_or_pull() {
  local url="$1" dir="$2"
  if [ -d "$dir/.git" ]; then
    echo "    Existing clone found → git pull"
    git -C "$dir" pull --ff-only 2>&1 || echo "    (pull skipped — no fast-forward)"
  elif [ -d "$dir" ]; then
    warn "$dir exists but is not a git repo — removing and re-cloning"
    rm -rf "$dir"
    git clone --depth=1 "$url" "$dir"
  else
    git clone --depth=1 "$url" "$dir"
  fi
}

# ── Global paths ──────────────────────────────────────────────
PDK_ROOT="$HOME/pdk"
TOOLS_SRC="$HOME/vlsi-src"
mkdir -p "$PDK_ROOT" "$TOOLS_SRC" "$HOME/bin"

echo "========================================================"
echo "  VLSI Tools + SKY130 PDK — WSL Ubuntu 24 Setup"
echo "  Log → $LOGFILE"
echo "========================================================"

# ================================================================
# PHASE 1 — System dependencies  (apt is always idempotent)
# ================================================================
phase "PHASE 1 : System dependencies"
sudo apt update -qq && sudo apt upgrade -y -qq

sudo apt install -y \
  build-essential git curl wget \
  python3 python3-pip python3-venv python3-dev python3-full \
  pipx \
  tcl tcl-dev tk tk-dev \
  libx11-dev libxext-dev libxft-dev libxrender-dev \
  libxaw7-dev libxmu-dev libxi-dev \
  libxcb1-dev libxcb-render0-dev \
  libglu1-mesa-dev freeglut3-dev mesa-common-dev \
  libcairo2-dev libgsl-dev \
  libreadline-dev libncurses5-dev libncursesw5-dev \
  flex bison libfl2 libfl-dev \
  libffi-dev libssl-dev libsuitesparse-dev \
  autoconf automake libtool \
  gawk cmake \
  libboost-all-dev libeigen3-dev \
  libgtk-3-dev \
  default-jre \
  xdg-utils \
  graphviz xdot \
  fonts-urw-base35

pipx ensurepath
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
ok "Phase 1 complete"

# ================================================================
# PHASE 2 — APT-installable tools
# ================================================================
phase "PHASE 2 : APT tools (iverilog, gtkwave, yosys, klayout)"

if has_cmd iverilog; then
  skip "Icarus Verilog $(iverilog -V 2>&1 | head -1)"
else
  sudo apt install -y iverilog
  ok "Icarus Verilog : $(iverilog -V 2>&1 | head -1)"
fi

if has_cmd gtkwave; then
  skip "GTKWave"
else
  sudo apt install -y gtkwave
  ok "GTKWave : installed"
fi

if has_cmd yosys; then
  skip "Yosys $(yosys --version 2>&1 | head -1)"
else
  sudo apt install -y yosys
  ok "Yosys : $(yosys --version 2>&1 | head -1)"
fi

if has_cmd klayout; then
  skip "KLayout $(klayout -v 2>&1 | head -1)"
else
  if sudo apt install -y klayout 2>/dev/null; then
    ok "KLayout : $(klayout -v 2>&1 | head -1)"
  else
    echo "  klayout not in apt — downloading latest .deb..."
    KLAYOUT_DEB=$(curl -fsSL https://api.github.com/repos/KLayout/klayout/releases/latest \
      | grep "browser_download_url.*amd64.deb" | head -1 | cut -d'"' -f4)
    wget -q -O /tmp/klayout.deb "$KLAYOUT_DEB"
    sudo dpkg -i /tmp/klayout.deb || sudo apt-get install -f -y
    ok "KLayout : installed via .deb"
  fi
fi

ok "Phase 2 complete"

# ================================================================
# PHASE 3a — Ngspice from source
# ================================================================
phase "PHASE 3a : Ngspice (source build)"

if has_cmd ngspice; then
  skip "Ngspice : $(ngspice -v 2>&1 | head -1)"
else
  cd "$TOOLS_SRC"
  git_clone_or_pull https://github.com/ngspice/ngspice.git ngspice
  cd ngspice

  # autogen.sh needed for git clones (not for tarballs)
  if [ ! -f configure ]; then
    echo "  Running autogen.sh ..."
    ./autogen.sh 2>/dev/null || autoreconf -fi
  fi

  mkdir -p build_release && cd build_release
  ../configure \
    --with-x --with-readline=yes \
    --enable-xspice --enable-cider \
    --disable-debug \
    CFLAGS="-m64 -O2" LDFLAGS="-m64"
  make -j"$(nproc)"
  sudo make install
  sudo ldconfig
  ok "Ngspice : $(ngspice -v 2>&1 | head -1)"
fi

# ================================================================
# PHASE 3b — Magic VLSI from source
# ================================================================
phase "PHASE 3b : Magic VLSI (source build)"

if has_cmd magic; then
  skip "Magic : $(magic --version 2>&1 | head -1)"
else
  cd "$TOOLS_SRC"
  git_clone_or_pull https://github.com/RTimothyEdwards/magic.git magic
  cd magic
  ./configure
  make -j"$(nproc)"
  sudo make install
  ok "Magic : $(magic --version 2>&1 | head -1)"
fi

# ================================================================
# PHASE 3c — Netgen from source
# ================================================================
phase "PHASE 3c : Netgen (source build)"

if has_cmd netgen; then
  skip "Netgen"
else
  cd "$TOOLS_SRC"
  git_clone_or_pull https://github.com/RTimothyEdwards/netgen.git netgen
  cd netgen
  ./configure
  make -j"$(nproc)"
  sudo make install
  ok "Netgen : installed"
fi

# ================================================================
# PHASE 3d — Xschem from source
# ================================================================
phase "PHASE 3d : Xschem (source build)"

if has_cmd xschem; then
  skip "Xschem : $(xschem --version 2>&1 | head -1)"
else
  cd "$TOOLS_SRC"
  git_clone_or_pull https://github.com/StefanSchippers/xschem.git xschem
  cd xschem
  ./configure
  make -j"$(nproc)"
  sudo make install
  ok "Xschem : $(xschem --version 2>&1 | head -1)"
fi

# ================================================================
# PHASE 4a — OpenLane 2 (latest from GitHub, via pipx)
# ================================================================
phase "PHASE 4a : OpenLane 2 (latest from GitHub)"

if has_cmd openlane; then
  skip "OpenLane : $(openlane --version 2>&1 | head -1)"
else
  cd "$TOOLS_SRC"
  git_clone_or_pull https://github.com/efabless/openlane2.git openlane2
  cd openlane2

  if pipx list 2>/dev/null | grep -q "openlane"; then
    echo "  OpenLane in pipx — upgrading..."
    pipx upgrade openlane
  else
    pipx install .
  fi

  # Pin click<8.2.0 inside openlane venv to prevent cloup/IntEnumChoice crash
  pipx runpip openlane install "click<8.2.0" -q

  ok "OpenLane 2 : $(openlane --version 2>&1 | head -1)"
fi

# ================================================================
# PHASE 4b — Logisim Evolution
# ================================================================
phase "PHASE 4b : Logisim Evolution"

LOGISIM_JAR="$HOME/bin/logisim-evolution.jar"
if [ -f "$LOGISIM_JAR" ] && has_cmd logisim; then
  skip "Logisim Evolution"
else
  LOGISIM_VER="3.9.0"
  wget -q --show-progress -O "$LOGISIM_JAR" \
    "https://github.com/logisim-evolution/logisim-evolution/releases/download/v${LOGISIM_VER}/logisim-evolution-${LOGISIM_VER}-all.jar"

  cat > "$HOME/bin/logisim" << 'LOGISIM_LAUNCHER'
#!/bin/bash
java -jar "$HOME/bin/logisim-evolution.jar" "$@"
LOGISIM_LAUNCHER
  chmod +x "$HOME/bin/logisim"
  ok "Logisim Evolution $LOGISIM_VER → ~/bin/logisim"
fi

ok "Phase 4 complete"

# ================================================================
# PHASE 5 — SKY130A PDK via volare
# ================================================================
phase "PHASE 5 : SKY130A PDK via volare"
export PDK_ROOT="$HOME/pdk"

# Install volare via pipx (safe on Ubuntu 24.04)
if has_cmd volare; then
  skip "volare already installed"
else
  pipx install volare
fi

# Check if PDK already installed
if [ -d "$PDK_ROOT/sky130A/libs.tech" ]; then
  skip "SKY130A PDK already at $PDK_ROOT/sky130A"
else
  echo "  Fetching latest SKY130 version..."
  LATEST_VER=$(volare ls-remote --pdk sky130 --pdk-root "$PDK_ROOT" 2>/dev/null \
    | grep -v "^#\|^$" | head -1 | awk '{print $1}')

  if [ -z "$LATEST_VER" ]; then
    LATEST_VER="bdc9412b3e468c102d01b7cf6337be06ec6e9c9a"
    echo "  Auto-detect failed — using known stable version"
  fi

  echo "  Enabling SKY130A : $LATEST_VER"
  volare enable --pdk sky130 --pdk-root "$PDK_ROOT" "$LATEST_VER"
  ok "PDK installed at $PDK_ROOT/sky130A"
fi

ok "Phase 5 complete"

# ================================================================
# PHASE 6 — ~/.vlsi_env
# ================================================================
phase "PHASE 6 : Creating ~/.vlsi_env"

cat > "$HOME/.vlsi_env" << 'VLSI_ENV_EOF'
# ================================================================
#  ~/.vlsi_env  — VLSI Environment + SKY130A
#  Auto-sourced by ~/.bashrc on every WSL session
# ================================================================

export PDK_ROOT="$HOME/pdk"
export PDK="sky130A"
export PDK_PATH="$PDK_ROOT/$PDK"
export STD_CELL_LIBRARY="sky130_fd_sc_hd"
export PROCESS="sky130"
export PDKPATH="$PDK_ROOT"

# Auto-detect actual SPICE model file (path varies by PDK version)
_NG=$(find "$PDK_PATH/libs.tech/ngspice" -maxdepth 2 -name "*.lib.spice" 2>/dev/null | head -1)
export NGSPICE_MODELS="${_NG:-$PDK_PATH/libs.tech/ngspice/sky130.lib.spice}"

export XSCHEM_SKY130="$PDK_PATH/libs.tech/xschem"
export KLAYOUT_PATH="$PDK_PATH/libs.tech/klayout:${KLAYOUT_PATH:-}"
export LIBERTY="$PDK_PATH/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
export NETGEN_SETUP="$PDK_PATH/libs.tech/netgen/sky130A_setup.tcl"
export OPENLANE_PDK_ROOT="$PDK_ROOT"
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Windows 11 (WSLg)  → GUI works automatically, nothing needed
# Windows 10 (VcXsrv) → uncomment:
# export DISPLAY=$(grep -m1 nameserver /etc/resolv.conf | awk '{print $2}'):0.0
# export LIBGL_ALWAYS_INDIRECT=1

echo "[VLSI] SKY130A loaded → $PDK_PATH"
VLSI_ENV_EOF

ok "~/.vlsi_env created"

# ================================================================
# PHASE 7 — Per-tool config files
# ================================================================
phase "PHASE 7 : Per-tool config files"

# Magic
cat > "$HOME/.magicrc" << 'MAGICRC_EOF'
source $env(PDK_ROOT)/sky130A/libs.tech/magic/sky130A.magicrc
MAGICRC_EOF
ok "~/.magicrc → sky130A.magicrc"

# Xschem
mkdir -p "$HOME/.xschem"
cat > "$HOME/.xschem/xschemrc" << 'XSCHEMRC_EOF'
set XSCHEM_LIBRARY_PATH "$env(PDK_PATH)/libs.tech/xschem"
set user_lib "$env(HOME)/.xschem/xschem_library"
if {[file isdirectory $user_lib]} { append XSCHEM_LIBRARY_PATH ":$user_lib" }
set ngspice_models "$env(PDK_PATH)/libs.tech/ngspice"
XSCHEMRC_EOF
ok "~/.xschem/xschemrc → sky130A symbols"

# KLayout — find the .lyt file dynamically (path varies by PDK version)
mkdir -p "$HOME/.klayout/tech"
KLAYOUT_LYT=$(find "$PDK_ROOT/sky130A/libs.tech/klayout" \
  -maxdepth 3 -name "*.lyt" 2>/dev/null | head -1)
if [ -n "$KLAYOUT_LYT" ]; then
  ln -sf "$KLAYOUT_LYT" "$HOME/.klayout/tech/sky130A.lyt" 2>/dev/null || true
  ok "~/.klayout/tech/sky130A.lyt → $KLAYOUT_LYT"
else
  warn "KLayout .lyt not found yet — will be linked after PDK install"
fi

ok "Phase 7 complete"

# ================================================================
# PHASE 8 — ~/.bashrc
# ================================================================
phase "PHASE 8 : Updating ~/.bashrc"

BASHRC_TAG="# VLSI Tools — SKY130 Auto-Detect"
if ! grep -qF "$BASHRC_TAG" "$HOME/.bashrc"; then
  { echo ""; echo "$BASHRC_TAG"; echo 'source "$HOME/.vlsi_env"'; } >> "$HOME/.bashrc"
  ok "Added source line to ~/.bashrc"
else
  skip "~/.bashrc already patched"
fi

# ================================================================
# DONE — Summary
# ================================================================
echo ""
echo "========================================================"
echo -e "${GREEN}  ✅  Setup Complete! ${NC}"
echo "========================================================"
echo ""
echo "  NEXT STEP :  source ~/.bashrc"
echo ""
echo "  QUICK VERIFY:"
echo "    iverilog -V        → Icarus Verilog"
echo "    yosys --version    → Yosys"
echo "    ngspice -v         → Ngspice"
echo "    magic --version    → Magic VLSI"
echo "    xschem --version   → Xschem"
echo "    openlane --help    → OpenLane 2"
echo "    logisim            → Logisim GUI"
echo ""
echo "  PDK  : $PDK_ROOT/sky130A"
echo "  Log  : $LOGFILE"
echo ""
