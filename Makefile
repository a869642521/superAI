##
## Starpath 开发快捷命令
## 用法：make <目标>   (需要 make 已安装；macOS 自带)
##

ROOT := $(shell pwd)
APP  := $(ROOT)/app

# ── 彩色输出 ────────────────────────────────────────────────────
BOLD  := \033[1m
GREEN := \033[0;32m
CYAN  := \033[0;36m
RESET := \033[0m

.PHONY: help dev dev-macos backend \
        android android-emu android-phone \
        ios ios-device simulator \
        macos phone-setup stop logs logs-nest logs-ai \
        db-reset db-seed clean flutter-get check

help: ## 显示此帮助
	@echo ""
	@echo "$(BOLD)Starpath 开发命令$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ════════════════════════════════════════════════════════════════
#  一键启动
# ════════════════════════════════════════════════════════════════

dev: backend android ## 后端 + Flutter Android（真机优先）

dev-emu: backend android-emu ## 后端 + Flutter Android 模拟器

dev-macos: backend macos ## 后端 + Flutter macOS 桌面版

# ════════════════════════════════════════════════════════════════
#  后端
# ════════════════════════════════════════════════════════════════

backend: ## 启动 Docker + NestJS + AI 服务（后台运行）
	@echo "$(GREEN)▶ 启动后端服务...$(RESET)"
	@bash $(ROOT)/start-backend.sh

# ════════════════════════════════════════════════════════════════
#  Android
# ════════════════════════════════════════════════════════════════

android: ## Flutter Android — 自动检测（真机优先，否则模拟器）
	@echo "$(GREEN)▶ Flutter Android（自动）...$(RESET)"
	@bash $(APP)/android.sh

android-emu: ## Flutter Android — 模拟器（已有则直接用，否则自动启动）
	@echo "$(GREEN)▶ Flutter Android 模拟器...$(RESET)"
	@bash $(APP)/android.sh --emu

android-phone: ## Flutter Android — 只连真机（跳过模拟器）
	@echo "$(GREEN)▶ Flutter Android 真机...$(RESET)"
	@bash $(APP)/android.sh --phone

# ════════════════════════════════════════════════════════════════
#  iOS / macOS
# ════════════════════════════════════════════════════════════════

ios: ## Flutter iOS 模拟器（需先 make simulator 打开）
	@cd $(APP) && flutter pub get && bash ios-sim.sh

ios-device: ## Flutter iOS 真机（含豆包语音 SDK）
	@echo "$(GREEN)▶ Flutter iOS 真机...$(RESET)"
	@cd $(APP) && bash ios-device.sh

simulator: ## 打开 iOS Simulator
	@open -a Simulator

macos: ## Flutter macOS 桌面版
	@echo "$(GREEN)▶ Flutter macOS...$(RESET)"
	@cd $(APP) && flutter pub get && flutter run -d macos

phone-setup: ## 提示：真机体验前的配置步骤
	@echo "$(CYAN)真机连本机后端：$(RESET)"
	@echo "  1. cp app/.env.dev.example app/.env.dev"
	@echo "  2. 把 STARPATH_API_HOST 改成你电脑局域网 IP（Mac: ipconfig getifaddr en0）"
	@echo "  3. 手机与电脑同一 Wi‑Fi，USB 调试连接后：make backend + make android-phone"
	@echo "  4. 若连不上：关闭 Mac 防火墙对 3000/8000 的拦截，或放行 node/python"

# ════════════════════════════════════════════════════════════════
#  日志查看（Cursor 终端里用）
# ════════════════════════════════════════════════════════════════

logs: ## 同时 tail NestJS + AI 服务日志
	@echo "$(CYAN)NestJS 日志 → /tmp/starpath-nestjs.log$(RESET)"
	@echo "$(CYAN)AI 服务日志 → /tmp/starpath-aiservice.log$(RESET)"
	@echo "按 Ctrl+C 退出"
	@tail -f /tmp/starpath-nestjs.log /tmp/starpath-aiservice.log

logs-nest: ## 只看 NestJS 日志
	@tail -f /tmp/starpath-nestjs.log

logs-ai: ## 只看 AI 服务日志
	@tail -f /tmp/starpath-aiservice.log

check: ## 快速健康检查（看端口是否通）
	@echo "── Docker ──────────────────────────"
	@docker ps --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  Docker 未运行"
	@echo "── NestJS (3000) ───────────────────"
	@curl -sS -o /dev/null --connect-timeout 2 http://localhost:3000/ 2>/dev/null && echo "  ✅ NestJS 在线（端口可连）" || echo "  ❌ NestJS 不可达"
	@echo "── AI Service (8000) ───────────────"
	@curl -sf http://localhost:8000/health && echo "  ✅ AI 服务在线" || echo "  ❌ AI 服务不可达"
	@echo "── Flutter 设备 ────────────────────"
	@cd $(APP) && flutter devices

# ════════════════════════════════════════════════════════════════
#  停止 / 重置
# ════════════════════════════════════════════════════════════════

stop: ## 停止所有服务（保留 Docker 数据）
	@echo "$(GREEN)▶ 停止服务...$(RESET)"
	@pkill -f "nest start" 2>/dev/null && echo "  NestJS 已停止" || true
	@pkill -f "ts-node" 2>/dev/null || true
	@pkill -f "uvicorn main:app" 2>/dev/null && echo "  AI 服务已停止" || true
	@echo "  Docker 容器保留（如需停止：docker compose stop）"

db-reset: ## 重置数据库（删数据！）
	@echo "⚠️  即将重置数据库，5 秒后执行（Ctrl+C 取消）..."
	@sleep 5
	@cd $(ROOT)/server && npx prisma migrate reset --force

db-seed: ## 填充种子数据
	@cd $(ROOT)/server && npm run prisma:seed

flutter-get: ## flutter pub get
	@cd $(APP) && flutter pub get

clean: ## 清理缓存
	@cd $(APP) && flutter clean && flutter pub get
	@echo "  ✅ Flutter 缓存已清理"
