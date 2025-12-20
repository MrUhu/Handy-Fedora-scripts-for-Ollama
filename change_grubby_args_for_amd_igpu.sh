#!/bin/bash

# Ensure the script is running with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with bash."
    exit 1
fi

# Enter the desired size of your graphics transfer table in gb
echo "Enter the desired size of your graphics transfer table in GB:"
read -r number

# Check if the entered value is a positive integer
if ! [[ "$number" =~ ^[0-9]+$ ]] || [ "$number" -le 0 ]; then
    echo "Error: Please enter a valid positive integer."
    exit 1
fi

# Get available memory
available_memory=$(free -g | awk '/^Mem:/{print $2}')

if [ -z "$available_memory" ]; then
    echo "Error: Could not determine available memory."
    exit 1
fi

# Calculate 50% and 90% of available system memory for limits
max_size_50_percent=$((available_memory / 2))
max_size_90_percent=$((available_memory * 9 / 10)) # 90% of available memory

echo "Available system memory: $available_memory GB"
echo "50% limit: $max_size_50_percent GB"
echo "90% limit: $max_size_90_percent GB"

if [ "$number" -gt "$max_size_50_percent" ]; then
    echo "Warning: The requested GTT size ($number GB) exceeds 50% of available system memory ($available_memory GB)."
    if [ "$number" -le "$max_size_90_percent" ]; then
        read -p "Do you want to overwrite the 50% limit and set GTT size up to 90% of system memory? (y/N): " response
        if [[ "$response" =~ ^[yY]$ ]]; then
            echo "Proceeding with GTT size $number GB, using up to 90% of system memory."
        else
            echo "Error: GTT size request rejected by user."
            exit 1
        fi
    else
        echo "Error: The requested GTT size ($number GB) exceeds 90% of available system memory ($max_size_90_percent GB)."
        echo "A minimum of 10% of system memory ($((available_memory - max_size_90_percent)) GB) should be spared."
        exit 1
    fi
fi

# Perform the calculation: (number * 1024 * 1024 * 1024)/4096
result=$(( (number * 1024 * 1024 * 1024) / 4096 ))

# Display the result
echo "-------------------------------"
echo "Desired GTT size in GB: $number"
echo "Calculated pages: $result"
echo "-------------------------------"

# Write amdgpu memory related dmesg output to file as backup
sudo dmesg | grep "amdgpu.*memory" > /tmp/dmesg.amdgpu.memory.bkp
echo "amdgpu memory dmesg output saved to /tmp/dmesg.amdgpu.memory.bkp"

# Get the GTT memory value from dmesg
gtt_line=$(sudo dmesg | grep "amdgpu.*memory" | grep -v "VRAM" | head -1)

if [ -z "$gtt_line" ]; then
    echo "No amdgpu memory line found in dmesg"
    exit 1
fi

# Extract the GTT memory value (e.g., 23975M)
gtt_value=$(echo "$gtt_line" | grep -o '[0-9]*M' | head -1 | sed 's/M//')
gtt_page_value=$(( (gtt_value * 1024 * 1024 * 1024) / 4096 ))

echo "-------------------------------"
echo "Current GTT Memory Value: $gtt_value MB"
echo "Current Page Limit: $gtt_page_value"
echo "-------------------------------"

# Compare the values
if [ "$gtt_page_value" -ne "$result" ]; then
    echo "Values don't match, applying kernel parameter changes..."
    # Apply the changes
    if ! sudo grubby --update-kernel=ALL --args="ttm.pages_limit=$result ttm.page_pool_size=$result amdgpu.cwsr_enable=0"; then
        echo "Error: Failed to update kernel parameters."
        exit 1
    fi
    echo "Kernel parameters updated successfully"

    # Verify the changes
    echo "Verifying kernel parameters..."
    grubby_output=$(sudo grubby --info=ALL)

    if [ -z "$grubby_output" ]; then
        echo "Error: Failed to retrieve grubby info."
        exit 1
    fi

    # Check if the desired parameters are present in the output
    check=0
    if echo "$grubby_output" | grep -q "ttm.pages_limit=$result"; then
        echo "Verification successful: ttm.pages_limit=$result found in grubby output"
        check=$((check + 1))
    else
        echo "Verification failed: ttm.pages_limit=$result not found in grubby output"
        exit 1
    fi

    if echo "$grubby_output" | grep -q "ttm.page_pool_size=$result"; then
        echo "Verification successful: ttm.page_pool_size=$result found in grubby output"
        check=$((check + 1))
    else
        echo "Verification failed: ttm.page_pool_size=$result not found in grubby output"
        exit 1
    fi

    if echo "$grubby_output" | grep -q "amdgpu.cwsr_enable=0"; then
        echo "Verification successful: amdgpu.cwsr_enable=0 found in grubby output"
        check=$((check + 1))
    else
        echo "Verification failed: amdgpu.cwsr_enable=0 not found in grubby output"
        exit 1
    fi

    if [ "$check" == 3 ]; then
        echo "-------------------------------"
        echo "Everything is set up"
        read -p "Do you want to reboot now? (y/N): " reboot_response
        if [[ "$reboot_response" =~ ^[yY]$ ]]; then
            echo "Rebooting in 5 seconds..."
            sleep 5
            shutdown -r now
        else
            echo "Reboot cancelled. Please reboot manually to apply changes."
        fi
    fi
else
    echo "Values match - no changes needed"
fi