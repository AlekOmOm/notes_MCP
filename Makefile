# Variables; override these values on the command line if needed.
JSON_FILE = mcps.json
# Default REPO_URL can be overridden by providing 'REPO_URL=...' argument on the command line.
REPO_URL ?= https://github.com/anaisbetts/mcp-installer

# --- JSON Context (Keep as is for reference) ---
# {
#   "mcpRepos": [
#     {
#       "name": "mcp-installer",
#       "url": "https://github.com/anaisbetts/mcp-installer"
#     }
#   ]
# }
# --- End JSON Context ---


.PHONY: add_mcp
add_mcp:
	@export JSON_FILE="$(JSON_FILE)" && \
	SCRIPT_PATH="./scripts/add_mcp.sh" && \
	if [ -f "$$SCRIPT_PATH" ]; then \
		bash "$$SCRIPT_PATH" "$(REPO_URL)" 2>&1 | grep -i "error" || true; \
	else \
		echo "Error: Script not found at $$SCRIPT_PATH"; \
		exit 1; \
	fi


help:
	@echo "--------------------------------"
	@echo "Makefile for noting MCP repos"
	@echo "Usage:"
	@echo "  make add_mcp REPO_URL=<repository_url>"
	@echo "  make help"
	@echo ""
	@echo "Commands:"
	@echo "  add_mcp       Add a new MCP repository to the JSON file."
	@echo "  help          Show this help message."
	@echo ""
	@echo "--------------------------------"