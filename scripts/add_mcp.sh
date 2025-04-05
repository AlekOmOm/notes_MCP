#!/bin/bash
# Ensure the script stops on errors
set -e

# Debug information
#echo "Script location: $0"
#echo "Current directory: $(pwd)"

# Change working directory to notes_MCP directory with better path handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
#echo "Moving to base directory: $BASE_DIR"
cd "$BASE_DIR" || { echo "Failed to change directory to $BASE_DIR"; exit 1; }

# Check for Python availability and find the right command
PYTHON_CMD=""
# On Windows, try 'python' first as it's usually the correct command
if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "win"* ]]; then
    for cmd in python py python3; do
        if command -v $cmd >/dev/null 2>&1; then
            PYTHON_CMD=$cmd
#           echo "Found Python command: $PYTHON_CMD"
            break
        fi
    done
else
    # On other systems, try python3 first
    for cmd in python3 python py; do
        if command -v $cmd >/dev/null 2>&1; then
            PYTHON_CMD=$cmd
#            echo "Found Python command: $PYTHON_CMD"
            break
        fi
    done
fi

if [ -z "$PYTHON_CMD" ]; then
    echo "Error: Python is required but not found. Please install Python from https://www.python.org/downloads/"
    echo "If Python is already installed, ensure it's added to your PATH environment variable."
    exit 1
fi

# Test Python is working correctly
# Suppress Python version output
$PYTHON_CMD --version >/dev/null 2>&1 || {
    echo "Error: Python command found but not working correctly."
    exit 1
}

# Variables with defaults
JSON_FILE=${JSON_FILE:-mcps.json}
REPO_URL="${1:-https://github.com/anaisbetts/mcp-installer}"
#echo "Using repository URL: $REPO_URL"

# Check if the JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file $JSON_FILE not found in $(pwd)"
    exit 1
fi

# Use a simple approach to check for duplicates
dup_count=$($PYTHON_CMD -c "
import json
try:
    with open('$JSON_FILE', 'r') as f:
        data = json.load(f)
    count = sum(1 for repo in data.get('mcpRepos', []) if repo.get('url') == '$REPO_URL')
    print(count) 
except Exception as e:
    print(f'Error: {e}', file=open('error.log', 'w'))
    print(0)  # Default to 0 on error to continue execution
")

# Check for parsing errors
if [[ ! "$dup_count" =~ ^[0-9]+$ ]]; then
    echo "Error checking for duplicates: $dup_count"
    exit 1
fi

if [ "$dup_count" -gt 1 ]; then
    echo "Error: Duplicate repository entries found for $REPO_URL in $JSON_FILE."
    exit 1
fi

# Check for gh CLI availability
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh is required but not installed. Please install gh CLI from https://cli.github.com/"
    exit 1
fi

#echo "Fetching repository description for $REPO_URL..."
desc=$(gh repo view "$REPO_URL" --json description -q .description)
if [ -z "$desc" ]; then
    echo "Error: could not fetch repository description."
    exit 1
fi

#echo "Updating $JSON_FILE with repository description: $desc..."
# Use a simplified Python script for updating but suppress all output
$PYTHON_CMD -c "
import json
try:
    # Read the JSON file
    with open('$JSON_FILE', 'r') as fin:
        data = json.load(fin)
    
    # Look for existing entry
    entry_exists = False
    for repo in data.get('mcpRepos', []):
        if repo.get('url') == '$REPO_URL':
            repo['description'] = '$desc'
            entry_exists = True
            # Removed print statement
            print('Entry updated successfully.')
    
    # Add new entry if needed
    if not entry_exists:
        repo_name = '$REPO_URL'.split('/')[-1]
        new_entry = {'name': repo_name, 'url': '$REPO_URL', 'description': '$desc'}
        if 'mcpRepos' not in data:
            data['mcpRepos'] = []
        data['mcpRepos'].append(new_entry)
        # Removed print statement
        print('New entry added successfully.')
    
    # Write updated data back
    with open('$JSON_FILE', 'w') as fout:
        json.dump(data, fout, indent=2)
        # Removed print statement
except Exception as e:
    print(f'Error updating JSON file: {e}')
    exit(1)
"

#echo "repo added to MCPs.json successfully."