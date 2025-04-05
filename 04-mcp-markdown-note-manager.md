# 04. Markdown Note Manager Example 📝

[<- Back to Main Note](./README.md) | [Next: Best Practices ->](./05-best-practices.md)

## Table of Contents

- [Project Overview](#project-overview)
- [Basic Implementation](#basic-implementation)
- [File Operations](#file-operations)
- [Advanced Features](#advanced-features)
- [Complete Implementation](#complete-implementation)

## Project Overview

This example demonstrates how to build a complete MCP Server that provides tools for managing markdown notes. The implementation includes core file operations, search capabilities, and organization features.

### System Architecture

```
+-------------------+       +-------------------+       +-----------------+
| Claude Desktop    | ----> | Claude Backend    | ----> | Markdown Note   |
| (User Interface)  |       | (LLM Host)        |       | Manager         |
|                   | <---- |                   | <---- | (MCP Server)    |
+-------------------+       +-------------------+       +-----------------+
                                                                |
                                                                v
                                                        +-----------------+
                                                        | File System     |
                                                        | (Note Storage)  |
                                                        +-----------------+
```

### Functionality Overview

The Markdown Note Manager MCP Server will provide the following capabilities:

1. **Note Creation**: Create new markdown notes with templates
2. **Note Reading**: Retrieve existing notes
3. **Note Updates**: Modify existing notes
4. **Note Organization**: Move, rename, and categorize notes
5. **Search**: Find notes by content or metadata
6. **Metadata Management**: Add, update, and query note metadata

Key points to remember:
- The MCP Server acts as the bridge between LLM Hosts and the file system
- A well-designed tool interface makes interaction natural for users
- Clear descriptions help the LLM understand when and how to use each function

## Basic Implementation

Let's start with the core MCP Server setup and basic note operations.

### Project Setup

```javascript
// File: server.js
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

const { registerNoteManagerTool } = require('./tools/note-manager');
const { createMCPRouter } = require('./mcp/router');

// Create Express server
const app = express();
app.use(cors());
app.use(bodyParser.json());

// Configure Note Manager tool
const notesDirectory = process.env.NOTES_DIR || './notes';
const noteManager = registerNoteManagerTool(notesDirectory);

// Set up MCP routes
const mcpRouter = createMCPRouter();
mcpRouter.registerTool(noteManager);
app.use('/mcp', mcpRouter.getRouter());

// Start server
const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`MCP Server running on port ${port}`);
  console.log(`Notes directory: ${notesDirectory}`);
});
```

### MCP Router Implementation

```javascript
// File: mcp/router.js
const express = require('express');

function createMCPRouter() {
  const router = express.Router();
  const registeredTools = new Map();
  
  // Handle discovery requests
  router.get('/discover', (req, res) => {
    const manifest = generateManifest();
    res.json({
      type: 'mcp_discovery_response',
      manifest
    });
  });
  
  // Handle invocation requests
  router.post('/invoke', async (req, res) => {
    try {
      const { tool, function: functionName, parameters } = req.body;
      
      // Validate request
      if (!tool || !functionName) {
        return res.status(400).json({
          type: 'mcp_error',
          error: 'Missing tool or function name'
        });
      }
      
      // Find tool
      if (!registeredTools.has(tool)) {
        return res.status(404).json({
          type: 'mcp_error',
          error: `Tool '${tool}' not found`
        });
      }
      
      const toolDefinition = registeredTools.get(tool);
      
      // Find function
      const functionDef = toolDefinition.functions.find(f => f.name === functionName);
      if (!functionDef) {
        return res.status(404).json({
          type: 'mcp_error',
          error: `Function '${functionName}' not found in tool '${tool}'`
        });
      }
      
      // Execute function
      const result = await functionDef.implementation(parameters);
      
      // Return result
      res.json({
        type: 'mcp_invocation_response',
        result
      });
    } catch (error) {
      console.error('Invocation error:', error);
      res.status(500).json({
        type: 'mcp_error',
        error: error.message
      });
    }
  });
  
  // Generate tool manifest
  function generateManifest() {
    const tools = [];
    
    for (const [name, definition] of registeredTools.entries()) {
      tools.push({
        name,
        description: definition.description,
        functions: definition.functions.map(f => ({
          name: f.name,
          description: f.description,
          parameters: f.parameters,
          returns: f.returns
        }))
      });
    }
    
    return {
      protocol_version: '1.0',
      server_info: {
        name: 'Markdown Note Manager',
        version: '1.0.0',
        description: 'MCP Server for managing markdown notes'
      },
      {
        name: 'search_notes',
        description: 'Searches notes content for specific text',
        parameters: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Text to search for in notes'
            },
            max_results: {
              type: 'number',
              description: 'Maximum number of results to return (default: 10)'
            }
          },
          required: ['query']
        },
        returns: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            results: { 
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  filename: { type: 'string' },
                  preview: { type: 'string' },
                  relevance: { type: 'number' }
                }
              }
            }
          }
        },
        implementation: searchNotes
      }
      {
        name: 'update_note',
        description: 'Updates the content of an existing markdown note',
        parameters: {
          type: 'object',
          properties: {
            filename: {
              type: 'string',
              description: 'Name of the note file to update'
            },
            content: {
              type: 'string',
              description: 'New content for the note'
            },
            append: {
              type: 'boolean',
              description: 'If true, append content instead of replacing'
            }
          },
          required: ['filename', 'content']
        },
        returns: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            message: { type: 'string' }
          }
        },
        implementation: updateNote
      },
      {
        name: 'list_notes',
        description: 'Lists all markdown notes in the notes directory',
        parameters: {
          type: 'object',
          properties: {
            folder: {
              type: 'string',
              description: 'Optional subfolder to list notes from'
            },
            pattern: {
              type: 'string',
              description: 'Optional glob pattern to filter notes'
            }
          }
        },
        returns: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            notes: { 
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  filename: { type: 'string' },
                  path: { type: 'string' },
                  modified: { type: 'string' }
                }
              }
            }
          }
        },
        implementation: listNotes
      },
      tools
    };
  }
  
  // Register tool with the router
  return {
    registerTool: (tool) => {
      registeredTools.set(tool.name, tool);
      console.log(`Registered tool: ${tool.name} with ${tool.functions.length} functions`);
    },
    getRouter: () => router
  };
}

module.exports = { createMCPRouter };
```

## File Operations

The core functionality of our note manager centers around file operations.

### Note Creation and Reading

```javascript
// File: tools/note-manager.js
const fs = require('fs').promises;
const path = require('path');
const { sanitizeFilename } = require('../utils/filename');

function registerNoteManagerTool(notesDirectory) {
  // Ensure notes directory exists
  fs.mkdir(notesDirectory, { recursive: true }).catch(console.error);
  
  // Implementation functions
  async function createNote(params) {
    const { filename, content, template } = params;
    
    if (!filename) {
      return { status: 'error', message: 'Filename is required' };
    }
    
    try {
      // Sanitize filename and ensure .md extension
      const sanitizedName = sanitizeFilename(filename);
      const noteName = sanitizedName.endsWith('.md') ? sanitizedName : `${sanitizedName}.md`;
      const notePath = path.join(notesDirectory, noteName);
      
      // Check if file already exists
      try {
        await fs.access(notePath);
        return { 
          status: 'error', 
          message: `Note '${noteName}' already exists` 
        };
      } catch (e) {
        // File doesn't exist, we can proceed
      }
      
      // Determine content (use template or provided content)
      let noteContent = content || '';
      if (!content && template) {
        const templatePath = path.join(notesDirectory, 'templates', `${template}.md`);
        try {
          noteContent = await fs.readFile(templatePath, 'utf8');
        } catch (err) {
          // Template not found, use default
          noteContent = `# ${filename}\n\nCreated on ${new Date().toISOString().split('T')[0]}\n\n`;
        }
      }
      
      // Write file
      await fs.writeFile(notePath, noteContent, 'utf8');
      
      return {
        status: 'success',
        message: `Note '${noteName}' created successfully`,
        path: notePath
      };
    } catch (error) {
      return {
        status: 'error',
        message: `Failed to create note: ${error.message}`
      };
    }
  }
  
  async function readNote(params) {
    const { filename } = params;
    
    if (!filename) {
      return { status: 'error', message: 'Filename is required' };
    }
    
    try {
      // Normalize filename
      const noteName = filename.endsWith('.md') ? filename : `${filename}.md`;
      const notePath = path.join(notesDirectory, noteName);
      
      // Read file
      const content = await fs.readFile(notePath, 'utf8');
      
      return {
        status: 'success',
        filename: noteName,
        content
      };
    } catch (error) {
      return {
        status: 'error',
        message: `Failed to read note: ${error.message}`
      };
    }
  }
  
  async function updateNote(params) {
    const { filename, content, append = false } = params;
    
    if (!filename || content === undefined) {
      return { status: 'error', message: 'Filename and content are required' };
    }
    
    try {
      // Normalize filename
      const noteName = filename.endsWith('.md') ? filename : `${filename}.md`;
      const notePath = path.join(notesDirectory, noteName);
      
      // Check if file exists
      try {
        await fs.access(notePath);
      } catch (e) {
        return { 
          status: 'error', 
          message: `Note '${noteName}' does not exist` 
        };
      }
      
      // Read existing content if appending
      let newContent = content;
      if (append) {
        const existingContent = await fs.readFile(notePath, 'utf8');
        newContent = existingContent + '\n\n' + content;
      }
      
      // Write file
      await fs.writeFile(notePath, newContent, 'utf8');
      
      return {
        status: 'success',
        message: `Note '${noteName}' ${append ? 'appended to' : 'updated'} successfully`
      };
    } catch (error) {
      return {
        status: 'error',
        message: `Failed to update note: ${error.message}`
      };
    }
  }
  
  async function listNotes(params) {
    const { folder = '', pattern = '*.md' } = params;
    
    try {
      // Resolve folder path
      const folderPath = path.join(notesDirectory, folder);
      
      // Ensure folder exists
      try {
        await fs.access(folderPath);
      } catch (e) {
        return { 
          status: 'error', 
          message: `Folder '${folder}' does not exist` 
        };
      }
      
      // Read directory
      const files = await fs.readdir(folderPath);
      
      // Filter markdown files and get stats
      const notePromises = files
        .filter(file => file.endsWith('.md'))
        .filter(file => {
          // Simple pattern matching (could use full glob with additional library)
          if (pattern === '*.md') return true;
          return new RegExp(pattern.replace('*', '.*')).test(file);
        })
        .map(async file => {
          const filePath = path.join(folderPath, file);
          const stats = await fs.stat(filePath);
          return {
            filename: file,
            path: filePath,
            modified: stats.mtime.toISOString()
          };
        });
      
      const notes = await Promise.all(notePromises);
      
      return {
        status: 'success',
        notes: notes
      };
    } catch (error) {
      return {
        status: 'error',
        message: `Failed to list notes: ${error.message}`
      };
    }
  }
  
  async function searchNotes(params) {
    const { query, max_results = 10 } = params;
    
    if (!query) {
      return { status: 'error', message: 'Search query is required' };
    }
    
    try {
      // Helper function to get all markdown files recursively
      async function getMarkdownFiles(dir) {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        const files = await Promise.all(entries.map(async (entry) => {
          const res = path.resolve(dir, entry.name);
          return entry.isDirectory() ? getMarkdownFiles(res) : res;
        }));
        return Array.prototype.concat(...files)
          .filter(file => file.endsWith('.md'));
      }
      
      // Get all markdown files
      const markdownFiles = await getMarkdownFiles(notesDirectory);
      
      // Search in each file
      const searchResults = [];
      const lowerQuery = query.toLowerCase();
      
      for (const file of markdownFiles) {
        try {
          const content = await fs.readFile(file, 'utf8');
          const lowerContent = content.toLowerCase();
          
          if (lowerContent.includes(lowerQuery)) {
            // Calculate relevance score (simple count of occurrences)
            const occurrences = (lowerContent.match(new RegExp(lowerQuery, 'g')) || []).length;
            
            // Create preview with context
            const index = lowerContent.indexOf(lowerQuery);
            const startIndex = Math.max(0, index - 50);
            const endIndex = Math.min(content.length, index + query.length + 50);
            
            let preview = content.substring(startIndex, endIndex);
            if (startIndex > 0) preview = '...' + preview;
            if (endIndex < content.length) preview = preview + '...';
            
            // Get relative path for cleaner display
            const relativePath = path.relative(notesDirectory, file);
            
            searchResults.push({
              filename: relativePath,
              preview,
              relevance: occurrences
            });
          }
        } catch (error) {
          console.error(`Error searching file ${file}:`, error);
        }
      }
      
      // Sort by relevance and limit results
      const results = searchResults
        .sort((a, b) => b.relevance - a.relevance)
        .slice(0, max_results);
      
      return {
        status: 'success',
        query,
        count: results.length,
        results
      };
    } catch (error) {
      return {
        status: 'error',
        message: `Search failed: ${error.message}`
      };
    }
  }
  
  // Define tool schema
  const toolDefinition = {
    name: 'note_manager',
    description: 'Create, read, update, and search markdown notes',
    functions: [
      {
        name: 'create_note',
        description: 'Creates a new markdown note with the given content',
        parameters: {
          type: 'object',
          properties: {
            filename: {
              type: 'string',
              description: 'Name of the note file (will be sanitized)'
            },
            content: {
              type: 'string',
              description: 'Markdown content for the note'
            },
            template: {
              type: 'string',
              description: 'Optional template name to use if content is not provided'
            }
          },
          required: ['filename']
        },
        returns: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            message: { type: 'string' },
            path: { type: 'string' }
          }
        },
        implementation: createNote
      },
      {
        name: 'read_note',
        description: 'Retrieves the content of a markdown note',
        parameters: {
          type: 'object',
          properties: {
            filename: {
              type: 'string',
              description: 'Name of the note file to read'
            }
          },
          required: ['filename']
        },
        returns: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            filename: { type: 'string' },
            content: { type: 'string' }
          }
        },
        implementation: readNote
      },