#!/bin/bash

# Configuration
model_dir="models"
prefix="my"  # Prefix for new model names
create_new_models=true  # Set to false to only create modelfiles

# Create the model directory if it doesn't exist
if [[ ! -d "$model_dir" ]]; then
  mkdir -p "$model_dir"
fi

# Get the output of "ollama list" and process each model
ollama list | tail -n +2 | while read -r line; do
  # Extract the model name (first column)
  model_name=$(echo "$line" | awk '{print $1}')
  mymodel_name="${prefix}${model_name}"

  # Skip if model already has our prefix
  if [[ "$model_name" == "$prefix"* ]]; then
    echo "Skipping $model_name (already has prefix)"
    continue
  fi

  # Check if our version of the model already exists
  if ollama list | grep -q "$mymodel_name"; then
    echo "Skipping $model_name (custom version already exists)"
    continue
  fi

  # Skip Hugging Face models
  if [[ "$model_name" == *"hf.co"* ]]; then
    echo "Skipping $model_name (Hugging Face model)"
    continue
  fi

  echo "Processing $model_name"

  # Create the modelfile using ollama show
  modelfile_name="${mymodel_name}.modelfile"
  if ! ollama show "$model_name" --modelfile > "$model_dir/$modelfile_name"; then
    echo "Error creating modelfile for $model_name"
    continue
  fi

  # Get the library URL for the model
  library_url="https://ollama.com/library/$model_name"

  # Extract the blob href from the library page
  blob_href=$(curl -s "$library_url" | grep -o '<a href="/library/[^"]*blob[^"]*"' | head -1 | sed 's/.*href="\([^"]*\)".*/\1/')

  if [[ -z "$blob_href" ]]; then
    echo "Could not find blob href for $model_name"
    continue
  fi

  # Follow the blob href to get the table entry
  echo "Receiving layer count information for $model_name"
  full_url="https://ollama.com$blob_href"
  block_count=$(curl -s "$full_url" | tr -d '\n' | tr -s " " | grep -oP '\.block_count<\/div>\s*<div class="sm:hidden font-mono font-medium py-1">\s*\K[0-9]+(?=\s*<\/div>)' )

  # Clean up block_count to make sure it's all digits
  block_count=$(echo "$block_count" | tr -cd '[:digit:]')

  # Validate block_count
  if [[ -z "$block_count" || "$block_count" -eq 0 ]]; then
    echo "Invalid block count for $model_name"
    continue
  fi

  # Adjust block count (website is one short)
  block_count=$((block_count + 1))
  echo "Layer count for $model_name: $block_count"

  # Edit modelfile
  echo "Editing modelfile..."
  # Remove existing FROM statement
  sed -i '/^FROM [^a-zA-Z0-9]/d' "$model_dir/$modelfile_name"
  # Uncomment the FROM statement
  sed -i 's/^# FROM/FROM/' "$model_dir/$modelfile_name"
  # Add the num_gpu parameter
  echo "PARAMETER num_gpu $block_count" >> "$model_dir/$modelfile_name"

  if [[ "$create_new_models" == true ]]; then
    echo "Creating new model from modelfile with custom num_gpu parameter"
    # Create new model with modelfile
    if ! ollama create "$mymodel_name" --file "$model_dir/$modelfile_name"; then
      echo "Error creating model $mymodel_name"
    fi
  else
    echo "Skipping model creation (create_new_models=false)"
  fi

  echo "----------------------------------------"
done