---
title: 【极客日常】用Eino+Ollama低成本研发LLM的Agent
date: 2025/10/06 13:04:36
categories:
- 极客日常
tags:
- LLM
- Eino
- Ollama
- Agent
- LangChain
---

十一国庆正是充电的好时机，借着假期时间充裕，笔者又浅调研了一下本地LLM开发相关的工具链，看下如果是日常业余搞个人LLM的Agent项目，具体有哪些能力可用。工业界的话，因为知识保密性等各种原因，我们可能会用到兄弟部门的LLM模型或者相关Agent能力，以及市面上收费但企业内部免费的一些技术基建。但如果是个人搞LLM应用开发，就更加倾向于看有没有低成本甚至免费的办法去做本地研发了。

基于这个目的，经过一番调研实操，发现只需要一个Agent开发框架加上模型Provider就能解决问题。因此本文就介绍一下，以Agent开发框架Eino，加上Ollama这个模型Provider，如何能够低成本研发LLM的Agent。针对这个主题，虽然以前也写过[用Coze开源版研发的Case](https://utmhikari.top/2025/08/10/geekdaily/develop_agent_by_coze/)，但Coze本身作为一套工业界产品基建，直接拿它工作还是比较重的，本文暂且只讨论一些比较轻量的事情。

<!-- more -->

首先咱们需要理解模型对标现实中的啥，具体怎么提升生产力。按笔者粗浅理解的话，一个模型实例就相当于一个大脑，它节省开发者工作量的地方在于，以前的程序是开发者一行行代码编写出来的，而现在我们可以通过微调或者工具增强等方式定制化一个大脑，使得在尽可能减少确定性折损的条件下，低成本做多模态的数据转换，甚至实现另一套我们需要的程序。不管这个理解是不是精确，但至少有了这个想法的话，开发一个LLM应用思路会清晰的多。

在本地，我们可以借助[Ollama](https://ollama.com/)工具管理多个大脑，每个大脑有不同的能力，比如gemma3可以处理视觉信息，qwen3可以做外部工具识别，bge-m3可以做文本向量化（embedding），deepseek-r1具备自思考能力，然后基本上每个模型都有问答能力，等等。在具体实现上，我们可以组合不同的模型，打造一套完善的Agent。

比方说有用户问，想要去某个图片里面的地方旅游，有什么方案？那么我们的Agent可以实现成，首先借助deepseek-r1的思考能力做意图识别，发现问题包含额外图片信息，之后就调用gemma3模型（或是封装的Agent）做图片识别，识别图片里的关键地标信息，再之后结合向量数据库跟我们通过bge-m3模型embed的大量文本，我们可以构建一套地理知识库，在这个知识库里检索到这个地标对应的城市，最后再借助qwen3以及外部高德地图等工具，规划出一套完整的旅行方案，回给主脑deepseek-r1吐出来。具体怎么管理Ollama的模型，可以参考[Ollama官方文档](https://docs.ollama.com/)。

为了实现这样的编排，我们需要有一套Agent开发框架，常见的就是基于Python的[LangChain](https://www.langchain.com/)以及基于Golang的[Eino](https://www.cloudwego.io/zh/docs/eino/)。本文以Eino为例子，Eino内部有封装对Ollama的调用，所以通过Eino连接Ollama模型也比较简单，示例代码：

```go
func (a *EinoOllamaAgent) Run(ctx context.Context) {
    // connect local ollama model
	model, err := ollama.NewChatModel(ctx, &ollama.ChatModelConfig{
		// 基础配置
		BaseURL: ollamaURL,        // Ollama 服务地址，通常为http://localhost:11434
		Timeout: 30 * time.Second, // 请求超时时间

		// 模型配置
		Model:  qwen3Model,                // 模型名称，比如qwen3:latest
		Format: json.RawMessage(`"json"`), // 输出格式（可选）

		// 模型参数
		Options: &api.Options{
			Temperature: 0.7,
			NumPredict:  8192,
		},

		// 推理配置
		Thinking: &api.ThinkValue{Value: false},
	})
	if err != nil {
		panic(errors.Errorf("create ollama chat model failed: %v", err))
	}

	messages := []*schema.Message{
		schema.SystemMessage("你是一个助手"),
		schema.UserMessage("请用一句话介绍Ollama"),
	}

	// 普通模式
	response, err := model.Generate(ctx, messages)
	if err != nil {
		panic(errors.Errorf("generate msg failed: %v", err))
	}
	fmt.Printf("resp: %s\n", response.Content)
}
```

如果是需要构建知识库的场景，那么我们需要做的一是把embedding模型当成通用文本向量化工具，不单独写一套代码，二是引入一个向量数据库，持久化文本向量，提供知识访问能力。如果用Eino实现的话，先给一个以内存作为向量数据库的最简单例子，当然Eino本身也有很多向量数据库Client的抽象，此处不赘述了。

```go
type Doc struct {
	ID        int
	Content   string
	Embedding []float64
}

type EinoOllamaKnowledge struct {
	docs     map[int]*Doc
	embedder *openai.Embedder
	idIncr   int
	idMtx    sync.Mutex
}

func NewEinoOllamaKnowledge(ctx context.Context) *EinoOllamaKnowledge {
	embedder, err := openai.NewEmbedder(ctx, &openai.EmbeddingConfig{
		BaseURL: ollamaV1URL, // Ollama服务v1地址，兼容OpenAI接口
		Model:   embedModel, // 模型名称，比如bge-m3:latest
		Timeout: 30 * time.Second,
	})
	if err != nil {
		panic(errors.Errorf("create ollama embed model failed: %v", err))
	}
	return &EinoOllamaKnowledge{
		docs:     make(map[int]*Doc),
		embedder: embedder,
	}
}

func (k *EinoOllamaKnowledge) Run(ctx context.Context) {
	texts := []string{
		"床前明月光，疑是地上霜。举头望明月，低头思故乡。",
		"离离原上草，一岁一枯荣。野火烧不尽，春风吹又生。",
		"白日依山尽，黄河入海流。欲穷千里目，更上一层楼。",
		"煮豆燃豆萁，豆在釜中泣。本是同根生，相煎何太急。",
		"鹅鹅鹅，曲项向天歌。白毛浮绿水，红掌拨清波。",
	}
	k.AddDocs(ctx, texts)

	queries := []string{
		"韧性",
		"登高",
		"夜晚",
		"动物",
		"兄弟",
	}
	for _, q := range queries {
		doc := k.FindMostSimilarDoc(ctx, q)
		if doc != nil {
			fmt.Printf("query: %s, most similar doc: %s\n", q, doc.Content)
		} else {
			fmt.Printf("query: %s, no similar doc found\n", q)
		}
	}
}

func (k *EinoOllamaKnowledge) genID() int {
	k.idMtx.Lock()
	defer k.idMtx.Unlock()
	k.idIncr++
	return k.idIncr
}

func (k *EinoOllamaKnowledge) AddDocs(ctx context.Context, texts []string) {
	embeddings, err := k.embedder.EmbedStrings(ctx, texts)
	if err != nil {
		panic(errors.Errorf("generate embedding failed: %v", err))
	}
	if len(embeddings) != len(texts) {
		panic(errors.Errorf("embedding count not equal to text count: %d != %d", len(embeddings), len(texts)))
	}

	for i := 0; i < len(texts); i++ {
		id := k.genID()
		doc := &Doc{
			ID:        id,
			Content:   texts[i],
			Embedding: embeddings[i],
		}
		k.docs[id] = doc
	}
}

func (k *EinoOllamaKnowledge) GetDoc(id int) *Doc {
	if doc, ok := k.docs[id]; ok {
		return doc
	}
	return nil
}

// FindMostSimilarDoc 最简单的查找最相似文档的实现
func (k *EinoOllamaKnowledge) FindMostSimilarDoc(ctx context.Context, text string) *Doc {
	if text == "" || len(k.docs) == 0 {
		return nil
	}

	embeddings, err := k.embedder.EmbedStrings(ctx, []string{text})
	if err != nil {
		panic(errors.Errorf("generate embedding failed: %v", err))
	}
	if len(embeddings) != 1 {
		panic(errors.Errorf("embedding count not equal to text count: %d != %d", len(embeddings), 1))
	}
	queryEmbedding := embeddings[0]

	cosineSimilarity := func(a, b []float64) float64 {
		if len(a) != len(b) {
			return 0
		}
		var dotProduct, normA, normB float64
		for i := range a {
			dotProduct += a[i] * b[i]
			normA += a[i] * a[i]
			normB += b[i] * b[i]
			if normA == 0 || normB == 0 {
				return 0
			}
		}
		return dotProduct / (math.Sqrt(normA) * math.Sqrt(normB))
	}

	var mostSimilar *Doc
	maxScore := -1.0
	for _, doc := range k.docs {
		score := cosineSimilarity(queryEmbedding, doc.Embedding)
		fmt.Printf("[FindMostSimilarDoc] query: %s, doc: %s, score: %v\n", text, doc.Content, score)
		if score > maxScore {
			maxScore = score
			mostSimilar = doc
		}
	}
	return mostSimilar
}
```

值得一提的是，如果这段代码转成Python也是比较容易的，比如Trae这种善于处理代码任务的Agent就可以做不同语言代码转换。假使用LangChain实现，外加ChromaDB本地持久化向量文本的话，可以这样写：

```python
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.schema import Document
import uuid
import os
import shutil


class OllamaKnowledge:
    def __init__(self, model="bge-m3:latest", ollama_base_url="http://localhost:11434",
                 persist_directory="./chroma_db"):
        # 初始化Ollama嵌入模型
        self.embeddings = OllamaEmbeddings(
            model=model,
            base_url=ollama_base_url
        )

        # 初始化Chroma向量存储
        self.vector_store = Chroma(
            embedding_function=self.embeddings,
            persist_directory=persist_directory
        )

    def add_docs(self, texts):
        """添加文档到向量数据库"""
        documents = []
        for text in texts:
            # 为每个文档生成唯一ID
            doc_id = str(uuid.uuid4())
            # 创建LangChain文档对象
            document = Document(
                page_content=text,
                metadata={"id": doc_id}
            )
            documents.append(document)

        # 将文档添加到向量存储
        self.vector_store.add_documents(documents)
        # 持久化存储
        self.vector_store.persist()

    def find_most_similar_doc(self, query, k=1):
        """查找与查询最相似的文档"""
        if not query:
            return None

        # 执行相似度搜索
        results = self.vector_store.similarity_search_with_score(query, k=k)

        if not results:
            return None

        # 返回最相似的文档
        most_similar_doc, score = results[0]
        return most_similar_doc, score

    def run_demo(self):
        """运行演示：添加文档并执行查询"""
        # 示例文档（唐诗）
        texts = [
            "床前明月光，疑是地上霜。举头望明月，低头思故乡。",
            "离离原上草，一岁一枯荣。野火烧不尽，春风吹又生。",
            "白日依山尽，黄河入海流。欲穷千里目，更上一层楼。",
            "煮豆燃豆萁，豆在釜中泣。本是同根生，相煎何太急。",
            "鹅鹅鹅，曲项向天歌。白毛浮绿水，红掌拨清波。",
        ]

        # 添加文档
        print("正在添加文档到向量数据库...")
        self.add_docs(texts)
        print(f"成功添加了 {len(texts)} 篇文档\n")

        # 查询示例
        queries = ["韧性", "登高", "夜晚", "动物", "兄弟"]

        for q in queries:
            result = self.find_most_similar_doc(q)
            if result:
                doc, score = result
                print(f"查询: {q}")
                print(f"最相似的文档: {doc.page_content}")
                print(f"相似度得分: {score:.4f}\n")
            else:
                print(f"查询: {q}, 未找到相似文档\n")


# 主函数
if __name__ == "__main__":
    # 创建OllamaKnowledge实例
    knowledge = OllamaKnowledge()
    # 运行演示
    knowledge.run_demo()
```

对于复杂编排，除了可以考虑用Dify之类的可视化工具做之外，纯程序的话，Eino也提供了一套[ADK](https://www.cloudwego.io/zh/docs/eino/core_modules/eino_adk/)框架封装了更复杂的Agent编排功能。除了最基础的ChatModelAgent之外，再往上实现的是WorkflowAgents，里面包括Sequential、Loop以及Parallel等编排，也就是行为树的翻版，然后再继续往上就实现了Supervisor以及Plan-Execute两类封装好的应用级编排。

对于调研类任务的话，有一个封装好的Plan-Execute编排，加上靠谱的数据处理模型，就可以实现一个简单的调研类Agent：

```go
type EinoAdkAgent struct {
	runner *adk.Runner
}

func NewEinoAdkAgent() *EinoAdkAgent {
	a := &EinoAdkAgent{}
	if err := a.init(context.Background()); err != nil {
		panic(errors.Errorf("initialize EinoAdkAgent failed: %v", err))
	}
	return a
}

func (a *EinoAdkAgent) Run(ctx context.Context) {
	userInput := []adk.Message{
		schema.UserMessage("请用中文回答如何写一篇100000字的科幻小说？"),
	}
	events := a.runner.Run(ctx, userInput)
	for {
		event, ok := events.Next()
		if !ok {
			break
		}
		if event.Err != nil {
			log.Printf("执行错误: %v", event.Err)
			break
		}
		// 打印智能体输出（计划、执行结果、最终响应等）
		if msg, err := event.Output.MessageOutput.GetMessage(); err == nil && msg.Content != "" {
			log.Printf("\n=== Agent [%s] Output ===\n%s\n", event.AgentName, msg.Content)
		}
	}
}

func (a *EinoAdkAgent) init(ctx context.Context) error {
	// init chat model
	chatModel, err := a.initChatModel(ctx)
	if err != nil {
		return errors.Errorf("create ollama chat model failed: %v", err)
	}
	var agent adk.Agent

	// init plan-executor
	planExecutor, err := a.initPlanExecutor(ctx, chatModel)
	if err != nil {
		return errors.Errorf("create plan-executor agent failed: %v", err)
	}
	agent = planExecutor

	// init runner
	a.runner = adk.NewRunner(ctx, adk.RunnerConfig{Agent: agent, EnableStreaming: true})
	return nil
}

func (a *EinoAdkAgent) initChatModel(ctx context.Context) (model.ToolCallingChatModel, error) {
	return ollama.NewChatModel(ctx, &ollama.ChatModelConfig{
		// 基础配置
		BaseURL: ollamaURL,         // Ollama 服务地址
		Timeout: 300 * time.Second, // 请求超时时间

		// 模型配置
		Model: qwen3Model, // 模型名称
		// Format: json.RawMessage(`"json"`), // 输出格式（可选）

		// 模型参数
		Options: &api.Options{
			NumPredict: 4096,
		},

		// 推理配置
		Thinking: &api.ThinkValue{Value: false},
	})
}

func (a *EinoAdkAgent) initPlanExecutor(ctx context.Context, chatModel model.ToolCallingChatModel) (adk.Agent, error) {
	// init planner
	planner, err := planexecute.NewPlanner(ctx, &planexecute.PlannerConfig{
		ToolCallingChatModel: chatModel,
		ToolInfo:             &planexecute.PlanToolInfo, // 默认 Plan 工具 schema
	})
	if err != nil {
		return nil, errors.Errorf("create planner agent failed: %v", err)
	}

	// init executor
	execAgent, err := adk.NewChatModelAgent(ctx, &adk.ChatModelAgentConfig{
		Name:          "AnySolver",
		Description:   "你是一个专业的解答者，能够为任意问题生成解答方案。",
		Instruction:   "你只能根据用户的问题，生成具体可执行的解答方案，不能生成任何与问题无关的内容。",
		Model:         chatModel,
		MaxIterations: 1,
	})
	if err != nil {
		return nil, errors.Errorf("create executor chat model agent failed: %v", err)
	}
	execTool := adk.NewAgentTool(ctx, execAgent) // 一个纯ChatModel占位，MCP基本收费，先不管
	executor, err := planexecute.NewExecutor(ctx, &planexecute.ExecutorConfig{
		Model:         chatModel,
		MaxIterations: 3,
		ToolsConfig: adk.ToolsConfig{
			ToolsNodeConfig: compose.ToolsNodeConfig{
				Tools: []tool.BaseTool{execTool},
			},
		},
	})
	if err != nil {
		return nil, errors.Errorf("create executor agent failed: %v", err)
	}

	// init replanner
	replanner, err := planexecute.NewReplanner(ctx, &planexecute.ReplannerConfig{
		ChatModel: chatModel,
	})
	if err != nil {
		return nil, errors.Errorf("create replanner agent failed: %v", err)
	}

	// init plan-executor agent
	planExecuteAgent, err := planexecute.New(ctx, &planexecute.Config{
		Planner:       planner,
		Executor:      executor,
		Replanner:     replanner,
		MaxIterations: 10,
	})
	if err != nil {
		return nil, errors.Errorf("create plan-execute agent failed: %v", err)
	}
	return planExecuteAgent, nil
}
```

最后，如果说要把Agent效果继续优化的话，先是要有一套完善的评测系统，然后也需要有一个Trace工具了解整个Agent链路上的弱点，最后可以从工具、Prompt、模型FineTune等很多角度去做优化，从而不断完善Agent的能力。要实现一个Demo很容易，但打磨产品的任务仍然任重道远。
