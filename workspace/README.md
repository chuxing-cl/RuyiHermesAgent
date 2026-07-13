# workspace/ — Hermes 便携运行时目录（HERMES_HOME）

这个目录是 Hermes Agent 的 **HERMES_HOME**：运行时的全部数据都落在这里，
和源码放在同一棵树里。配合根目录的 `run.ps1` / `run.sh` 启动器，做到
**「把源码整个复制/打包过去 = 在新机器上复现环境」**。

## 这里装什么

| 内容 | 是否随源码走（进 git / 打包） | 说明 |
|------|:--:|------|
| `config.yaml` | ✅ 是 | 运行配置（不含密钥） |
| `SOUL.md` | ✅ 是 | Agent 人设 |
| `.env.example` | ✅ 是 | 环境变量模板（仅键名，无真实值） |
| `memories/` | ✅ 是 | 长期记忆 / 用户画像（随源码走） |
| `skills/`（用户自建） | ✅ 是 | 你自己创建的技能 |
| `.env` | ⛔ 否 | **真实密钥**，已被 .gitignore 排除 |
| `auth.json` | ⛔ 否 | 模型登录凭据（机器/账号特定） |
| `state.db` / `*.db-wal` / `*.db-shm` | ⛔ 否 | 会话数据库（逐条历史，可重建） |
| `sessions/` | ⛔ 否 | 会话明细（可重建） |
| `cache/` `image_cache/` `audio_cache/` `sandboxes/` `logs/` `bin/` | ⛔ 否 | 缓存/沙箱/日志（可重建，体积大） |

> **设计原则**：随源码走的是「能重建的核心结构 + 技能 + 长期记忆」；
> 密钥与隐私（.env / auth.json / 会话历史）**绝不进包**，由部署方在新机器落地时注入。

## bundled 技能在哪？

不在这里。Hermes 自带的几十个技能在**源码根的 `skills/` 目录**，运行时由
`get_bundled_skills_dir()` 直接从源码读取——它们本来就随源码走，无需复制到这里。
`workspace/skills/` 只放你自己新建的技能和运行时状态。

## 部署到新机器（3 步）

1. 复制 / 解压整个源码目录到任意路径（盘符随意，`run.ps1` 会自动适配）。
2. 安装依赖（首次）：`uv pip install -e ".[all]"`，或按 README 的 Windows 安装方式。
3. 运行 `..\run.ps1`（Windows）或 `../run.sh`（Linux/macOS）：
   - 首次会自动从 `.env.example` 生成 `.env` 并提示你填密钥；
   - 填好密钥后再次运行即进入；
   - 跑 `.\smoke-test.ps1` 做落地自检。
