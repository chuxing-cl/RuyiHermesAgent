#!/usr/bin/env bash
# Hermes Agent 便携启动器（Linux / macOS / WSL）
#
# 把 HERMES_HOME 指向「本脚本所在目录/workspace」，使运行时全部数据
# （配置、技能、记忆、会话等）都落在源码树内部。无论源码被复制到哪个路径，
# HERMES_HOME 都自动跟随——「复制源码即复现环境」。
# 不依赖全局环境变量；每次启动在进程内注入，杜绝静默回退到 ~/.hermes。
#
# 用法:
#   ./run.sh                 # 交互式终端
#   ./run.sh gateway start   # 消息网关
#   ./run.sh doctor          # 自检
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 注入 HERMES_HOME（相对脚本自身，绝对路径随源码位置自动正确）
export HERMES_HOME="$DIR/workspace"
mkdir -p "$HERMES_HOME"

# 2. 首次运行引导：无 .env 则从模板生成并提示（fail-loud）
if [ ! -f "$HERMES_HOME/.env" ]; then
    if [ -f "$HERMES_HOME/.env.example" ]; then
        cp "$HERMES_HOME/.env.example" "$HERMES_HOME/.env"
        echo ""
        echo "[hermes] 首次运行：已从 .env.example 生成 workspace/.env"
        echo "[hermes] 请填入你的 API 密钥后重新运行：$HERMES_HOME/.env"
        echo ""
        exit 1
    else
        echo "[hermes] 警告：缺少 workspace/.env.example，无法生成 .env"
    fi
fi

# 3. 解析 Python：优先本地 venv
PY="python3"
if [ -x "$DIR/.venv/bin/python" ]; then
    PY="$DIR/.venv/bin/python"
elif [ -x "$DIR/venv/bin/python" ]; then
    PY="$DIR/venv/bin/python"
fi

# 4. 启动 Hermes
echo "[hermes] HERMES_HOME = $HERMES_HOME"
exec "$PY" "$DIR/hermes" "$@"
