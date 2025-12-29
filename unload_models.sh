#!/bin/bash

# Get the list of loaded models from Ollama
loaded_models=$(ollama ps | tail -n +2 | awk '{print $1}')

# Check if there are any loaded models
if [ -z "$loaded_models" ]; then
    echo "No loaded models found."
    exit 0
fi

# Stop each loaded model
for model in $loaded_models; do
    echo "Stopping model: $model"
    ollama stop "$model"
done

echo "All models have been stopped."