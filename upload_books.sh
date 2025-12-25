#!/bin/bash

# Configuration
TAG_NAME="v1.0-books"
TITLE="Large Book Storage"

# 1. Check if inside a git repo
if [ ! -d ".git" ]; then
    echo "❌ Error: Run this from the root of your git repository."
    exit 1
fi

# 2. Get Repo Info
REPO_URL=$(gh repo view --json url -q .url)
if [ -z "$REPO_URL" ]; then
    echo "❌ Error: Run 'gh auth login' first."
    exit 1
fi

echo "--------------------------------------------------------"
echo "Target Repo:    $REPO_URL"
echo "Target Release: $TAG_NAME"
echo "Strategy:       Deep Renaming (Category_Version_Class_File)"
echo "--------------------------------------------------------"

# 3. Create Release if needed
gh release view "$TAG_NAME" >/dev/null 2>&1 || gh release create "$TAG_NAME" --title "$TITLE" --notes "Storage for files >20MB"

# 4. Prepare the output file
echo "Local Path | New Remote URL" > new_links.txt

# 5. Find files > 20MB
find . -type f -size +20M -not -path '*/.*' -print0 | while IFS= read -r -d '' filepath; do
    
    # --- PARSING THE PATH ---
    # Example Path: ./pdfs/secondary/bangla-version/class-nine/math.pdf
    
    filename=$(basename "$filepath")                # math.pdf
    
    dir_class=$(dirname "$filepath")                # .../class-nine
    class_name=$(basename "$dir_class")             # class-nine
    
    dir_version=$(dirname "$dir_class")             # .../bangla-version
    version_name=$(basename "$dir_version")         # bangla-version
    
    dir_category=$(dirname "$dir_version")          # .../secondary
    category_name=$(basename "$dir_category")       # secondary

    # --- CONSTRUCTING THE UNIQUE NAME ---
    # Format: category_version_class_filename
    unique_name="${category_name}_${version_name}_${class_name}_${filename}"
    
    # Optional: If you want to replace hyphens in folder names with underscores (e.g. bangla-version -> bangla_version)
    # unique_name=$(echo "$unique_name" | sed 's/-/_/g') 

    echo "Processing: $filepath"
    echo "   -> New Name: $unique_name"

    # Create a temporary copy
    cp "$filepath" "$unique_name"

    # Upload
    if gh release upload "$TAG_NAME" "$unique_name" --clobber; then
        
        # Generate URL
        base_url=${REPO_URL%.git}
        final_url="$base_url/releases/download/$TAG_NAME/$unique_name"
        
        echo "$filepath | $final_url" >> new_links.txt
        echo "✅ Uploaded"
    else
        echo "❌ Failed to upload $unique_name"
    fi

    # Cleanup temp file
    rm "$unique_name"
    echo "--------------------------------------------------------"
done

echo "🎉 Done! Check 'new_links.txt' for your new URLs."