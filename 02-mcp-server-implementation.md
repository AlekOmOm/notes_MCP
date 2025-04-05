# 02. Server Implementation 🖥️

[<- Back: MCP Tool Development](./01a-mcp-tool-development.md) | [Next: Integration with LLM Hosts ->](./03-mcp-llm-host-integration.md)

## Table of Contents

- [Core Server Architecture](#core-server-architecture)
- [Discovery Implementation](#discovery-implementation)
- [Invocation Handling](#invocation-handling)
- [Protocol Message Formats](#protocol-message-formats)
- [Security Considerations](#security-considerations)

## Core Server Architecture

The MCP Server acts as the critical middleware between LLM Hosts and tool implementations. Its architecture must support efficient message handling, routing, and reliable communication.

### Server Components

A well-designed MCP Server consists of several core architectural components:

```javascript
// Conceptual MCP Server architecture
class MCPServer {
  constructor(options = {}) {
    this.port = options.port || 3000;
    this.tools = new Map(); // Stores registered tools
    this.server = null; // HTTP/WebSocket server instance
  }

  // Core functionality methods
  start() {
    /* Initialize and start the server */
  }
  stop() {
    /* Gracefully shut down the server */
  }
  handleRequest(request) {
    /* Process incoming MCP requests */
  }
  registerTool(tool) {
    /* Register a new tool with the server */
  }
}
```

### Communication Models

MCP Servers typically implement one of two primary communication models:

1. **REST API Model**

   - HTTP-based with JSON payloads
   - Stateless requests and responses
   - Simpler to implement but may have higher latency

2. **WebSocket Model**
   - Persistent bidirectional connection
   - Lower latency for multiple interactions
   - More complex to implement but better for interactive usage

Key points to remember:

- Choose the communication model based on expected usage patterns
- REST is simpler but WebSockets offer better performance for frequent interactions
- Consider implementing both for maximum compatibility

## Discovery Implementation

Discovery is the process by which an MCP Server advertises its capabilities to LLM Hosts.

### Tool Manifest Structure

```javascript
// Example tool manifest structure
const toolManifest = {
  protocol_version: "1.0",
  server_info: {
    name: "Markdown Notes Manager",
    version: "1.0.0",
    description: "MCP Server for managing markdown notes",
  },
  tools: [
    {
      name: "note_manager",
      description: "Create, read, update, and search markdown notes",
      functions: [
        {
          name: "create_note",
          description: "Creates a new markdown note with the given content",
          parameters: {
            type: "object",
            properties: {
              filename: {
                type: "string",
                description: "Name of the note file (will be sanitized)",
              },
              content: {
                type: "string",
                description: "Markdown content for the note",
              },
            },
            required: ["filename", "content"],
          },
          returns: {
            type: "object",
            properties: {
              status: { type: "string" },
              message: { type: "string" },
              path: { type: "string" },
            },
          },
        },
        // Additional function definitions...
      ],
    },
  ],
};
```

### Discovery Implementation Example

```javascript
// Handler for discovery requests
function handleDiscoveryRequest(request, response) {
  // Generate the current tool manifest
  const manifest = generateToolManifest();

  // Send the manifest as the response
  response.status(200).json({
    type: "mcp_discovery_response",
    manifest: manifest,
  });
}

// Generate the tool manifest from registered tools
function generateToolManifest() {
  const tools = [];

  // Iterate through registered tools
  for (const [toolName, toolDefinition] of registeredTools.entries()) {
    tools.push({
      name: toolName,
      description: toolDefinition.description,
      functions: toolDefinition.functions.map((func) => ({
        name: func.name,
        description: func.description,
        parameters: func.parameters,
        returns: func.returns,
      })),
    });
  }

  return {
    protocol_version: "1.0",
    server_info: {
      name: serverConfig.name,
      version: serverConfig.version,
      description: serverConfig.description,
    },
    tools: tools,
  };
}
```

## Invocation Handling

Invocation handling is the process of receiving tool invocation requests, executing the appropriate tool function, and returning results.

### Invocation Process

1. **Request parsing**: Validate and extract invocation details
2. **Tool resolution**: Identify the requested tool and function
3. **Parameter validation**: Ensure parameters meet the expected schema
4. **Function execution**: Call the tool implementation with validated parameters
5. **Result formatting**: Package the execution result in the proper response format
6. **Error handling**: Catch and properly format any errors that occur

### Example Implementation

```javascript
// Handler for tool invocation requests
async function handleInvocationRequest(request, response) {
  try {
    // Extract request details
    const { tool, function: functionName, parameters } = request.body;

    // Validate request
    if (!tool || !functionName) {
      return response.status(400).json({
        type: "mcp_invocation_error",
        error: "Missing required fields 'tool' and/or 'function'",
      });
    }

    // Check if tool exists
    if (!registeredTools.has(tool)) {
      return response.status(404).json({
        type: "mcp_invocation_error",
        error: `Tool '${tool}' not found`,
      });
    }

    // Get tool definition
    const toolDefinition = registeredTools.get(tool);

    // Find the requested function
    const functionDef = toolDefinition.functions.find(
      (f) => f.name === functionName
    );
    if (!functionDef) {
      return response.status(404).json({
        type: "mcp_invocation_error",
        error: `Function '${functionName}' not found in tool '${tool}'`,
      });
    }

    // Validate parameters against schema
    const validationResult = validateParameters(
      parameters,
      functionDef.parameters
    );
    if (!validationResult.valid) {
      return response.status(400).json({
        type: "mcp_invocation_error",
        error: `Parameter validation failed: ${validationResult.error}`,
      });
    }

    // Execute the function
    const result = await functionDef.implementation(parameters);

    // Return the result
    response.status(200).json({
      type: "mcp_invocation_response",
      tool: tool,
      function: functionName,
      result: result,
    });
  } catch (error) {
    console.error("Error handling invocation:", error);
    response.status(500).json({
      type: "mcp_invocation_error",
      error: `Internal server error: ${error.message}`,
    });
  }
}
```

## Protocol Message Formats

Standardized message formats ensure compatibility between different MCP implementations.

### Comparison Table

| Message Type        | Direction             | Purpose                 | Key Fields                                                            |
| ------------------- | --------------------- | ----------------------- | --------------------------------------------------------------------- |
| Discovery Request   | LLM Host → MCP Server | Request available tools | `type: "mcp_discover"`                                                |
| Discovery Response  | MCP Server → LLM Host | Provide tool manifest   | `type: "mcp_discovery_response", manifest: {...}`                     |
| Invocation Request  | LLM Host → MCP Server | Execute a tool function | `type: "mcp_invoke", tool: "...", function: "...", parameters: {...}` |
| Invocation Response | MCP Server → LLM Host | Return execution result | `type: "mcp_invocation_response", result: {...}`                      |
| Error Response      | MCP Server → LLM Host | Communicate errors      | `type: "mcp_error", error: "...", details: {...}`                     |

### Real-world Considerations

When implementing these message formats:

1. Include version information to handle protocol evolution
2. Provide detailed error information to aid in debugging
3. Use consistent field naming across all message types
4. Consider adding correlation IDs for request/response matching
5. Document extensions to the standard protocol clearly

## Security Considerations

MCP Servers must implement appropriate security measures to protect both the server and connected systems.

### Implementation Steps

1. **Authentication**

   ```javascript
   // Example authentication middleware
   function authMiddleware(req, res, next) {
     const apiKey = req.headers["x-api-key"];

     if (!apiKey || !validateApiKey(apiKey)) {
       return res.status(401).json({
         type: "mcp_error",
         error: "Unauthorized access",
       });
     }

     next();
   }
   ```

2. **Authorization**
   Implement tool-specific permissions to control which clients can access which tools.

3. **Input Validation**
   Thoroughly validate all input parameters to prevent injection attacks.

4. **Rate Limiting**
   Protect against abuse with appropriate rate limiting:

   ```javascript
   const rateLimit = require("express-rate-limit");

   const limiter = rateLimit({
     windowMs: 15 * 60 * 1000, // 15 minutes
     max: 100, // Limit each IP to 100 requests per windowMs
     message: {
       type: "mcp_error",
       error: "Too many requests, please try again later",
     },
   });

   app.use("/mcp", limiter);
   ```

5. **Secure Configuration**
   Protect sensitive configuration data using environment variables or secure storage.

### Advanced Technique

For enhanced security, implement capability-based authorization:

```javascript
class SecureToolRegistry {
  constructor() {
    this.tools = new Map();
    this.clientPermissions = new Map();
  }

  registerTool(toolDefinition) {
    this.tools.set(toolDefinition.name, toolDefinition);
  }

  registerClient(clientId, permissions) {
    this.clientPermissions.set(clientId, permissions);
  }

  canClientAccessTool(clientId, toolName, functionName) {
    if (!this.clientPermissions.has(clientId)) {
      return false;
    }

    const permissions = this.clientPermissions.get(clientId);

    // Check for wildcard permission
    if (permissions.includes("*")) {
      return true;
    }

    // Check for tool-level permission
    if (permissions.includes(`${toolName}:*`)) {
      return true;
    }

    // Check for specific function permission
    return permissions.includes(`${toolName}:${functionName}`);
  }

  async executeToolFunction(clientId, toolName, functionName, parameters) {
    // Check authorization
    if (!this.canClientAccessTool(clientId, toolName, functionName)) {
      throw new Error("Unauthorized access to tool function");
    }

    // Get tool and function
    const tool = this.tools.get(toolName);
    if (!tool) {
      throw new Error(`Tool '${toolName}' not found`);
    }

    const func = tool.functions.find((f) => f.name === functionName);
    if (!func) {
      throw new Error(
        `Function '${functionName}' not found in tool '${toolName}'`
      );
    }

    // Execute function with parameters
    return await func.implementation(parameters);
  }
}
```

### Best Practices

1. **Principle of Least Privilege**: Only grant the minimum permissions necessary
2. **Defense in Depth**: Implement multiple layers of security controls
3. **Regular Auditing**: Monitor and log all access and operations
4. **Secure Defaults**: All security features should be enabled by default
5. **Keep Dependencies Updated**: Regularly update all dependencies to patch security vulnerabilities

---

[<- Back: MCP Tool Development](./01a-mcp-tool-development.md) | [Next: Integration with LLM Hosts ->](./03-mcp-llm-host-integration.md)
