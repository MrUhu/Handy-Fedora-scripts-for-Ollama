Run
#!/bin/bash

# Enter the desired size of your graphics transfer table in gb
echo "Enter the desired size of your graphics transfer table in GB:"
read -r number

# Check if the entered value is an integer
if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    echo "Error: Please enter a valid integer."
    exit 1
fi

# Get available system memory in GB
available_memory=$(free -g | awk '/^Mem:/{print $2}')

# Check if the entered number is smaller or equal to 50% of available system memory
max_size=$((available_memory / 2))

if [ "$number" -gt "$max_size" ]; then
    echo "Error: The requested GTT size ($number GB) exceeds 50% of available system memory ($max_size GB)."
    exit 1
fi

# Perform the calculation: (number * 1024 * 1024 * 1024)/4096
result=$(( (number * 1024 * 1024 * 1024) / 4096 ))

# Display the result
echo "-------------------------------"
echo "Desired GTT size in GB: $number"
echo "Caculated pages: $result"
echo "-------------------------------"

# Write amdgpu memory related dmesg output to file as backup
sudo dmesg | grep "amdgpu.*memory" > dmesg.amdgpu.memory.bkp

echo "amdgpu memory dmesg output saved to dmesg.amdgpu.memory.bkp"

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
    #sudo grubby --update-kernel=ALL --args="ttm.pages_limit=$result ttm.page_pool_size=$result no_system_mem_limit=Y"
    sudo grubby --update-kernel=ALL --args="ttm.pages_limit=$result ttm.page_pool_size=$result"
    echo "Kernel parameters updated successfully"
    
    # Verify the changes
    echo "Verifying kernel parameters..."
    grubby_output=$(sudo grubby --info=ALL)
    
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

    if [ "$check" == 2 ]; then
        echo "-------------------------------"
        echo "Everything is set up"
        echo "Reboot will start in 5 seconds..."
        # Schedule reboot in 5 seconds
        sleep 5
        shutdown -r now
    fi
    
else
    echo "Values match - no changes needed"
fi