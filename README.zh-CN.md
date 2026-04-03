# free-code

[English](README.md) | [简体中文](README.zh-CN.md)

**Claude Code 的自由构建版本。**

现已支持全端部署：为 Linux、macOS、Windows 提供预编译的一键安装器，并通过 GitHub Actions 自动完成跨平台构建与发布。

已移除全部遥测。已移除额外注入的安全提示词护栏。已解锁全部可编译的实验特性。一个二进制，无需回传。

> 当前仓库是在 [paoloanzn](https://github.com/paoloanzn) 最初重构的 free-code 工作基础上继续扩展而来，新增了全平台部署、一键安装器以及 GitHub Actions 自动发版能力。原始重构仓库的保留镜像见：https://gitlawb.com/node/repos/z6MkgKkb/paoloanzn-free-code

```bash
curl -fsSL https://raw.githubusercontent.com/Cross2pro/free-coder/main/install.sh | bash
```

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/Cross2pro/free-coder/main/install.ps1 | iex"
```

> 安装器会优先下载 Linux、macOS、Windows 对应的预编译发布包。如果没有匹配的发布资产，则会自动回退为源码构建。

<p align="center">
  <img src="assets/screenshot.png" alt="free-code 截图" width="800" />
</p>

---

## 这是什么

这是 Anthropic [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI 的一个干净、可构建的分支版本。Claude Code 是一个面向终端的 AI 编码代理。上游源码于 2026 年 3 月 31 日通过 npm 分发包中的 source map 暴露而公开可见。

这个分支在该源码快照基础上做了三类改动：

### 1. 移除遥测

上游二进制会通过 OpenTelemetry/gRPC、GrowthBook 分析、Sentry 错误上报以及自定义事件日志回传信息。在这个构建中：

- 所有外发遥测端点都已被死代码消除或替换为空实现
- GrowthBook 特性开关仍可在本地工作，以保证运行期 gating 正常，但不会向外回报
- 不会再上传崩溃报告、使用分析或会话指纹

### 2. 移除安全提示词护栏

Anthropic 会在每次会话中向模型注入系统级提示，用来额外限制 Claude 的行为，而不仅仅依赖模型自身的安全训练。这些内容包括：

- 针对特定类别请求的硬编码拒绝模式
- 注入的 “cyber risk” 指令块
- 来自 Anthropic 服务器下发的托管安全设置覆盖层

这个构建会移除这些注入层。模型自身的安全训练仍然生效；这里只是去掉 CLI 额外包裹的一层提示词级限制。

### 3. 解锁实验特性

Claude Code 内部包含大量由 `bun:bundle` 编译期开关控制的特性标志。公开 npm 版本中大多数都默认关闭。这个构建解锁了全部能够稳定编译的 45+ 个实验特性，包括：

| 特性 | 作用 |
|---|---|
| `ULTRAPLAN` | 在 Claude Code Web 上启用远程多代理规划（Opus 级） |
| `ULTRATHINK` | 深度思考模式，输入 `ultrathink` 可提升推理强度 |
| `VOICE_MODE` | 按键说话语音输入与听写 |
| `AGENT_TRIGGERS` | 本地定时/触发器后台自动化工具 |
| `BRIDGE_MODE` | IDE 远程控制桥接（VS Code、JetBrains） |
| `TOKEN_BUDGET` | Token 预算跟踪与使用告警 |
| `BUILTIN_EXPLORE_PLAN_AGENTS` | 内置 explore/plan 代理预设 |
| `VERIFICATION_AGENT` | 用于任务校验的验证代理 |
| `BASH_CLASSIFIER` | 带分类器辅助的 Bash 权限决策 |
| `EXTRACT_MEMORIES` | 查询结束后自动提取记忆 |
| `HISTORY_PICKER` | 交互式提示词历史选择器 |
| `MESSAGE_ACTIONS` | UI 中的消息动作入口 |
| `QUICK_SEARCH` | Prompt 快速搜索 |
| `SHOT_STATS` | shot 分布统计 |
| `COMPACTION_REMINDERS` | 上下文压缩提醒 |
| `CACHED_MICROCOMPACT` | 跨查询流缓存 microcompact 状态 |

完整的 88 个特性审计与状态见 [FEATURES.md](FEATURES.md)。

---

## 快速安装

```bash
curl -fsSL https://raw.githubusercontent.com/Cross2pro/free-coder/main/install.sh | bash
```

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/Cross2pro/free-coder/main/install.ps1 | iex"
```

在已发布对应资产的情况下，安装器会下载与你平台匹配的预编译二进制并安装 `free-code` 到 PATH 中。如果没有匹配的发布包，则会自动回退为源码构建。

安装完成后，直接运行：

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
free-code
```

---

## 依赖要求

- 使用预编译安装：不需要 Bun
- 使用源码构建：需要 [Bun](https://bun.sh) >= 1.3.11
- 需要一个 Anthropic API Key，并在环境变量中设置 `ANTHROPIC_API_KEY`

---

## 构建

```bash
# 克隆仓库
git clone https://github.com/Cross2pro/free-coder.git
cd free-coder

# 安装依赖
bun install

# 标准构建，产出 ./cli
bun run build

# 开发构建，带开发版版本号
bun run build:dev

# 开发构建并启用全部实验特性，产出 ./cli-dev
bun run build:dev:full

# 编译构建（输出到其他目录），产出 ./dist/cli
bun run compile
```

### 构建变体

| 命令 | 输出 | 特性 | 说明 |
|---|---|---|---|
| `bun run build` | `./cli` | 仅 `VOICE_MODE` | 接近生产的默认构建 |
| `bun run build:dev` | `./cli-dev` | 仅 `VOICE_MODE` | 带开发版本号 |
| `bun run build:dev:full` | `./cli-dev` | 全部 45+ 实验特性 | 完整解锁构建 |
| `bun run compile` | `./dist/cli` | 仅 `VOICE_MODE` | 输出到替代目录 |

### 发布打包

```bash
# 将全部发布归档构建到 ./dist/release
bun run release:build

# 本地调试时只打部分目标
bun run release:build --targets=windows-x64,linux-x64,macos-arm64
```

这会生成：

- 用于安装的版本无关资产，例如 `free-code-windows-x64.zip` 和 `free-code-linux-x64.tar.gz`
- 带目标元数据的 `manifest.json`
- 带 SHA-256 校验和的 `checksums.txt`

仓库中还包含 [release.yml](.github/workflows/release.yml)，当你推送 `v*` tag 时，它会自动构建并发布这些归档。

### 单独启用某些特性

你也可以不使用完整特性包，而只打开指定特性：

```bash
# 只启用 ultraplan 和 ultrathink
bun run ./scripts/build.ts --feature=ULTRAPLAN --feature=ULTRATHINK

# 在 dev 构建上额外启用某个特性
bun run ./scripts/build.ts --dev --feature=BRIDGE_MODE
```

---

## 运行

```bash
# 直接运行构建出的二进制
./cli

# 或运行开发版二进制
./cli-dev

# 或直接从源码运行（启动更慢）
bun run dev

# 设置 API Key
export ANTHROPIC_API_KEY="sk-ant-..."

# 或使用 Claude.ai OAuth 登录
./cli /login
```

### 快速测试

```bash
# 单次执行模式
./cli -p "what files are in this directory?"

# 默认交互 REPL
./cli

# 指定模型
./cli --model claude-sonnet-4-6-20250514
```

---

## 项目结构

```text
scripts/
  build.ts              # 带特性开关系统的构建脚本

src/
  entrypoints/cli.tsx   # CLI 入口
  commands.ts           # 命令注册表（slash commands）
  tools.ts              # 工具注册表（agent tools）
  QueryEngine.ts        # LLM 查询引擎
  screens/REPL.tsx      # 主交互界面

  commands/             # /slash 命令实现
  tools/                # Agent 工具实现（Bash、Read、Edit 等）
  components/           # Ink/React 终端 UI 组件
  hooks/                # React hooks
  services/             # API 客户端、MCP、OAuth、分析等
  state/                # 应用状态存储
  utils/                # 工具函数
  skills/               # Skill 系统
  plugins/              # 插件系统
  bridge/               # IDE 桥接
  voice/                # 语音输入
  tasks/                # 后台任务管理
```

---

## 技术栈

| | |
|---|---|
| 运行时 | [Bun](https://bun.sh) |
| 语言 | TypeScript |
| 终端 UI | React + [Ink](https://github.com/vadimdemedes/ink) |
| CLI 解析 | [Commander.js](https://github.com/tj/commander.js) |
| Schema 校验 | Zod v4 |
| 代码搜索 | ripgrep（打包内置） |
| 协议 | MCP、LSP |
| API | Anthropic Messages API |

---

## IPFS 镜像

这个仓库的完整副本已经通过 Filecoin 永久固定到 IPFS：

- **CID:** `bafybeiegvef3dt24n2znnnmzcud2vxat7y7rl5ikz7y7yoglxappim54bm`
- **Gateway:** https://w3s.link/ipfs/bafybeiegvef3dt24n2znnnmzcud2vxat7y7yoglxappim54bm

即使这个仓库被下线，代码仍然存在。

---

## 致谢

- 原始产品：[Anthropic Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- 最初的 free-code 重构仓库与研究打包工作：[paoloanzn](https://github.com/paoloanzn)
- 原始重构仓库镜像：https://gitlawb.com/node/repos/z6MkgKkb/paoloanzn-free-code

---

## 许可证

原始 Claude Code 源码版权归 Anthropic 所有。这个分支之所以存在，是因为源码曾通过他们的 npm 分发包被公开暴露。请自行判断使用风险。
