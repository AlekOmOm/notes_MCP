# 03. Integration with LLM Hosts 🔄

[<- Back to Server Implementation](./02-mcp-server-implementation.md) | [Next: Markdown Note Manager Example ->](./04-mcp-markdown-note-manager.md)

## Table of Contents

- [Understanding LLM Hosts](#understanding-llm-hosts)
- [Connection Protocols](#connection-protocols)
- [Compatibility Requirements](#compatibility-requirements)
- [Testing and Debugging](#testing-and-debugging)
- [Optimizing LLM Tool Usage](#optimizing-llm-tool-usage)

## Understanding LLM Hosts

LLM Host applications bridge between user interfaces and AI language models, managing both the interaction with models and the connection to MCP Servers.

### Host Architecture

LLM Hosts typically consist of several core components:

```javascript
// Conceptual LLM Host architecture
class LLMHost {
  constructor() {
    this.llm = new LanguageModel(); // The AI model
    this.mcpClients = new Map(); // Connected MCP servers
    this.conversations = new Map(); // Active conversations
  }

  // Core methods
  async processUserInput(conversationId, userInput) {
    /* ... */
  }
  async connectToMCPServer(serverUrl, options) {
    /* ... */
  }
  async invokeTool(serverUrl, tool, func, params) {
    /* ... */
  }
}
```

### Host Responsibilities

1. **Model Management**: Handling interaction with the underlying language model
2. **Context Maintenance**: Preserving conversation history and context
3. **Tool Discovery**: Finding and registering available MCP Server capabilities
4. **Tool Selection**: Determining when to use tools based on model output
5. **Tool Invocation**: Calling MCP Server functions and handling responses
6. **Response Integration**: Incorporating tool results into model interactions

Key points to remember:

- The LLM Host mediates between the user, the language model, and external tools
- Host applications may be desktop, web, mobile, or API-based services
- Different hosts may implement varying levels of MCP support

## Connection Protocols

Establishing and maintaining connections between LLM Hosts and MCP Servers requires standardized protocols.

### Connection Initialization

```javascript
// Example connection flow
async function initializeMCPConnection(serverUrl) {
  try {
    // Step 1: Establish connection
    const connection = await createConnection(serverUrl);

    // Step 2: Send discovery request
    const discoveryResponse = await connection.sendDiscoveryRequest();

    // Step 3: Process tool manifest
    const toolManifest = discoveryResponse.manifest;
    registerAvailableTools(toolManifest);

    // Step 4: Update LLM system prompt with tool descriptions
    updateLLMWithToolDescriptions(toolManifest);

    return {
      status: "connected",
      serverInfo: toolManifest.server_info,
      tools: toolManifest.tools,
    };
  } catch (error) {
    console.error("Failed to initialize MCP connection:", error);
    return {
      status: "error",
      error: error.message,
    };
  }
}
```

### Common Patterns

Different patterns for integrating MCP with host applications:

1. **Direct Integration**: Host directly implements MCP client protocol
2. **Plugin/Extension Architecture**: MCP support via pluggable components
3. **Proxy Pattern**: Intermediate service translates between host and MCP servers

## Compatibility Requirements

Ensuring compatibility requires adhering to protocol specifications and implementing required features.

### Comparison Table

| Feature             | Minimum Requirement     | Enhanced Support            | Best Practice                   |
| ------------------- | ----------------------- | --------------------------- | ------------------------------- |
| Protocol Version    | Support latest stable   | Support multiple versions   | Negotiate version on connection |
| Authentication      | API key support         | OAuth or JWT tokens         | Configurable auth mechanisms    |
| Tool Discovery      | Basic discovery         | Categorized tool listings   | Dynamic discovery and updates   |
| Invocation          | Basic parameter passing | Full JSON Schema validation | Structured error handling       |
| Response Processing | Simple success/error    | Typed responses             | Schema-validated responses      |
| Error Handling      | Basic error codes       | Detailed error messages     | Guidance for error resolution   |

### Real-world Considerations

When integrating with LLM hosts:

1. Consider varying capabilities across different host implementations
2. Build for backward compatibility where possible
3. Implement graceful degradation for unsupported features
4. Document compatibility requirements clearly
5. Test with multiple host implementations

## Testing and Debugging

Thorough testing ensures reliable integration between MCP Servers and LLM Hosts.

### Implementation Steps

1. **Unit Testing MCP Clients**

   ```javascript
   // Example unit test for MCP client
   test("should successfully discover tools", async () => {
     // Mock server response
     mockServer.onGet("/discover").reply(200, {
       type: "mcp_discovery_response",
       manifest: {
         protocol_version: "1.0",
         server_info: { name: "Test Server", version: "1.0.0" },
         tools: [{ name: "test_tool", functions: [] }],
       },
     });

     // Test client discovery
     const client = new MCPClient("http://mockserver");
     const result = await client.discoverTools();

     // Assertions
     expect(result.status).toBe("success");
     expect(result.manifest.tools).toHaveLength(1);
     expect(result.manifest.tools[0].name).toBe("test_tool");
   });
   ```

2. **Integration Testing**
   Create end-to-end tests that verify the full flow from user input to tool execution and response.

3. **Mock LLM for Testing**
   Implement a mock language model that generates predictable tool usage for testing.

4. **Protocol Validation**
   Verify that all messages conform to the MCP specification.

5. \*\*Debugging Instrumentationn

   ```javascript
   class DebugMCPClient extends MCPClient {
     constructor(serverUrl, options = {}) {
       super(serverUrl, options);
       this.enableTracing = options.trace || false;
       this.traceLog = [];
     }

     async sendRequest(endpoint, data) {
       if (this.enableTracing) {
         this.traceLog.push({
           timestamp: new Date(),
           direction: "outgoing",
           endpoint,
           data: JSON.parse(JSON.stringify(data)),
         });
       }

       try {
         const response = await super.sendRequest(endpoint, data);

         if (this.enableTracing) {
           this.traceLog.push({
             timestamp: new Date(),
             direction: "incoming",
             endpoint,
             data: JSON.parse(JSON.stringify(response)),
           });
         }

         return response;
       } catch (error) {
         if (this.enableTracing) {
           this.traceLog.push({
             timestamp: new Date(),
             direction: "error",
             endpoint,
             error: error.message,
           });
         }
         throw error;
       }
     }

     getTraceLog() {
       return this.traceLog;
     }

     clearTraceLog() {
       this.traceLog = [];
     }
   }
   ```

## Optimizing LLM Tool Usage

Enhancing how LLMs interact with MCP tools improves overall system effectiveness.

### Advanced Technique

Implementing tool-aware prompting to guide LLM tool selection:

```javascript
// Tool-aware prompting technique
function generateToolAwarePrompt(toolManifest, userQuery) {
  // Extract tool descriptions
  const toolDescriptions = toolManifest.tools
    .map((tool) => {
      const functions = tool.functions
        .map((fn) => `  - ${fn.name}: ${fn.description}`)
        .join("\n");

      return `${tool.name}: ${tool.description}\nFunctions:\n${functions}`;
    })
    .join("\n\n");

  // Create system prompt
  return `You have access to the following tools:
  
${toolDescriptions}

When a user's request can be fulfilled using one of these tools, use it.
To use a tool, respond with a JSON object specifying the tool name, function, and parameters.

User query: ${userQuery}`;
}
```

### Tool Selection Optimization

Improving how and when LLMs decide to use tools:

1. **Clear Tool Descriptions**: Ensure tool descriptions clearly convey capabilities
2. **Example Usage**: Include example invocations in tool documentation
3. **Function Naming**: Use intuitive, descriptive names for tool functions
4. **Parameter Descriptions**: Document parameters with clear descriptions and constraints
5. **Tool Categories**: Group related tools to aid in discovery and selection

### Best Practices

1. **Prompt Engineering**: Craft prompts that guide effective tool selection
2. **Contextual Hints**: Provide usage hints within the conversation context
3. **Error-Resilient Design**: Design for graceful handling of incorrect tool usage
4. **Response Templates**: Standardize how tool results are presented to users
5. **Feedback Loops**: Collect and analyze tool usage patterns to improve selection

---

[<- Back to Server Implementation](./02-mcp-server-implementation.md) | [Next: Markdown Note Manager Example ->](./04-mcp-markdown-note-manager.md)
