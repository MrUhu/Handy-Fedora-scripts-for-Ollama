## Overview
These scripts are designed to upgrade system packages, update Ollama, and configure AMD GPU memory settings for improved performance on local LLMs provided by Ollama.

***They are tested and used for Fedora Linux - please adjust for other distributions***

## What Each Script Accomplishes

### `update.sh`

#### Description
When the ollama update is run, all set environment variables are deleted.
Also, the update script is rather dumb and always updates even if Ollama is up-to-date.
This script first runs a full system update and ensures everything is up an running on the Ollama side.

1. **System Package Updates**: 
   - Upgrades all installed packages using `dnf upgrade`
   - Updates all system packages with `dnf update -y`

2. **Ollama Version Management**:
   - Checks for latest Ollama version on GitHub
   - Compares current local version with latest release
   - If versions differ, downloads and installs the latest Ollama version

3. **GPU Configuration**:
   - Sets environment variable `HSA_OVERRIDE_GFX_VERSION=11.0.2` for Ollama service
   - Sets `OLLAMA_KV_CACHE_TYPE=q4_0` to optimize cache usage
   - Sets `OLLAMA_NUM_PARALLEL=3` to control parallelism if coding, embedding and autocompletion models are executed
   - Sets `OLLAMA_MAX_LOADED_MODELS=3` to set max loaded models to 3
   - Reloads systemd configuration and restarts Ollama service

4. **Model Updates**:
   - Updates all installed Ollama models to their latest versions

### `change_grubby_args_for_amd_igpu.sh`

#### Description
This script changes the size of the GTT memory assigned to the AMD iGPU, but limits the size to half of the available system memory - this can be overwritten to 90% of system memory.
If Ollama or AMD ROCm introduce no bugs that impact memory handling - the available LLM memory will be vRAM+GTT.
Works with Ollama 0.13.0.

1. **GTT Memory Configuration**:
   - Calculates required GTT (Graphics Transfer Table) memory size based on user input
   - Checks current amdgpu memory configuration in dmesg output

2. **Parameter Adjustment**:
   - If GTT memory values don't match, updates kernel parameters with `amdttm.pages_limit` and `amdttm.page_pool_size`
   - When the GTT memory is set: `amdgpu.cwsr_enable=0` will also be set to possibly decrease crashes
   - Applies changes using `grubby` command

3. **Backup & Logging**:
   - Saves amdgpu memory dmesg output for backup
   - Provides detailed status information about configuration changes

4. **System Reboot**:
   - For the changes to take effect - the system will be rebooted

### `overwrite_gpu_restriction_to_modelfiles.sh`

#### Description
This script modifies Ollama model files to include a `num_gpu` parameter based on the layer count of each model.
Sometimes it is necessary to force Ollama to use the whole memory available to the iGPU (vRAM+GTT).
This script creates modelfiles for all models installed on the system and adds these models with a "my" prefix to Ollama.
May or may not work - use at your own risk.

1. **Directory Setup**:
   - Ensures a directory named `models` exists to store modelfiles.

2. **Model Processing**:
   - Retrieves the list of installed Ollama models.
   - For each model, it extracts the model name and generates a new model name with a `my` prefix.

3. **Modelfile Generation**:
   - For each model, it exports the modelfile using `ollama show`.
   - It then fetches information from the Ollama library to determine the layer count of the model.

4. **Parameter Injection**:
   - Removes the original `FROM` line from the modelfile.
   - Adds a new `FROM` statement to recreate the model.
   - Injects a `num_gpu` parameter into the modelfile, using the layer count.

5. **Model Recreation**:
   - Uses the modified modelfile to create a new model with the `num_gpu` restriction.
   - This allows better GPU memory management for models when running locally.

## Important Notes
- These scripts were generated with the help of local AI (Qwen3-Coder 30b)
- These scripts were tested and will work on Fedora 42
- Usage at your own risk
- Requires root privileges to execute properly

## Usage
To apply all changes, run scripts with appropriate permissions, e.g.:
```bash
chmod +x update.sh change_gtt_size_for_amd_igpu.sh overwrite_gpu_restriction_to_modelfiles.sh
./update.sh
./overwrite_gpu_restriction_to_modelfiles.sh
./change_gtt_size_for_amd_igpu.sh
```