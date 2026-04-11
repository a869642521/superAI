#!/bin/bash
# 一键启动 Starpath 后端服务
# 依赖：Node.js、Python3、PostgreSQL@16 (Homebrew)、Redis (Homebrew)

set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "▶ 检查 PostgreSQL & Redis..."
pg_isready -h localhost -p 5432 -q || { echo "❌ PostgreSQL 未运行，请先执行: brew services start postgresql@16"; exit 1; }
redis-cli -p 6379 ping -q > /dev/null 2>&1 || { echo "❌ Redis 未运行，请先执行: brew services start redis"; exit 1; }
echo "  ✅ PostgreSQL & Redis 已就绪"

# ── NestJS 后端 (port 3000) ───────────────────────────────────────────────────
echo "▶ 启动 NestJS 服务 (port 3000)..."
pkill -f "node dist/src/main" 2>/dev/null || true
cd "$ROOT/server"
node dist/src/main > /tmp/starpath-nestjs.log 2>&1 &
NEST_PID=$!
echo "  NestJS PID: $NEST_PID  →  日志: /tmp/starpath-nestjs.log"

# ── Python AI 服务 (port 8001) ────────────────────────────────────────────────
echo "▶ 启动 AI 服务 (port 8001)..."
pkill -f "uvicorn main:app" 2>/dev/null || true
cd "$ROOT/server/services/ai-service"

# 自动初始化虚拟环境
if [ ! -f "venv/bin/activate" ]; then
  echo "  正在初始化 Python 虚拟环境..."
  python3 -m venv venv
  ./venv/bin/pip install -r requirements.txt -q
fi

./venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001 > /tmp/starpath-aiservice.log 2>&1 &
AI_PID=$!
echo "  AI Service PID: $AI_PID  →  日志: /tmp/starpath-aiservice.log"

# ── 健康检查 ─────────────────────────────────────────────────────────────────
echo "▶ 等待服务就绪..."
sleep 4

if curl -sf http://localhost:3000/api/v1/users/quick-login -X POST \
  -H "Content-Type: application/json" -d '{"phone":"test"}' > /dev/null 2>&1; then
  echo "  ✅ NestJS 已就绪 → http://localhost:3000"
else
  echo "  ⚠️  NestJS 启动可能有问题，查看日志: cat /tmp/starpath-nestjs.log"
fi

if curl -sf http://localhost:8001/health > /dev/null 2>&1; then
  echo "  ✅ AI Service 已就绪 → http://localhost:8001"
else
  echo "  ⚠️  AI Service 启动可能有问题，查看日志: cat /tmp/starpath-aiservice.log"
fi

echo ""
echo "🚀 后端启动完成！"
echo "   ⚠️  对话功能需要在 server/services/ai-service/.env 中填写 MOONSHOT_API_KEY"
echo "   前往获取: https://platform.moonshot.cn/console/api-keys"
