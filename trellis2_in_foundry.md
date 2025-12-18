### Phase 1: The Foundation (Maestro / Conda)

Start with a fresh Conda environment. You need the **compilers** and **CUDA Toolkit** here so they are visible to the system.

**If editing `meta.yaml`:**

```yaml
requirements:
  run:
    - python 3.10
    - conda-forge::gxx_linux-64        # The C++ Compiler
    - conda-forge::sysroot_linux-64    # System headers
    - nvidia::cuda-toolkit 12.4.* # The FULL toolkit (nvcc + headers)
    - conda-forge::eigen               # Math library (Required for CuMesh/o-voxel)

```

**Or via command line (once env is active):**

```bash
conda install -c nvidia -c conda-forge \
    python=3.10 \
    cuda-toolkit=12.4 \
    gxx_linux-64=11.* \
    sysroot_linux-64=2.17 \
    eigen

```

---

### Phase 2: Setup Venv & "Magic Variables"

This block fixes 99% of the build errors (`missing cuda_runtime.h`, `cannot find -lcuda`, `missing Eigen`).

**Copy-paste this entire block into your terminal:**

```bash
# 1. Create and Activate Venv
python -m venv .venv
source .venv/bin/activate

# 2. Link System Tools to Venv
# (Appends Conda bin to path so venv python is first, but nvcc is visible)
export PATH=$PATH:$CONDA_PREFIX/bin
export CUDA_HOME=$CONDA_PREFIX

# 3. THE MAGIC VARIABLES (Fixes header/linker detection)
#    - CPATH: Forces compiler to find CUDA headers (hidden in targets/) and Eigen
#    - LIBRARY_PATH: Forces linker to find CUDA stubs (fixes -lcuda)
export CPATH=$CONDA_PREFIX/targets/x86_64-linux/include:$CONDA_PREFIX/include:$CONDA_PREFIX/include/eigen3:$CPATH
export LIBRARY_PATH=$CONDA_PREFIX/targets/x86_64-linux/lib:$CONDA_PREFIX/targets/x86_64-linux/lib/stubs:$LIBRARY_PATH
export LD_LIBRARY_PATH=$CONDA_PREFIX/targets/x86_64-linux/lib:$LD_LIBRARY_PATH

```

---

### Phase 3: Core Dependencies

Install PyTorch and the build tools first.

```bash
# 1. Install PyTorch (Matches CUDA 12.4)
python -m pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124

# 2. Install Build Helpers
python -m pip install ninja psutil packaging wheel setuptools

# 3. Install Standard Libraries
python -m pip install imageio imageio-ffmpeg tqdm easydict opencv-python-headless trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard kornia timm rembg

# 4. Install Git Dependencies
python -m pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8

```

---

### Phase 4: Flash Attention (The Heavy Compile)

We install this alone to ensure it grabs the correct CUDA paths.

```bash
# MAX_JOBS=4 prevents running out of RAM on the A10G
MAX_JOBS=4 python -m pip install flash-attn==2.7.3 --no-build-isolation --no-cache-dir

```

---

### Phase 5: The Extensions (With Symlink Surgery)

This handles the custom research code. We clone them locally and fix the missing `Eigen` dependency manually since git submodules are blocked.

```bash
mkdir -p extensions
cd extensions

# --- 1. Nvdiffrast & Nvdiffrec (Standard Install) ---
git clone -b v0.4.0 https://github.com/NVlabs/nvdiffrast.git
python -m pip install ./nvdiffrast --no-build-isolation

git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git
python -m pip install ./nvdiffrec --no-build-isolation

# --- 2. FlexGEMM (Standard Install) ---
git clone https://github.com/JeffreyXiang/FlexGEMM.git
python -m pip install ./FlexGEMM --no-build-isolation

# --- 3. CuMesh (The "Symlink Surgery") ---
git clone https://github.com/JeffreyXiang/CuMesh.git
# Manually link the system Eigen to where CuMesh expects it
rm -rf CuMesh/third_party/cubvh/third_party/eigen
ln -s $CONDA_PREFIX/include/eigen3 CuMesh/third_party/cubvh/third_party/eigen
# Now install
python -m pip install ./CuMesh --no-build-isolation

cd .. # Back to Repo Root

```

---

### Phase 6: The Final Boss (`o-voxel`)

This package has the same `Eigen` issue as CuMesh.

```bash
# 1. Perform Symlink Surgery
rm -rf o-voxel/third_party/eigen
ln -s $CONDA_PREFIX/include/eigen3 o-voxel/third_party/eigen

# 2. Install (No Deps flag prevents it from trying to re-download cumesh)
python -m pip install ./o-voxel --no-build-isolation --no-deps

```

---

### Phase 7: Verification & Run

Run the smoke test with the special flags to bypass the XetHub firewall block.

```bash
# 1. Export your HF Token (Required for DinoV3 / RMBG)
export HF_TOKEN="hf_YourTokenHere..."

# 2. Run the test with Xet Disabled
HF_HUB_DISABLE_XET=1 python smoke-test.py

```

If you see `✅ Generation Complete`, you have won.
