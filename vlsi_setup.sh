#!/bin/bash
# ================================================================
#  VLSI Full Setup Script — WSL Ubuntu 24
#  Tools : Icarus Verilog, GTKWave, Yosys, KLayout, Ngspice,
#          Magic VLSI, Netgen, Xschem, OpenLane 2 (git/latest),
#          Logisim Evolution
#  PDK   : SkyWater SKY130A via volare
#
#  Run   : chmod +x vlsi_setup.sh && ./vlsi_setup.sh
#  After : source ~/.bashrc
# ================================================================

set -e
LOGFILE="$HOME/vlsi_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "========================================================"
echo "  VLSI Tools + SKY130 PDK — WSL Ubuntu 24 Setup"
echo "  Log → $LOGFILE"
echo "========================================================"

# ── Global paths ──────────────────────────────────────────────
PDK_ROOT="$HOME/pdk"          # SKY130 will live here
TOOLS_SRC="$HOME/vlsi-src"   # Source build workspace
mkdir -p "$PDK_ROOT" "$TOOLS_SRC" "$HOME/bin"

# ================================================================
# PHASE 1 — System dependencies
# ================================================================
echo ""
echo "── PHASE 1 : System dependencies ──────────────────────"
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  build-essential git curl wget \
  python3 python3-pip python3-venv python3-dev \
  tcl tcl-dev tk tk-dev \
  libx11-dev libxext-dev libxft-dev libxrender-dev \
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
  xdg-utils

echo "✓ Phase 1 complete"

# ================================================================
# PHASE 2 — APT-installable tools
# ================================================================
echo ""
echo "── PHASE 2 : APT tools (iverilog, gtkwave, yosys, klayout) ─"

sudo apt install -y iverilog
echo "  ✓ Icarus Verilog : $(iverilog -V 2>&1 | head -1)"

sudo apt install -y gtkwave
echo "  ✓ GTKWave        : installed"

sudo apt install -y yosys
echo "  ✓ Yosys          : $(yosys --version 2>&1 | head -1)"

# KLayout — try apt first, fall back to .deb download
if sudo apt install -y klayout 2>/dev/null; then
  echo "  ✓ KLayout        : $(klayout -v 2>&1 | head -1)"
else
  echo "  klayout not in apt — downloading latest .deb ..."
  KLAYOUT_DEB=$(curl -s https://api.github.com/repos/KLayout/klayout/releases/latest \
    | grep "browser_download_url.*amd64.deb" | head -1 \
    | cut -d '"' -f 4)
  wget -O /tmp/klayout.deb "$KLAYOUT_DEB"
  sudo dpkg -i /tmp/klayout.deb || sudo apt-get install -f -y
  echo "  ✓ KLayout        : installed via .deb"
fi

echo "✓ Phase 2 complete"

# ================================================================
# PHASE 3a — Ngspice from source  (GitHub release, auto-latest)
# ================================================================
echo ""
echo "── PHASE 3a : Ngspice (source build) ───────────────────"
cd "$TOOLS_SRC"

