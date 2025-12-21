#!/bin/bash

# DO THIS: chmod +x setup_comfyui.sh
set -e  # Exit immediately if a command exits with a non-zero status

echo "### 1. Cloning ComfyUI Repository..."
git clone https://github.com/comfyanonymous/ComfyUI.git
sleep 2

echo "### Entering ComfyUI directory..."
cd ComfyUI

echo "### 2. Creating Virtual Environment (.venv)..."
python -m venv .venv
sleep 1

echo "### Activating Virtual Environment..."
# This assumes you are using bash/zsh. 
source .venv/bin/activate
sleep 1

echo "### 3. Installing Requirements..."
echo "This may take a while..."
python -m pip install -r requirements.txt
sleep 2

echo "### 4. Starting Model Downloads..."
echo "--------------------------------------------"

# --- Text Encoder ---
echo "Downloading Text Encoder (Qwen 3.4B)..."
mkdir -p models/text_encoders
wget -c "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" -O models/text_encoders/qwen_3_4b.safetensors
sleep 1

# --- Diffusion Model ---
echo "Downloading Diffusion Model (BF16)..."
mkdir -p models/diffusion_models
wget -c "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" -O models/diffusion_models/z_image_turbo_bf16.safetensors
sleep 1

# --- LoRA ---
echo "Downloading Pixel Art LoRA..."
mkdir -p models/loras
wget -c "https://huggingface.co/tarn59/pixel_art_style_lora_z_image_turbo/resolve/main/pixel_art_style_z_image_turbo.safetensors" -O models/loras/pixel_art_style_z_image_turbo.safetensors
sleep 1

# --- VAE ---
echo "Downloading VAE..."
mkdir -p models/vae
wget -c "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" -O models/vae/ae.safetensors
sleep 1

echo "--------------------------------------------"
echo "Setup Complete! To run ComfyUI, type:"
echo "cd ComfyUI"
echo "source .venv/bin/activate"
echo "python main.py"
