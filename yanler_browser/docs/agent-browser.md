# Yanler Agent 浏览器 — 手机内置 Agent 引擎架构

## 定位
手机内置 Agent：App 内 Dart 实现的工具循环，直调大模型 API（OpenAI 兼容 function calling），
不依赖电脑。能力面 = 浏览器内部操作，工具面收敛实现「职能锁死在浏览器内 + 权限给满 + 安全」。

## 为什么不用 OpenClaw 源码直接嵌入
OpenClaw 是 Node.js（>=22）独立 agent 框架，跑在电脑/服务器，无法嵌入 Flutter/Android App。
其继任者是 Hermes Agent（本机已装）。因此采用：**架构对齐开源 agent 设计，Dart 实现工具循环**。

## 组件
- `lib/features/agent_bridge/browser_tools.dart`
  浏览器工具集（23 个工具），也是 MCP 工具定义：
  - 标签：list_tabs / open_tab / close_tab / switch_tab / navigate / back / forward / reload / get_active_tab
  - 搜索：search（当前默认引擎）
  - 页面：get_page_text / click(selector) / type(selector,text) / scroll(direction) / get_page_screenshot
  - 书签：list / add / remove
  - 历史：list / clear
  - 设置：get / set（searchEngine/theme/adblock/wallpaper/homepage）
  - 广告：adblock.status / toggle
  页面级操作通过 NavBus.active（当前活动标签的 WebView 控制器）执行，不持有过期引用。
- `lib/features/agent_bridge/agent_engine.dart`
  工具循环：模型选工具 → 授权 → 执行 → 结果回传 → 直到完成（最多 8 轮）。
  - OpenAI 兼容 tools schema（自动从 MCPTool 转换）
  - 授权模式：strict（全部确认）/ smart（仅破坏性操作确认，默认）/ auto（全自动）
  - cancel() 随时中止，优先级最高
  - onStep 回调向 UI 推送 thinking / tool 状态
- `lib/providers/ai_provider.dart`
  - `browserTools` / `authorizeRequest` 由聊天页注入
  - agentMode 开启且工具注入 → sendMessage 走工具循环；否则普通对话
  - `authMode` 持久化（prefs: ai_auth_mode）
  - stopGenerating() 同时中止 AgentEngine
- `lib/features/ai/ai_chat_screen.dart`
  - initState 注入 BrowserTools + 授权确认弹窗
  - Agent 状态条：思考中 / 正在执行工具
  - 旧文本命令面板在工具循环模式下自动跳过

## 安全模型（用户控制权）
1. 工具面收敛：Agent 只能拿到浏览器工具，无 shell/文件/系统网络工具
2. smart 模式破坏性操作（删书签/清历史/改设置/关标签/广告开关）弹确认框
3. 停止按钮 + 新消息自动中止旧任务，终止指令优先
4. 授权模式可在设置中调整（严格/智能/全自动）

## 使用
1. 设置 → AI → 配置 API（推荐支持 function calling 的模型，如 deepseek-chat、glm-4）
2. 设置 → AI → 开启「代理模式 Agent」
3. 底部栏 AI 按钮 → 聊天 → 直接说任务：
   「搜索 华为mate70 评测」「打开 bilibili 并搜索 xxx」「把当前页面存到书签」
   「删除我刚才添加的书签」「清空历史记录」

## 后续可选增强
- MCP server 模式：把 BrowserTools 暴露为局域网 MCP 端点，电脑上 Hermes/OpenClaw 可接入（工具定义已就绪，需加 JSON-RPC 传输层）
- 截图给多模态模型（gpt-4o / gemini）看图操作页面
