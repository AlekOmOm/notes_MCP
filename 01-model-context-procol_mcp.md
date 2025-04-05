# 01. Model-Context-Protocol (MCP) 🔌

[<- Back to Main Note](./README.md) | [Next: Implementation Guide ->](./02-implementation-guide.md)

## Table of Contents

- [Definition](#definition)
- [Architecture](#architecture)
- [Components](#components)
- [Protocol Flow](#protocol-flow)
- [Implementation Considerations](#implementation-considerations)

## Definition

Model-Context-Protocol (MCP) is a specification designed to standardize communication between AI Language Models and external resources. It enables decoupling between LLM hosts and tools/context sources, creating a unified interface for interaction.

### Core Concepts

MCP manages two primary resource types:

- **Tools:** External services or functions that AI models invoke to perform actions or retrieve specific information
- **Context Sources:** Providers of relevant information that AI models use to inform responses without necessarily executing actions

The fundamental goal of MCP is decoupling, comparable to USB for AI tools:

```javascript
// Conceptual benefits of MCP decoupling
const mcpBenefits = {
  forLLMHosts: "Interact with various tools without knowing implementation details",
  forToolDevelopers: "Create services usable by any MCP-compatible LLM host",
  forUsers: "Seamless integration of diverse capabilities into AI interactions"
};
```

Key points to remember:
- MCP standardizes communication protocols between LLMs and external resources
- It creates clear interfaces for tool and context source integration
- The protocol enables plug-and-play functionality across compatible systems

## Architecture

The MCP architecture consists of a standardized communication flow between several distinct components.

### System Overview

```
+-------------------+       +-------------------+       +-----------------+       +-----------+
| User /            | ----> | LLM Host /        | ----> | MCP Server      | ----> | Tool /    |
| Host Client       |       | Host Application  |       | (Implements MCP)|       | Context   |
| (e.g., Claude     | <---- | (e.g., Claude     | <---- |                 | <---- | Source    |
| Desktop)          |       | Backend Service)  |       |                 |       | (e.g., .md|
+-------------------+       +-------------------+       +-----------------+       | notes API)|
                                     ^                                            +-----------+
                                     |
                                     v
                             +-----------------+
                             | Large Language  |
                             | Model (LLM)     |
                             +-----------------+
```

### Common Patterns

MCP follows client-server architecture with standardized message formats for discovery, invocation, and response. The protocol establishes clear boundaries between:

1. User interface/experience
2. LLM processing and decision-making
3. Tool/context management
4. Actual tool implementation

## Components

The MCP ecosystem consists of several key components with specific responsibilities.

### LLM Host Client

- User-facing application (e.g., Claude Desktop)
- Handles user interaction and communicates with LLM Host
- May be configured to specify which MCP Server to use

### LLM Host (Host Application)

- Core application/backend that hosts the LLM
- Manages LLM interaction (sending prompts, receiving responses)
- Acts as the MCP Client that communicates with MCP Server
- Initiates tool usage based on LLM decisions

### MCP Server

Central intermediary component that:

- Implements server-side Model-Context-Protocol
- Handles discovery, invocation, routing, communication, and response formatting
- Manages tool and context source registration

#### Internal Server Components

The MCP Server contains several conceptual subcomponents:

| Component | Function | Implementation Role |
|----------|------|------|
| Protocol Listener | Handles incoming connections from LLM Hosts | Core infrastructure |
| Request Parser | Interprets MCP message formats | Core infrastructure |
| Service Registry | Tracks available tools and generates discovery info | Core + custom tools |
| Tool/Context Connectors | Links to specific tool implementations | Custom implementation |
| Response Formatter | Packages results into MCP format | Core infrastructure |

### Tools / Context Sources

- Backend services, functions, APIs, or data stores
- Perform requested actions or provide information
- Implement specific business logic (e.g., markdown file operations)
- Return results to MCP Server for formatting and relay

## Protocol Flow

MCP communication follows a standard sequence of operations.

### Implementation Steps

1. **Connection & Discovery**
   ```javascript
   // Pseudocode: Discovery request
   const discoveryRequest = {
     type: "mcp_discover",
     version: "1.0"
   };
   ```

2. **Capability Advertising**
   MCP Server responds with available tools and their interfaces

3. **LLM Decision Process**
   LLM determines when to use a tool based on user request and available tools

4. **Invocation Request**
   ```javascript
   // Pseudocode: Tool invocation
   const invokeRequest = {
     type: "mcp_tool_invoke",
     tool: "markdown_note_creator",
     arguments: {
       filename: "meeting-notes.md",
       content: "# Meeting Notes\n\n- Discussion items..."
     }
   };
   ```

5. **Server Processing**
   MCP Server routes request to appropriate tool connector

6. **Tool Execution**
   Tool logic runs with provided arguments

7. **Result Return**
   Tool returns execution results to MCP Server connector

8. **Response to Host**
   MCP Server formats and returns results to LLM Host

9. **LLM Integration**
   LLM Host incorporates tool results into its response process

## Implementation Considerations

When building MCP Servers and tools, consider these best practices:

### Best Practices

1. **Clear Tool Descriptions**: Provide detailed descriptions for LLMs to understand when and how to use your tools
2. **Parameter Validation**: Implement thorough validation of incoming tool parameters
3. **Error Handling**: Design robust error handling with informative messages
4. **Security Considerations**: Implement authentication and authorization for sensitive operations
5. **Scalability Planning**: Design for potential growth in tool complexity and usage volume

### Advanced Technique

When implementing a markdown note manager via MCP:

```javascript
// Advanced implementation for markdown note management
class MarkdownNoteManager {
  constructor(baseDirectory) {
    this.baseDirectory = baseDirectory;
  }
  
  async createNote(filename, content) {
    // Sanitize filename
    const safeName = this.sanitizeFilename(filename);
    const fullPath = path.join(this.baseDirectory, safeName);
    
    // Write file
    await fs.promises.writeFile(fullPath, content, 'utf8');
    
    return {
      status: "success",
      message: `Note created at ${fullPath}`,
      path: fullPath
    };
  }
  
  // Additional methods for note operations
  async readNote(filename) { /* ... */ }
  async searchNotes(query) { /* ... */ }
  async listNotes() { /* ... */ }
  
  // Helper methods
  sanitizeFilename(filename) { /* ... */ }
}
```

---

[<- Back to Main Note](./README.md) | [Next: Implementation Guide ->](./02-implementation-guide.md)
