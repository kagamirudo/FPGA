#!/bin/bash

# Default directory
DEFAULT_DIR="/mnt/d/Materials/Study/HLS"

# Function to display usage
usage() {
    echo "Usage: $0 [folder_name]"
    echo "  folder_name: Optional name of a folder in the default directory"
    echo "  If no argument is provided, you will be prompted to enter a folder name"
    echo "  Default directory: $DEFAULT_DIR"
}

# Function to copy folder and sync with origin
copy_and_sync() {
    local folder_name="$1"
    local source_dir="$DEFAULT_DIR/$folder_name"
    local target_dir="$folder_name"
    local is_update=false
    
    echo "Source directory: $source_dir"
    echo "Target directory: $target_dir"
    
    # Check if source directory exists
    if [ ! -d "$source_dir" ]; then
        echo "Error: Folder '$folder_name' does not exist in '$DEFAULT_DIR'!"
        exit 1
    fi
    
    # Check if target directory already exists
    if [ -d "$target_dir" ]; then
        echo "Folder '$target_dir' already exists. Updating with rsync..."
        rsync -av --delete "$source_dir/" "$target_dir/"
        
        if [ $? -eq 0 ]; then
            echo "Successfully updated folder: $target_dir"
            is_update=true
        else
            echo "Error: Failed to update folder with rsync!"
            exit 1
        fi
    else
        # Copy the folder to current directory
        echo "Copying folder to current directory..."
        cp -r "$source_dir" .
        
        if [ $? -eq 0 ]; then
            echo "Successfully copied folder to: $target_dir"
        else
            echo "Error: Failed to copy folder!"
            exit 1
        fi
    fi
    
    # Add to git if this is a git repository
    if [ -d ".git" ]; then
        # If this script has changes, commit it separately with a fixed message
        if [ -n "$(git status --porcelain update.sh)" ]; then
            echo "Committing update.sh changes separately..."
            git add update.sh
            git commit -m "Update auto pushing process"
        fi

        # Ensure .gitignore has required rules and commit it separately if changed
        if [ ! -f .gitignore ]; then
            echo "Creating .gitignore..."
            touch .gitignore
        fi

        # Ensure .idea/ is ignored
        if ! grep -qE '^\.idea/\s*$' .gitignore; then
            echo "Adding .idea/ to .gitignore"
            printf "\n# IDE\n.idea/\n" >> .gitignore
        fi

        # If .gitignore has changes, commit with fixed message
        if [ -n "$(git status --porcelain .gitignore)" ]; then
            echo ".gitignore changed. Committing separately..."
            git add .gitignore
            git commit -m "Update .gitignore rules"
        fi

        echo "Adding to git..."
        git add "$target_dir"
        
        # Check git status to determine the type of changes
        echo "Checking git status..."
        local git_status=$(git status --porcelain "$target_dir")
        local commit_message=""
        
        if [ "$is_update" = true ]; then
            # For updates, check if files were added or modified
            if echo "$git_status" | grep -q "^A"; then
                commit_message="Add files to folder: $target_dir"
            elif echo "$git_status" | grep -q "^M"; then
                commit_message="Modify files in folder: $target_dir"
            else
                commit_message="Update folder: $target_dir"
            fi
        else
            # For new folders
            commit_message="Add folder: $target_dir"
        fi
        
        # Allow custom commit message before pushing
        echo "Default commit message: $commit_message"
        read -p "Enter custom commit message (or press Enter to use default): " custom_msg
        if [ -n "$custom_msg" ]; then
            commit_message="$custom_msg"
        fi
        
        # Commit the changes with chosen message
        echo "Committing changes: $commit_message"
        git commit -m "$commit_message"
        
        # Push to origin
        echo "Pushing to origin..."
        git push origin $(git branch --show-current)
        
        if [ $? -eq 0 ]; then
            echo "Successfully synced with origin!"
        else
            echo "Warning: Failed to push to origin. You may need to pull first or resolve conflicts."
        fi
    else
        echo "Warning: Not a git repository. Skipping git operations."
    fi
}

# Main script logic
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# If argument is provided, use it
if [ $# -eq 1 ]; then
    folder_name="$1"
    echo "Using provided folder name: $folder_name"
else
    # Prompt for folder name
    echo "No folder name provided."
    echo "Default directory: $DEFAULT_DIR"
    read -p "Enter folder name from default directory (or press Enter to list available folders): " user_input
    
    if [ -z "$user_input" ]; then
        echo "Available folders in $DEFAULT_DIR:"
        if [ -d "$DEFAULT_DIR" ]; then
            ls -1 "$DEFAULT_DIR" | grep -E '^[^.]' | head -20
            echo "..."
        else
            echo "Default directory does not exist: $DEFAULT_DIR"
            exit 1
        fi
        read -p "Enter folder name to copy: " folder_name
    else
        folder_name="$user_input"
        echo "Using user input: $folder_name"
    fi
fi

# Execute the copy and sync operation
copy_and_sync "$folder_name"

echo "Script completed successfully!"
