# Air-Gapped Nerfstudio Installation Guide (Foundry/Enterprise Linux)

**Target Environment:** Palantir Foundry (or similar enterprise air-gapped container)
**Hardware:** NVIDIA L4 GPU
**Python Version:** 3.11 (Pinned)

## 1. Infrastructure Setup (`meta.yaml`)

The critical first step is ensuring the Conda environment provides the necessary CUDA development headers, which are split into separate packages in CUDA 12.

**Action:** Update your `meta.yaml` to include the following dependencies.

```yaml
package:
  name: '{{ PACKAGE_NAME }}'
  version: '{{ PACKAGE_VERSION }}'
source:
  path: ../src
requirements:
  run:
  # --- Core Build Tools ---
  - ipykernel
  - pip
  - cmake
  - ninja
  - pkg-config
  - python=3.11                  # CRITICAL: Must be pinned. Changing this breaks compiled binaries.
  - gcc_linux-64=13.* # Modern GCC required for CUDA 12
  - gxx_linux-64=13.*

  # --- CUDA 12 Toolchain ---
  - cuda-nvcc                    # The Compiler
  - cuda-nvrtc                   # Runtime Compilation
  - cuda-cudart-dev              # Runtime Headers
  - cuda-nvrtc-dev

  # --- CRITICAL MISSING HEADERS (The "Split" Packages) ---
  - libcusparse-dev              # Sparse Matrix headers
  - libcublas-dev                # BLAS headers
  - libcusolver-dev              # Solver headers
  - libcurand-dev                # Random number headers
  - libcufft-dev                 # FFT headers

  # --- PyTorch Stack ---
  - pytorch==2.1.2               # Pinning PyTorch is recommended for stability
  - torchvision>=0.16.2
  - matplotlib
  
  # Note: Do NOT add 'nerfstudio' here. We install it via pip to control the build.

```

---

## 2. Compiling Tiny-CUDA-NN (The Core)

We must compile `tiny-cuda-nn` from source because pre-built wheels often fail on enterprise Linux setups with specific GPU architectures (L4).

**Location:** `~/repo/tiny-cuda-nn` (Ensure this is cloned recursively)

**Manual Build Command:**

```bash
# 1. Enter the bindings directory
cd ~/repo/tiny-cuda-nn/bindings/torch

# 2. Point CUDA_HOME to the Conda environment (CRITICAL)
export CUDA_HOME=$CONDA_PREFIX

# 3. Clean previous artifacts to prevent bad linking
rm -rf build/ dist/ tinycudann.egg-info/

# 4. Compile with full verbose output
# --no-build-isolation: Uses the Conda environment's packages instead of a temp venv
python -m pip install . --no-build-isolation --verbose

```

**Verification:**

* **Do NOT** run the verification check inside `bindings/torch`.
* Move to `~/repo` and run: `python -c "import tinycudann; print('Success')"`

---

## 3. Installing Nerfstudio (The App)

Once TCNN is compiled, install Nerfstudio using `pip`. It will detect the existing TCNN installation and skip building it.

```bash
# Install Nerfstudio (skipping dependencies if already present)
python -m pip install nerfstudio

```

---

## 4. Recovery Script (Persistence)

Since the environment resets on restart (wiping `pip` packages), save this script as `~/repo/restore_env.sh` to quickly rebuild the environment.

```bash
#!/bin/bash
# restore_env.sh - One-click recovery for Foundry

echo "🚀 Starting Environment Restoration..."

# 1. Setup Environment Variables
export CUDA_HOME=$CONDA_PREFIX

# 2. Check for TCNN Source
if [ -d "$HOME/repo/tiny-cuda-nn/bindings/torch" ]; then
    echo "⚙️ Re-installing Tiny-CUDA-NN..."
    cd "$HOME/repo/tiny-cuda-nn/bindings/torch"
    # This is fast if build artifacts survived; slow if not.
    python -m pip install . --no-build-isolation
    cd "$HOME/repo"
else
    echo "❌ CRITICAL: tiny-cuda-nn source not found in ~/repo"
    exit 1
fi

# 3. Install Nerfstudio
echo "📦 Installing Nerfstudio..."
python -m pip install nerfstudio

echo "✅ Restoration Complete."

```

---

## 5. Troubleshooting Common Errors

### "No module named tinycudann" immediately after install

* **Cause:** You are trying to import the package while standing inside the source folder.
* **Fix:** `cd ~/repo` (move out of the `bindings/torch` directory).

### "Undefined symbol: _ZN5torch3jit..."

* **Cause:** A harmless warning from `torchvision` looking for a C++ extension for JPEG loading.
* **Fix:** Ignore it. Nerfstudio uses Pillow/OpenCV, so this does not affect functionality.

### "Name or service not known" (AlexNet Download Error)

* **Cause:** Nerfstudio tries to download the AlexNet model for LPIPS metrics at runtime, but the environment is air-gapped.
* **Fix:** Whitelist `download.pytorch.org` on the network egress policy, OR monkey-patch the `LearnedPerceptualImagePatchSimilarity` class in Python to skip the download.
