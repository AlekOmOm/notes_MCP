# 05. Best Practices 💡

[<- Back to Markdown Note Manager Example ](./04-mcp-markdown-note-manager.md) | [Next: Advanced Applications ->](./06-advanced-applications.md)

## Table of Contents

- [Performance Optimization](#performance-optimization)
- [Security Considerations](#security-considerations)
- [Maintainability](#maintainability)
- [Reliability](#reliability)
- [Testing Strategy](#testing-strategy)

## Performance Optimization

Optimizing MCP Server performance ensures responsiveness and scalability when interacting with LLM Hosts.

### Efficient Tool Implementation

```javascript
// Inefficient implementation
async function searchNotesInefficient(query) {
  // Read all notes into memory at once
  const allNotes = await getAllNotes();

  // Search through all notes
  return allNotes.filter((note) => note.content.includes(query));
}

// Optimized implementation
async function searchNotesOptimized(query) {
  // Stream files and process incrementally
  const results = [];
  const fileStream = createNoteStream();

  for await (const note of fileStream) {
    // Check if note matches query without loading entire content
    const matches = await checkNoteMatches(note.path, query);
    if (matches) {
      results.push({
        path: note.path,
        preview: await generatePreview(note.path, query),
      });
    }
  }

  return results;
}
```

### Caching Strategies

Implementing appropriate caching improves response times for frequent operations:

| Operation      | Caching Strategy     | Benefits                                | Considerations                    |
| -------------- | -------------------- | --------------------------------------- | --------------------------------- |
| Tool Discovery | Long-lived cache     | Reduced latency for new connections     | Must invalidate on tool changes   |
| Note Listing   | Short-lived cache    | Faster directory browsing               | Need to refresh on file changes   |
| Note Content   | Content-hash-based   | Efficient for frequently accessed notes | Storage requirements              |
| Search Results | Query-based with TTL | Faster repeat searches                  | Staleness vs. performance balance |

### Connection Optimization

```javascript
// WebSocket connection pooling
class MCPConnectionPool {
  constructor(maxConnections = 10) {
    this.connections = new Map();
    this.maxConnections = maxConnections;
  }

  async getConnection(serverUrl) {
    // Return existing connection if available
    if (this.connections.has(serverUrl)) {
      const conn = this.connections.get(serverUrl);
      if (conn.isActive()) return conn;
    }

    // Create new connection
    if (this.connections.size >= this.maxConnections) {
      this.evictLeastRecentlyUsed();
    }

    const connection = await createMCPConnection(serverUrl);
    this.connections.set(serverUrl, connection);

    return connection;
  }

  evictLeastRecentlyUsed() {
    // Find and close least recently used connection
    let oldest = null;
    let oldestLastUsed = Date.now();

    for (const [url, conn] of this.connections.entries()) {
      if (conn.lastUsed < oldestLastUsed) {
        oldest = url;
        oldestLastUsed = conn.lastUsed;
      }
    }

    if (oldest) {
      const oldConn = this.connections.get(oldest);
      oldConn.close();
      this.connections.delete(oldest);
    }
  }
}
```

### Real-world Considerations

When optimizing MCP implementations:

1. **Measure Before Optimizing**: Establish performance baselines and identify bottlenecks
2. **Consider Request Patterns**: Optimize for the most common request types
3. **Balance Memory and Speed**: Choose appropriate data structures and algorithms
4. **Asynchronous Processing**: Use non-blocking operations for I/O-heavy tasks
5. **Resource Pooling**: Reuse expensive resources like database connections

## Security Considerations

Implementing robust security measures is critical for MCP implementations.

### Authentication & Authorization

```javascript
// Advanced JWT-based authentication and authorization
const jwt = require("jsonwebtoken");

// Authentication middleware
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({
      type: "mcp_error",
      error: "Authentication required",
    });
  }

  const token = authHeader.substring(7); // Remove 'Bearer ' prefix

  try {
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Attach user info to request
    req.user = {
      id: decoded.sub,
      roles: decoded.roles || [],
      permissions: decoded.permissions || [],
    };

    next();
  } catch (error) {
    return res.status(401).json({
      type: "mcp_error",
      error: "Invalid or expired token",
    });
  }
}

// Permission check middleware
function requirePermission(permission) {
  return (req, res, next) => {
    // Check if user has required permission
    if (!req.user || !req.user.permissions.includes(permission)) {
      return res.status(403).json({
        type: "mcp_error",
        error: "Insufficient permissions",
      });
    }

    next();
  };
}
```

### Input Validation

Thorough validation prevents security vulnerabilities:

```javascript
// Deep parameter validation using JSON Schema
const Ajv = require("ajv");
const ajv = new Ajv({ allErrors: true });

function validateToolParameters(schema, params) {
  const validate = ajv.compile(schema);
  const valid = validate(params);

  if (!valid) {
    return {
      valid: false,
      errors: validate.errors.map((err) => ({
        path: err.instancePath,
        message: err.message,
      })),
    };
  }

  return { valid: true };
}
```

### Secure Defaults

Always implement secure defaults to prevent accidental vulnerabilities:

1. **Access Control**: Default to no access, explicitly grant permissions
2. **Input Sanitization**: Sanitize all inputs by default
3. **Output Encoding**: Encode all outputs to prevent injection attacks
4. **Authentication**: Require authentication for all sensitive operations

## Maintainability

Building maintainable MCP implementations ensures longevity and adaptability.

### Modular Architecture

```javascript
// Modular tool registration system
class ToolRegistry {
  constructor() {
    this.tools = new Map();
    this.eventEmitter = new EventEmitter();
  }

  // Register a tool
  registerTool(tool) {
    this.validateTool(tool);
    this.tools.set(tool.name, tool);
    this.eventEmitter.emit("tool:registered", tool.name);
    return this;
  }

  // Unregister a tool
  unregisterTool(toolName) {
    if (this.tools.has(toolName)) {
      this.tools.delete(toolName);
      this.eventEmitter.emit("tool:unregistered", toolName);
    }
    return this;
  }

  // Get all registered tools
  getTools() {
    return Array.from(this.tools.values());
  }

  // Subscribe to registry events
  on(event, handler) {
    this.eventEmitter.on(event, handler);
    return this;
  }

  // Validate tool definition
  validateTool(tool) {
    // Validation logic
  }
}
```

### Versioning Strategy

Implement explicit versioning to maintain backward compatibility:

```javascript
// Version-aware request handling
function handleRequest(req, res) {
  const requestedVersion = req.headers["mcp-version"] || "1.0";

  // Route to appropriate version handler
  if (semver.satisfies(requestedVersion, ">=2.0.0")) {
    return handleV2Request(req, res);
  } else {
    return handleV1Request(req, res);
  }
}
```

### Logging and Monitoring

Comprehensive logging enables debugging and performance monitoring:

```javascript
// Structured logging
const logger = winston.createLogger({
  level: "info",
  format: winston.format.json(),
  defaultMeta: { service: "mcp-server" },
  transports: [
    new winston.transports.File({ filename: "error.log", level: "error" }),
    new winston.transports.File({ filename: "combined.log" }),
  ],
});

// Log request middleware
function logRequestMiddleware(req, res, next) {
  const startTime = Date.now();

  // Capture response
  const originalEnd = res.end;
  res.end = function (...args) {
    const responseTime = Date.now() - startTime;

    logger.info({
      type: "request",
      method: req.method,
      path: req.path,
      requestId: req.headers["x-request-id"],
      statusCode: res.statusCode,
      responseTime,
    });

    originalEnd.apply(res, args);
  };

  next();
}
```

## Reliability

Ensuring reliability is crucial for production MCP implementations.

### Error Handling

Implement comprehensive error handling:

```javascript
// Error boundary for tool execution
async function executeToolWithErrorBoundary(tool, funcName, params) {
  try {
    const result = await tool.functions[funcName].implementation(params);
    return {
      status: "success",
      result,
    };
  } catch (error) {
    logger.error("Tool execution failed", {
      tool: tool.name,
      function: funcName,
      error: error.message,
      stack: error.stack,
    });

    return {
      status: "error",
      error: {
        message: "Tool execution failed",
        details: error.message,
        code: error.code || "EXECUTION_ERROR",
      },
    };
  }
}
```

### Graceful Degradation

Design systems that can continue functioning with reduced capabilities:

```javascript
// Graceful degradation for tool invocation
async function invokeToolWithFallback(toolName, funcName, params) {
  try {
    // Try primary tool
    return await invokeTool(toolName, funcName, params);
  } catch (error) {
    // Check if we have a fallback
    if (hasFallback(toolName, funcName)) {
      logger.warn(`Using fallback for ${toolName}.${funcName}`);
      return await invokeFallback(toolName, funcName, params);
    }

    // Fallback with simpler operation if possible
    if (canUsePartialOperation(toolName, funcName)) {
      logger.warn(`Using partial operation for ${toolName}.${funcName}`);
      return await invokePartialOperation(toolName, funcName, params);
    }

    // No fallback available
    throw error;
  }
}
```

## Testing Strategy

A comprehensive testing strategy ensures reliable MCP implementations.

### Unit Testing

Test individual components in isolation:

```javascript
// Unit test for tool function
test("searchNotes should find notes containing query string", async () => {
  // Arrange
  const mockFS = {
    readdir: jest.fn().mockResolvedValue(["note1.md", "note2.md"]),
    readFile: jest
      .fn()
      .mockResolvedValueOnce("content with test")
      .mockResolvedValueOnce("other content"),
  };

  // Setup test subject with mocked dependencies
  const searchNotes = createSearchNotesFunction(mockFS, "/notes");

  // Act
  const result = await searchNotes({ query: "test" });

  // Assert
  expect(result.status).toBe("success");
  expect(result.results).toHaveLength(1);
  expect(result.results[0].filename).toBe("note1.md");
});
```

### Integration Testing

Test interaction between components:

```javascript
// Integration test for MCP Server
test("MCP Server should handle discovery and invocation", async () => {
  // Start test server
  const server = new MCPServer({
    port: 0, // Use random available port
    tools: [mockTool],
  });

  await server.start();
  const port = server.getPort();

  // Create client
  const client = new MCPClient(`http://localhost:${port}`);

  // Test discovery
  const discovery = await client.discoverTools();
  expect(discovery.manifest.tools).toHaveLength(1);
  expect(discovery.manifest.tools[0].name).toBe("mock_tool");

  // Test invocation
  const result = await client.invokeTool("mock_tool", "test_function", {
    param: "value",
  });
  expect(result.status).toBe("success");

  // Clean up
  await server.stop();
});
```

### End-to-End Testing

Test the complete system with real LLM Hosts:

```javascript
// End-to-end test with LLM Host
test("LLM should be able to discover and use tools", async () => {
  // Start MCP Server
  const mcpServer = new MCPServer({
    port: 0,
    tools: [testNoteManager],
  });

  await mcpServer.start();
  const mcpPort = mcpServer.getPort();

  // Start LLM Host with connection to MCP Server
  const llmHost = new LLMHost({
    model: "test-model",
    mcpServers: [`http://localhost:${mcpPort}`],
  });

  await llmHost.start();
  const llmPort = llmHost.getPort();

  // Connect client to LLM Host
  const client = new LLMClient(`http://localhost:${llmPort}`);

  // Send message that should trigger tool use
  const response = await client.sendMessage({
    conversationId: "test",
    message: "Create a note titled Test Note with content Hello World",
  });

  // Verify response includes tool execution
  expect(response.toolExecutions).toHaveLength(1);
  expect(response.toolExecutions[0].tool).toBe("note_manager");
  expect(response.toolExecutions[0].function).toBe("create_note");

  // Clean up
  await llmHost.stop();
  await mcpServer.stop();
});
```

### Best Practices

1. **Comprehensive Test Coverage**: Test all aspects of the system
2. **Automated Testing**: Implement CI/CD pipelines with automated tests
3. **Testing in Production**: Use feature flags and canary deployments
4. **Performance Testing**: Monitor response times and resource usage
5. **Security Testing**: Regular security audits and penetration testing

---

[<- Back to Markdown Note Manager Example ](./04-mcp-markdown-note-manager.md) | [Next: Advanced Applications ->](./06-advanced-applications.md)
