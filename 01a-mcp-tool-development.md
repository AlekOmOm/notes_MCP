# 01a. MCP Tool Development 🛠️

[<- Back to Main Topic](./01-model-context-protocol.md) | [Next Sub-Topic: Server Implementation ->](./01b-server-implementation.md)

## Overview

This sub-note focuses on building effective tools for the Model-Context-Protocol ecosystem. Tools are the functional components that execute actions or retrieve information when invoked through an MCP Server. Understanding how to design, implement, and optimize these tools is crucial for creating valuable extensions to LLM capabilities.

## Key Concepts

### Tool Definition

A tool in MCP represents a discrete capability that can be invoked by an LLM through standardized protocol messages.

```javascript
// Example tool definition in an MCP manifest
const markdownToolDefinition = {
  name: "markdown_manager",
  description: "Creates, reads, and manages markdown notes",
  functions: [
    {
      name: "create_note",
      description: "Creates a new markdown note with specified content",
      parameters: {
        type: "object",
        properties: {
          filename: {
            type: "string",
            description: "Name of the note file (without path)"
          },
          content: {
            type: "string",
            description: "Markdown content for the note"
          }
        },
        required: ["filename", "content"]
      },
      returns: {
        type: "object",
        properties: {
          status: { type: "string" },
          message: { type: "string" },
          path: { type: "string" }
        }
      }
    }
  ]
};
```

### Tool Implementation

The actual code that executes when a tool is invoked by the LLM.

```javascript
// Implementation of the create_note function
async function createNote(params) {
  const { filename, content } = params;
  
  // Validate parameters
  if (!filename || !content) {
    return {
      status: "error",
      message: "Both filename and content are required"
    };
  }
  
  try {
    // Ensure filename has .md extension
    const normalizedFilename = filename.endsWith('.md') 
      ? filename 
      : `${filename}.md`;
    
    // Write to file system
    const fullPath = path.join(notesDirectory, normalizedFilename);
    await fs.promises.writeFile(fullPath, content, 'utf8');
    
    return {
      status: "success",
      message: `Note "${normalizedFilename}" created successfully`,
      path: fullPath
    };
  } catch (error) {
    return {
      status: "error",
      message: `Failed to create note: ${error.message}`
    };
  }
}
```

## Implementation Patterns

### Pattern 1: Atomic Tools

Design tools that perform single, well-defined operations rather than complex multi-step processes.

```javascript
// Atomic tool approach
const atomicTools = {
  createNote: async (filename, content) => { /* single responsibility */ },
  readNote: async (filename) => { /* single responsibility */ },
  updateNote: async (filename, content) => { /* single responsibility */ },
  deleteNote: async (filename) => { /* single responsibility */ }
};
```

**When to use this pattern:**
- When operations are logically distinct
- When you want clear error boundaries
- When operations might be used independently

### Pattern 2: Capability Grouping

Group related operations under a single tool with multiple functions.

```javascript
// Capability grouping pattern
class NoteManager {
  constructor() {
    // Setup
  }
  
  async create(params) { /* implementation */ }
  async read(params) { /* implementation */ }
  async update(params) { /* implementation */ }
  async delete(params) { /* implementation */ }
  async search(params) { /* implementation */ }
  
  // Register all functions with MCP
  registerWithMCP(mcpServer) {
    mcpServer.registerTool({
      name: "note_manager",
      functions: [
        { name: "create", method: this.create.bind(this), /* params, etc. */ },
        { name: "read", method: this.read.bind(this), /* params, etc. */ },
        /* other functions */
      ]
    });
  }
}
```

**When to use this pattern:**
- For logically related functionality
- When operations share common resources or setup
- When presenting a cohesive capability to the LLM

## Common Challenges and Solutions

### Challenge 1: Parameter Validation

Tools often receive unexpected or malformed input from LLMs.

**Solution:**

```javascript
function validateParameters(params, schema) {
  const missingRequired = schema.required.filter(field => 
    params[field] === undefined || params[field] === null
  );
  
  if (missingRequired.length > 0) {
    return {
      valid: false,
      error: `Missing required parameters: ${missingRequired.join(', ')}`
    };
  }
  
  // Type checking and other validations
  for (const [key, value] of Object.entries(params)) {
    const fieldSchema = schema.properties[key];
    if (!fieldSchema) continue;
    
    // Type checking
    if (fieldSchema.type === 'string' && typeof value !== 'string') {
      return {
        valid: false,
        error: `Parameter "${key}" must be a string`
      };
    }
    // Add additional type checks as needed
  }
  
  return { valid: true };
}
```

### Challenge 2: Error Handling and Reporting

LLMs need clear error information to respond appropriately to users.

**Solution:**

