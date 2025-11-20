#!/bin/bash

# Create the model directory if it doesn't exist
model_dir="models"
if [[ ! -d "$model_dir" ]]; then
  mkdir -p "$model_dir"
fi

# Get the output of "ollama list" and process each model
ollama list | tail -n +2 | while read -r line; do
  # Extract the model name (first column)
  model_name=$(echo "$line" | awk '{print $1}')
  mymodel_name="my${model_name}"

  # Check if mymodel is not already in the model list
  if ! ollama list | grep -q "$mymodel_name" || [[ "$model_name" == *"my"* ]]; then
    # Create the modelfile name
    modelfile_name="${mymodel_name}.modelfile"
    
    # Create the modelfile using ollama show
    if [[ "$model_name" != *"hf.co"* ]]; then
      echo "Creating modelfile for $model_name"
      ollama show "$model_name" --modelfile > "$model_dir/$modelfile_name"
      
      # Get the library URL for the model
      library_url="https://ollama.com/library/$model_name"
      
      # Extract the blob href from the library page
      blob_href=$(curl -s "$library_url" | grep -o '<a href="/library/[^"]*blob[^"]*"' | head -1 | sed 's/.*href="\([^"]*\)".*/\1/')
      
      if [[ -n "$blob_href" ]]; then
        # Follow the blob href to get the table entry
        echo "Receiving layer count information to model: $model_name"
        full_url="https://ollama.com$blob_href"
        block_count=$(curl -s "$full_url" | tr -d '\n' | tr -s " " | grep -oP '\.block_count<\/div>\s*<div class="sm:hidden font-mono font-medium py-1">\s*\K[0-9]+(?=\s*<\/div>)' )
        # Somehow the Block count on the Website is one block short...
        block_count=$((block_count + 1))
        echo "Layer count for $model_name: $block_count"

        echo "Editing modelfile..."
        # Deleting the FROM statement from the ollama show export
        sed -i '/^FROM [^a-zA-Z0-9]/d' "$model_dir/$modelfile_name"
        # Uncommenting the FROM statement, so that a fresh model will be created
        sed -i 's/^# FROM/FROM/' "$model_dir/$modelfile_name"

        # Add the correct layer count to the num_gpu PARAMETER
        echo "PARAMETER num_gpu $block_count" >> "$model_dir/$modelfile_name"

        echo "Creating new Model from modelfile with custom num_gpu parameter"
        # Create new model with modelfile
        ollama create $mymodel_name --file "$model_dir/$modelfile_name"

        echo "--------------------------"
      else
        echo "Could not find blob href for $model_name"
      fi
    fi
  fi
done