# ── Auto-detect latest stable Ngspice release from GitHub ─────
echo "  Fetching latest Ngspice version from GitHub..."
NGSPICE_TAG=$(curl -fsSL "https://api.github.com/repos/ngspice/ngspice/releases/latest" \
  | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/')

# tag is typically  "ngspice-44"  → strip prefix to get the number
NGSPICE_VER="${NGSPICE_TAG#ngspice-}"

if [ -z "$NGSPICE_VER" ]; then
  NGSPICE_VER="44"
  NGSPICE_TAG="ngspice-44"
  echo "  GitHub lookup failed — falling back to Ngspice $NGSPICE_VER"
fi
echo "  Latest Ngspice : $NGSPICE_TAG  (ver $NGSPICE_VER)"

# ── Download tarball from GitHub releases ─────────────────────
NGSPICE_URL="https://github.com/ngspice/ngspice/releases/download/${NGSPICE_TAG}/ngspice-${NGSPICE_VER}.tar.gz"
echo "  Downloading: $NGSPICE_URL"
wget --show-progress -O ngspice.tar.gz "$NGSPICE_URL" 2>&1

# ── If tarball missing / 404, fall back to git clone ──────────
if [ ! -s ngspice.tar.gz ]; then
  echo "  Tarball unavailable — cloning from GitHub (git fallback)..."
  rm -f ngspice.tar.gz
  git clone --depth=1 https://github.com/ngspice/ngspice.git "ngspice-${NGSPICE_VER}"
  cd "ngspice-${NGSPICE_VER}"
  # Git clone needs autoconf bootstrap
  ./autogen.sh 2>/dev/null || autoreconf -fi
else
  tar xzf ngspice.tar.gz
  # Tarball may extract as  ngspice-44  or  ngspice-ngspice-44  — handle both
  NGSPICE_DIR=$(tar tzf ngspice.tar.gz 2>/dev/null | head -1 | cut -d/ -f1 || echo "ngspice-${NGSPICE_VER}")
  cd "${NGSPICE_DIR:-ngspice-${NGSPICE_VER}}"
fi

mkdir -p release && cd release
../configure \
  --with-x --with-readline=yes \
  --enable-xspice --enable-cider \
  --disable-debug \
  CFLAGS="-m64 -O2" LDFLAGS="-m64"
make -j"$(nproc)"
sudo make install
sudo ldconfig
echo "  ✓ Ngspice : $(ngspice -v 2>&1 | head -1)"

# ================================================================
# PHASE 3b — Magic VLSI from source
# ================================================================
echo ""
echo "── PHASE 3b : Magic VLSI (source build) ─────────────────"
cd "$TOOLS_SRC"
git clone https://github.com/RTimothyEdwards/magic.git
cd magic
./configure
make -j"$(nproc)"
sudo make install
echo "  ✓ Magic   : $(magic --version 2>&1 | head -1)"

# ================================================================
# PHASE 3c — Netgen from source
# ================================================================
echo ""
echo "── PHASE 3c : Netgen (source build) ─────────────────────"
cd "$TOOLS_SRC"
git clone https://github.com/RTimothyEdwards/netgen.git
cd netgen
./configure
make -j"$(nproc)"
sudo make install
echo "  ✓ Netgen  : installed"

# ================================================================
# PHASE 3d — Xschem from source
# ================================================================
echo ""
echo "── PHASE 3d : Xschem (source build) ─────────────────────"
cd "$TOOLS_SRC"
git clone https://github.com/StefanSchippers/xschem.git
cd xschem
./configure
make -j"$(nproc)"
sudo make install
echo "  ✓ Xschem  : $(xschem --version 2>&1 | head -1)"

# ================================================================
# PHASE 4a — OpenLane 2  (latest from GitHub)
# ================================================================
echo ""
echo "── PHASE 4a : OpenLane 2 (latest from GitHub) ───────────"

# Ensure pipx is available (cleaner isolated install)
pip3 install --upgrade pip pipx
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"

# Always pull the very latest commit from the main branch
cd "$TOOLS_SRC"
if [ -d "openlane2" ]; then
  echo "  Existing openlane2 clone found — pulling latest..."
  cd openlane2
  git pull --ff-only
else
  echo "  Cloning OpenLane 2 from GitHub..."
  git clone --depth=1 https://github.com/efabless/openlane2.git
  cd openlane2
fi

# Install (or upgrade) into an isolated pipx environment
echo "  Installing OpenLane 2 via pipx (isolated env)..."
pipx install --pip-args="--upgrade" . 2>/dev/null \
  || pipx upgrade openlane 2>/dev/null \
  || pip3 install --upgrade .

echo "  ✓ OpenLane 2 : $(openlane --version 2>&1 | head -1)"

# ================================================================
# PHASE 4b — Logisim Evolution
# ================================================================
echo ""
echo "── PHASE 4b : Logisim Evolution ────────────────────────"
LOGISIM_VER="3.9.0"
wget -O "$HOME/bin/logisim-evolution.jar" \
  "https://github.com/logisim-evolution/logisim-evolution/releases/download/v${LOGISIM_VER}/logisim-evolution-${LOGISIM_VER}-all.jar"

cat > "$HOME/bin/logisim" << 'LOGISIM_LAUNCHER'
#!/bin/bash
java -jar "$HOME/bin/logisim-evolution.jar" "$@"
LOGISIM_LAUNCHER
chmod +x "$HOME/bin/logisim"
echo "  ✓ Logisim Evolution $LOGISIM_VER → ~/bin/logisim"

echo "✓ Phase 4 complete"

# ================================================================
# PHASE 5 — SKY130A PDK via volare
# ================================================================
echo ""
echo "── PHASE 5 : SKY130A PDK via volare ─────────────────────"
pip3 install --upgrade volare

export PDK_ROOT="$HOME/pdk"

echo "  Fetching available SKY130 versions..."
LATEST_VER=$(volare ls-remote --pdk sky130 --pdk-root "$PDK_ROOT" 2>/dev/null \
  | grep -v "^#\|^$" | head -1 | awk '{print $1}')

if [ -z "$LATEST_VER" ]; then
  # Fallback to a known stable hash if network lookup fails
  LATEST_VER="bdc9412b3e468c102d01b7cf6337be06ec6e9c9a"
  echo "  Auto-detect failed — using known stable version"
fi

echo "  Enabling SKY130 : $LATEST_VER"
volare enable --pdk sky130 --pdk-root "$PDK_ROOT" "$LATEST_VER"

echo "  ✓ PDK installed at : $PDK_ROOT/sky130A"
echo "✓ Phase 5 complete"

# ================================================================
# PHASE 6 — Create ~/.vlsi_env  (the auto-source file)
# ================================================================
echo ""
echo "── PHASE 6 : Creating ~/.vlsi_env ───────────────────────"

# NOTE: single-quote the heredoc delimiter so $vars are written
#       literally (they expand at shell-source time, not now).
cat > "$HOME/.vlsi_env" << 'VLSI_ENV_EOF'
# ================================================================
#  ~/.vlsi_env  — VLSI Environment + SKY130A Auto-Detection
#  Auto-sourced by ~/.bashrc on every WSL session
#
#  PDK structure:
#    $PDK_ROOT/sky130A/libs.tech/magic/      ← Magic tech files
#    $PDK_ROOT/sky130A/libs.tech/ngspice/    ← SPICE models
#    $PDK_ROOT/sky130A/libs.tech/xschem/     ← Xschem symbols
#    $PDK_ROOT/sky130A/libs.tech/netgen/     ← Netgen LVS setup
#    $PDK_ROOT/sky130A/libs.tech/klayout/    ← KLayout DRC/LVS
#    $PDK_ROOT/sky130A/libs.ref/             ← Std-cell libraries
# ================================================================

# ── PDK Core ──────────────────────────────────────────────────
export PDK_ROOT="$HOME/pdk"
export PDK="sky130A"
export PDK_PATH="$PDK_ROOT/$PDK"
export STD_CELL_LIBRARY="sky130_fd_sc_hd"
export PROCESS="sky130"

# ── Magic VLSI ────────────────────────────────────────────────
# PDKPATH → Magic auto-loads $PDKPATH/sky130A/libs.tech/magic/
# .magicrc then calls sky130A.magicrc for tech + startup
export PDKPATH="$PDK_ROOT"

# ── Ngspice ───────────────────────────────────────────────────
# In your SPICE netlists, include models with:
#   .lib "$NGSPICE_MODELS" tt        (TT corner)
#   .lib "$NGSPICE_MODELS" ff        (FF corner)
#   .lib "$NGSPICE_MODELS" ss        (SS corner)
export NGSPICE_MODELS="$PDK_PATH/libs.tech/ngspice/sky130.lib.spice"

# ── Xschem ───────────────────────────────────────────────────
# xschemrc in ~/.xschem/ picks this up for symbol libraries
export XSCHEM_SKY130="$PDK_PATH/libs.tech/xschem"

# ── KLayout ───────────────────────────────────────────────────
export KLAYOUT_PATH="$PDK_PATH/libs.tech/klayout:${KLAYOUT_PATH:-}"

# ── Yosys (Liberty file for synthesis) ────────────────────────
export LIBERTY="$PDK_PATH/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# ── Netgen ────────────────────────────────────────────────────
# LVS run: netgen -batch source $NETGEN_SETUP
export NETGEN_SETUP="$PDK_PATH/libs.tech/netgen/sky130A_setup.tcl"

# ── OpenLane 2 ────────────────────────────────────────────────
export OPENLANE_PDK_ROOT="$PDK_ROOT"

# ── PATH ──────────────────────────────────────────────────────
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# ── Display — WSL2/WSLg ───────────────────────────────────────
# Windows 11 (WSLg): GUI launches automatically — nothing needed.
# Windows 10 (VcXsrv): uncomment the two lines below:
# export DISPLAY=$(grep -m1 nameserver /etc/resolv.conf | awk '{print $2}'):0.0
# export LIBGL_ALWAYS_INDIRECT=1

# ── Confirm ───────────────────────────────────────────────────
echo "[VLSI] SKY130A loaded → $PDK_PATH"
VLSI_ENV_EOF

echo "  ✓ ~/.vlsi_env created"

# ================================================================
# PHASE 7 — Per-tool SKY130 config files
# ================================================================
echo ""
echo "── PHASE 7 : Per-tool config files ──────────────────────"

# ── Magic : ~/.magicrc ────────────────────────────────────────
cat > "$HOME/.magicrc" << 'MAGICRC_EOF'
# Magic VLSI startup — load SKY130A technology
# Requires PDK_ROOT env var (set in ~/.vlsi_env)
source $env(PDK_ROOT)/sky130A/libs.tech/magic/sky130A.magicrc
MAGICRC_EOF
echo "  ✓ ~/.magicrc         → sky130A.magicrc auto-loaded"

# ── Xschem : ~/.xschem/xschemrc ──────────────────────────────
mkdir -p "$HOME/.xschem"
cat > "$HOME/.xschem/xschemrc" << 'XSCHEMRC_EOF'
# Xschem startup config — SKY130A symbol/model libraries
# Requires PDK_PATH env var (set in ~/.vlsi_env)

# SKY130 device symbols
set XSCHEM_LIBRARY_PATH "$env(PDK_PATH)/libs.tech/xschem"

# Your personal symbol library (create if needed)
set user_lib "$env(HOME)/.xschem/xschem_library"
if {[file isdirectory $user_lib]} {
    append XSCHEM_LIBRARY_PATH ":$user_lib"
}

# SPICE model include (Ngspice)
set ngspice_models "$env(PDK_PATH)/libs.tech/ngspice"
XSCHEMRC_EOF
echo "  ✓ ~/.xschem/xschemrc → sky130A symbols linked"

# ── KLayout : tech file symlink ───────────────────────────────
mkdir -p "$HOME/.klayout/tech"
KLAYOUT_LYT="$PDK_ROOT/sky130A/libs.tech/klayout/sky130A.lyt"
if [ -f "$KLAYOUT_LYT" ]; then
  ln -sf "$KLAYOUT_LYT" "$HOME/.klayout/tech/sky130A.lyt" 2>/dev/null || true
  echo "  ✓ ~/.klayout/tech/   → sky130A.lyt symlinked"
fi

echo "✓ Phase 7 complete"

# ================================================================
# PHASE 8 — Add source to ~/.bashrc
# ================================================================
echo ""
echo "── PHASE 8 : Updating ~/.bashrc ─────────────────────────"

BASHRC_TAG="# VLSI Tools — SKY130 Auto-Detect"
if ! grep -qF "$BASHRC_TAG" "$HOME/.bashrc"; then
  {
    echo ""
    echo "$BASHRC_TAG"
    echo 'source "$HOME/.vlsi_env"'
  } >> "$HOME/.bashrc"
  echo "  ✓ Added to ~/.bashrc"
else
  echo "  ~/.bashrc already has the source line — skipped"
fi

# ================================================================
# DONE
# ================================================================
echo ""
echo "========================================================"
echo "  Setup Complete!"
echo "========================================================"
echo ""
echo "  NEXT STEPS:"
echo "  1.  source ~/.bashrc"
echo ""
echo "  QUICK VERIFY:"
echo "  echo \$PDK_PATH          → $HOME/pdk/sky130A"
echo "  iverilog -V              → Icarus version"
echo "  yosys --version          → Yosys version"
echo "  ngspice -v               → Ngspice version"
echo "  magic                    → opens with sky130A tech"
echo "  xschem                   → opens with sky130 symbols"
echo "  klayout                  → open → File → Technologies"
echo "  logisim                  → Logisim Evolution GUI"
echo "  openlane --help          → OpenLane 2 CLI"
echo ""
echo "  PDK location : $PDK_ROOT/sky130A"
echo "  Source file  : $HOME/.vlsi_env"
echo "  Log file     : $LOGFILE"
echo ""
