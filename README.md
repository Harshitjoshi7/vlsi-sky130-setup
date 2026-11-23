# 🔬 VLSI SKY130 Setup — WSL Ubuntu 24

> One-script installer for a complete open-source VLSI toolchain + SkyWater SKY130A PDK on **WSL Ubuntu 24**.

---

## ⚡ Quick Install (any PC)

```bash
# 1. Clone the repo
git clone https://github.com/Harshitjoshi7/vlsi-sky130-setup.git
cd vlsi-sky130-setup

# 2. Make executable & run
chmod +x vlsi_setup.sh
./vlsi_setup.sh

# 3. Reload environment
source ~/.bashrc
```

> **Requires:** WSL 2 with Ubuntu 24.04 installed on Windows.  
> The script logs everything to `~/vlsi_install.log`.

---

## 🛠️ Tools Installed

| Tool | Version | Method |
|------|---------|--------|
| **Icarus Verilog** | Latest APT | `apt` |
| **GTKWave** | Latest APT | `apt` |
| **Yosys** | Latest APT | `apt` |
| **KLayout** | Latest | `apt` → `.deb` fallback |
| **Ngspice** | 43 | Built from source |
| **Magic VLSI** | Latest | Built from source (GitHub) |
| **Netgen** | Latest | Built from source (GitHub) |
| **Xschem** | Latest | Built from source (GitHub) |
| **OpenLane 2** | ⭐ Latest (HEAD) | Cloned from GitHub + `pipx` |
| **Logisim Evolution** | 3.9.0 | JAR download |
| **SKY130A PDK** | Latest | `volare` |

### 🆕 OpenLane 2 — always the latest from GitHub

The script clones [`efabless/openlane2`](https://github.com/efabless/openlane2) directly and installs it via `pipx`, so you always get the **newest commit** instead of a potentially stale PyPI release.

```bash
# To update OpenLane 2 later without re-running the full script:
cd ~/vlsi-src/openlane2
git pull
pipx upgrade openlane
```

---

## 📂 Repository Structure

```
vlsi-sky130-setup/
├── vlsi_setup.sh       ← Main installer script (fully idempotent)
├── verify.sh           ← Comprehensive 30+ health-check test suite
├── synth_sky130.sh     ← Quick Yosys + SKY130 synthesis & GUI schematic script
├── run_openlane.sh     ← OpenLane 2 runner (synthesis or full RTL-to-GDS)
├── examples/
│   └── and_gate/       ← Ready-to-run AND gate design for OpenLane
│       ├── config.json
│       └── src/and_gate.v
├── README.md           ← Documentation
└── .gitignore
```

---

## 🚀 Running OpenLane 2 (RTL to GDS II)

OpenLane automates the entire ASIC flow from Verilog RTL all the way to tape-out-ready GDS II.

An example `and_gate` design is already included under `examples/and_gate`.

### Option A: Using the helper script

```bash
# 1. Run Synthesis only
./run_openlane.sh examples/and_gate --synth

# 2. Run Full RTL to GDS II
./run_openlane.sh examples/and_gate
```

### Option B: Using the `openlane` command directly

```bash
# Full flow (Floorplanning, Placement, CTS, Routing, Signoff)
openlane examples/and_gate

# Synthesis only (stops right after Yosys)
openlane examples/and_gate --to Yosys.Synthesis
```

### Inspecting outputs
- All flow artifacts are placed in `examples/and_gate/runs/<timestamp_run>/`
- Synthesized gate-level netlist: `runs/<run>/final/nl/and_gate.nl.v`
- Final GDS II layout: `runs/<run>/final/gds/and_gate.gds`
- To view the final chip layout in KLayout:
  ```bash
  klayout examples/and_gate/runs/<run_tag>/final/gds/and_gate.gds
  ```

---

## 📋 Prerequisites

| Requirement | How to get it |
|-------------|--------------|
| Windows 10/11 | — |
| WSL 2 | `wsl --install` in PowerShell (Admin) |
| Ubuntu 24.04 | Microsoft Store → "Ubuntu 24.04 LTS" |
| Internet access | Required for downloads |
| ≥ 20 GB free disk | For tools + PDK |

---

## 🗂️ What Gets Installed Where

```
~/pdk/sky130A/          ← SkyWater SKY130A PDK (via volare)
~/vlsi-src/             ← Source build workspace
│   ├── ngspice-43/
│   ├── magic/
│   ├── netgen/
│   ├── xschem/
│   └── openlane2/      ← OpenLane 2 git clone
~/bin/logisim           ← Logisim launcher script
~/.vlsi_env             ← All PDK env-vars (auto-sourced)
~/.magicrc              ← Magic SKY130A auto-load
~/.xschem/xschemrc      ← Xschem SKY130A symbols
~/.klayout/tech/        ← KLayout tech file symlink
```

---

## ✅ Post-Install Verification

```bash
source ~/.bashrc

echo $PDK_PATH           # → /home/<user>/pdk/sky130A
iverilog -V              # → Icarus Verilog version
yosys --version          # → Yosys version
ngspice -v               # → Ngspice version
magic --version          # → Magic version
xschem --version         # → Xschem version
openlane --help          # → OpenLane 2 CLI help
logisim                  # → Launches Logisim GUI
```

---

## 🖥️ GUI / Display (WSL)

| Windows version | Setup needed |
|----------------|-------------|
| **Windows 11** | ✅ Nothing — WSLg handles it automatically |
| **Windows 10** | Install [VcXsrv](https://sourceforge.net/projects/vcxsrv/), then uncomment the `DISPLAY` lines in `~/.vlsi_env` |

---

## 🔄 Re-running / Updating

The script is **idempotent** for most steps:
- `git clone` steps will fail safely if the directory already exists (rename `~/vlsi-src/<tool>` to force a fresh build).
- For **OpenLane 2** specifically, re-running the script will `git pull` the latest and upgrade.

---

## 📄 License

MIT — free to use, fork, and share.
