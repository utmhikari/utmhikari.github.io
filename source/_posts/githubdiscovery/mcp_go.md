---
title: 【GitHub探索】mcp-go，MCP协议的Golang-SDK
date: 2025/04/12 23:37:07
categories:
- GitHub探索
tags:
- Golang
- MCP
- AI
- mcp-go
- LLM
---

近期大模型Agent应用开发方面，MCP的概念比较流行，基于MCP的ToolServer能力开发也逐渐成为主流趋势。由于笔者工作原因，主力是Go语言，为了调研大模型应用开发，也接触到了[mcp-go](https://github.com/mark3labs/mcp-go)这套MCP的SDK实现。

对于企业内部而言，在这个SDK基础上做封装，基本上就能够完善MCP-Server的开发生态。因此今天就简单看一下这个SDK里面，实现了什么东西。

首先是Client连接的实现，这里可以看到每次连接都需要InitializeRequest、InitializeResult以及InitializeNotification这[三次握手](https://modelcontextprotocol.io/docs/concepts/architecture)。从Client角度看逻辑是这样：

<!-- more -->

```go
func (c *StdioMCPClient) Initialize(
	ctx context.Context,
	request mcp.InitializeRequest,
) (*mcp.InitializeResult, error) {
	// This structure ensures Capabilities is always included in JSON
	params := struct {
		ProtocolVersion string                 `json:"protocolVersion"`
		ClientInfo      mcp.Implementation     `json:"clientInfo"`
		Capabilities    mcp.ClientCapabilities `json:"capabilities"`
	}{
		ProtocolVersion: request.Params.ProtocolVersion,
		ClientInfo:      request.Params.ClientInfo,
		Capabilities:    request.Params.Capabilities, // Will be empty struct if not set
	}

	response, err := c.sendRequest(ctx, "initialize", params)
	if err != nil {
		return nil, err
	}

	var result mcp.InitializeResult
	if err := json.Unmarshal(*response, &result); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	// Store capabilities
	c.capabilities = result.Capabilities

	// Send initialized notification
	notification := mcp.JSONRPCNotification{
		JSONRPC: mcp.JSONRPC_VERSION,
		Notification: mcp.Notification{
			Method: "notifications/initialized",
		},
	}

	notificationBytes, err := json.Marshal(notification)
	if err != nil {
		return nil, fmt.Errorf(
			"failed to marshal initialized notification: %w",
			err,
		)
	}
	notificationBytes = append(notificationBytes, '\n')

	if _, err := c.stdin.Write(notificationBytes); err != nil {
		return nil, fmt.Errorf(
			"failed to send initialized notification: %w",
			err,
		)
	}

	c.initialized = true
	return &result, nil
}
```

握手的校验当前还比较粗糙，没有对版本号之类的兼容性做校验。两次握手后Client确认Notification（单向消息）可以发出去，就代表可以建立连接了。

从利于应用开发的角度，开发框架有SDK的话，最好是再封装一层Client把Initialize握手步骤也代理掉，然后把其他List/Call协议也封装成接口，这样对开发者比较方便一些。

然后看Server端的实现，主要包括：资源/Prompt/Tool的管理、C2S的Notification的处理，以及S2C单点Notification跟广播能力。说白了就是无状态、长连接都同时能支持上。

```go
// NewMCPServer creates a new MCP server instance with the given name, version and options
func NewMCPServer(
	name, version string,
	opts ...ServerOption,
) *MCPServer {
	s := &MCPServer{
		resources:            make(map[string]resourceEntry),
		resourceTemplates:    make(map[string]resourceTemplateEntry),
		prompts:              make(map[string]mcp.Prompt),
		promptHandlers:       make(map[string]PromptHandlerFunc),
		tools:                make(map[string]ServerTool),
		name:                 name,
		version:              version,
		notificationHandlers: make(map[string]NotificationHandlerFunc),
		capabilities: serverCapabilities{
			tools:     nil,
			resources: nil,
			prompts:   nil,
			logging:   false,
		},
	}

	for _, opt := range opts {
		opt(s)
	}

	return s
}
```

应用角度就比较简单了，Server端可以基于examples/everything/main.go的实现做扩展，Client端长期来看用SSE的连接方式比较多，参考client/sse_test.go的实现做扩充即可。