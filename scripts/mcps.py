import json
import sys

def update_mcps(json_file, repo_url, description):
    try:
        # Read the JSON file
        with open(json_file, 'r') as fin:
            data = json.load(fin)
        
        # Look for existing entry
        entry_exists = False
        for repo in data.get('mcpRepos', []):
            if repo.get('url') == repo_url:
                repo['description'] = description
                entry_exists = True
        
        # Add new entry if needed
        if not entry_exists:
            repo_name = repo_url.split('/')[-1]
            new_entry = {'name': repo_name, 'url': repo_url, 'description': description}
            if 'mcpRepos' not in data:
                data['mcpRepos'] = []
            data['mcpRepos'].append(new_entry)
        
        # Write updated data back
        with open(json_file, 'w') as fout:
            json.dump(data, fout, indent=2)
        
        return True
    except Exception as e:
        print(f'Error updating JSON file: {e}', file=sys.stderr)
        return False

if __name__ == "__main__":
    # Check for command line arguments
    if len(sys.argv) < 4:
        print("Usage: python mcps.py JSON_FILE REPO_URL DESCRIPTION")
        sys.exit(1)
    
    json_file = sys.argv[1]
    repo_url = sys.argv[2]
    description = sys.argv[3]
    
    success = update_mcps(json_file, repo_url, description)
    if not success:
        sys.exit(1)