```javascript
async function executeToolSafely(toolFn, params) {
  try {
    // Validate parameters
    const validationResult = validateParameters(params, toolFn.paramSchema);
    if (!validationResult.valid) {
      return {
        status: 'error',
        error_type: 'validation',
        message: validationResult.error,
        data: null
      };
    }
    
    // Execute the tool function
    const result = await toolFn(params);
    return {
      status: 'success',
      message: 'Operation completed successfully',
      data: result
    };
  } catch (error) {
    // Classify and format the error
    const errorType = determineErrorType(error);
    
    return {
      status: 'error',
      error_type: errorType,
      message: error.message || 'An unexpected error occurred',
      data: null
    };
  }
}

function determineErrorType(error) {
  if (error.code === 'ENOENT') return 'file_not_found';
  if (error.code === 'EACCES') return 'permission_denied';
  if (error instanceof ValidationError) return 'validation';
  return 'internal_error';
}
```

## Practical Example

A complete markdown note management tool implementation:

```javascript
import fs from 'fs/promises';
import path from 'path';
import { glob } from 'glob';

class MarkdownNoteManager {
  constructor(notesDirectory) {
    this.notesDirectory = notesDirectory;
  }
  
  // Create a new note
  async createNote(params) {
    const { filename, content, template } = params;
    let noteContent = content;
    
    // Apply template if specified
    if (template && !content) {
      noteContent = await this.getTemplate(template);
    }
    
    const fullPath = this.getFullPath(filename);
    await fs.writeFile(fullPath, noteContent, 'utf8');
    
    return {
      status: 'success',
      message: `Note "${filename}" created successfully`,
      path: fullPath
    };
  }
  
  // Read a note
  async readNote(params) {
    const { filename } = params;
    const fullPath = this.getFullPath(filename);
    
    try {
      const content = await fs.readFile(fullPath, 'utf8');
      return {
        status: 'success',
        content,
        filename,
        path: fullPath
      };
    } catch (error) {
      if (error.code === 'ENOENT') {
        return {
          status: 'error',
          message: `Note "${filename}" not found`,
          error_type: 'file_not_found'
        };
      }
      throw error;
    }
  }
  
  // Search notes
  async searchNotes(params) {
    const { query, max_results = 10 } = params;
    
    // Get all markdown files
    const files = await glob('**/*.md', { cwd: this.notesDirectory });
    
    // Search results with relevance score
    const results = [];
    
    for (const file of files) {
      try {
        const content = await fs.readFile(path.join(this.notesDirectory, file), 'utf8');
        
        // Simple search implementation
        if (content.toLowerCase().includes(query.toLowerCase())) {
          // Calculate basic relevance score
          const matches = (content.toLowerCase().match(new RegExp(query.toLowerCase(), 'g')) || []).length;
          
          results.push({
            filename: file,
            relevance: matches,
            preview: this.generatePreview(content, query)
          });
        }
      } catch (error) {
        console.error(`Error searching file ${file}:`, error);
      }
    }
    
    // Sort by relevance and limit results
    const sortedResults = results
      .sort((a, b) => b.relevance - a.relevance)
      .slice(0, max_results);
    
    return {
      status: 'success',
      query,
      count: sortedResults.length,
      results: sortedResults
    };
  }
  
  // Helper methods
  getFullPath(filename) {
    const normalizedFilename = filename.endsWith('.md') ? filename : `${filename}.md`;
    return path.join(this.notesDirectory, normalizedFilename);
  }
  
  generatePreview(content, query) {
    const lowerContent = content.toLowerCase();
    const index = lowerContent.indexOf(query.toLowerCase());
    
    if (index === -1) return content.substring(0, 100) + '...';
    
    const start = Math.max(0, index - 40);
    const end = Math.min(content.length, index + query.length + 40);
    let preview = content.substring(start, end);
    
    if (start > 0) preview = '...' + preview;
    if (end < content.length) preview = preview + '...';
    
    return preview;
  }
  
  async getTemplate(templateName) {
    const templatePath = path.join(this.notesDirectory, 'templates', `${templateName}.md`);
    try {
      return await fs.readFile(templatePath, 'utf8');
    } catch (error) {
      if (error.code === 'ENOENT') {
        return `# ${templateName.charAt(0).toUpperCase() + templateName.slice(1)}\n\n`;
      }
      throw error;
    }
  }
}
```

## Summary

1. MCP tools should be clearly defined with precise descriptions and parameter specifications
2. Implementation patterns vary between atomic tools and grouped capabilities
3. Robust parameter validation and error handling are critical for reliable tool operation
4. Tools should provide meaningful feedback to the LLM for user-friendly responses

## Next Steps

In the next sub-topic, we'll explore MCP Server implementation, focusing on how to integrate multiple tools into a cohesive MCP endpoint and handle the protocol's communication requirements.

---

[<- Back to Main Topic](./01-model-context-protocol.md) | [Next Sub-Topic: Server Implementation ->](./01b-server-implementation.md)
