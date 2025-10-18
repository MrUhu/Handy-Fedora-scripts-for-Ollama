#!/bin/bash
echo "Upgrade the packages"
sudo dnf upgrade -y

echo "Updating all system packages"
sudo dnf update -y

# Get latest version from GitHub API
latest_version=$(curl -s https://api.github.com/repos/ollama/ollama/releases/latest | grep -Po '"tag_name": "\K[^"]*')

echo "Latest version from GitHub: $latest_version"

# Get current local version
if command -v ollama &> /dev/null; then
    current_version=$(ollama --version 2>&1 | grep -Po 'ollama version is \K.*')
    echo "Current version: $current_version"
else
    echo "Ollama not found, setting to empty"
    current_version=""
fi

# Remove 'v' prefix from latest version for comparison
clean_latest=$(echo "$latest_version" | sed 's/^v//')

echo "Clean latest version: $clean_latest"

# Compare versions
if [ "$clean_latest" = "$current_version" ]; then
    echo "Versions match: $current_version"
    echo "Skipping Ollama Update"
else
    echo "Versions don't match - GitHub: $latest_version, Local: $current_version"
    echo "Starting the Ollama Update script"

    curl -fsSL https://ollama.com/install.sh | sh

    echo "Waiting 3 seconds for Ollama to start"
    sleep 3

    updated_version=$(ollama --version 2>&1 | grep -Po 'ollama version is \K.*')
    
    if [ "$clean_latest" = "$updated_version" ]; then
        # Add Environment variable to ollama service
        if grep -q 'Environment="HSA_OVERRIDE_GFX_VERSION=11.0.2"' /etc/systemd/system/ollama.service; then
            echo "Environment variable already exists"
        else
            # Add the environment variable line after [Service] section
            if [ -f /etc/systemd/system/ollama.service ]; then
                sudo sed -i '/\[Service\]/a Environment="HSA_OVERRIDE_GFX_VERSION=11.0.2"' /etc/systemd/system/ollama.service
                sudo sed -i '/\[Service\]/a Environment="OLLAMA_KV_CACHE_TYPE=q4_0"' /etc/systemd/system/ollama.service
                sudo sed -i '/\[Service\]/a Environment="OLLAMA_NUM_PARALLEL=3"' /etc/systemd/system/ollama.service
                sudo sed -i '/\[Service\]/a Environment="OLLAMA_MAX_LOADED_MODELS=3"' /etc/systemd/system/ollama.service
                echo "Environment variable added"

                # Restart Ollama with GPU enabled
                echo "Restart Ollama with GPU enabled"
                sudo systemctl daemon-reload
                sudo systemctl restart ollama.service

                echo "Waiting 3 seconds for Ollama to restart"
                sleep 3
            else
                echo "Ollama service file not found"
            fi
        fi
    else
        echo "Something went wrong during the update process of ollama"
    fi
fi

# After updating check for Ollama Environment Variable and restart
# Add Environment variable to ollama service
if grep -q 'Environment="HSA_OVERRIDE_GFX_VERSION=11.0.2"' /etc/systemd/system/ollama.service; then
    echo "Post-Update Environment Variable Check successful..."
else
    # Add the environment variable line after [Service] section
    if [ -f /etc/systemd/system/ollama.service ]; then
        sudo sed -i '/\[Service\]/a Environment="HSA_OVERRIDE_GFX_VERSION=11.0.2"' /etc/systemd/system/ollama.service
        echo "Environment variable added"

        # Restart Ollama with GPU enabled
        echo "Restart Ollama with GPU enabled"
        sudo systemctl daemon-reload
        sudo systemctl restart ollama.service
    else
        echo "Ollama service file not found"
    fi
fi

# Update Ollama models if needed
echo "Updating Ollama models where possible"
for i in $(ollama ls | awk '{ print $1}' | grep -v NAME); do
    if [[ "$i" == my* ]]; then
        echo "Skipping model: $i"
        continue
    fi
    echo "Updating model: $i"
    ollama pull "$i"
done
