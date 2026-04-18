#!/bin/bash
# iOS 真机一键启动（带豆包语音 SDK）
# 用法：./ios-device.sh
# 真机需要在 Xcode 里先 Trust 开发者证书，然后连接 USB
set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

append_env_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    DART_DEFINES="$DART_DEFINES --dart-define=$key=$val"
  done < "$f"
}

# 真机构建：去掉 skip 标记（允许链接 SpeechEngineToB）
rm -f ios/.skip_volc_for_sim

# 读取豆包 SDK 凭证（从 .env.volc）
ENV_FILE=".env.volc"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 找不到 $ENV_FILE，请先创建（参考 .env.volc 示例）"
  exit 1
fi

# 解析 KEY=VALUE（忽略注释和空行）
source <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')

echo "→ pod install（含 SpeechEngineToB）..."
cd ios && pod install --silent && cd ..

# 列出可用真机
echo ""
echo "→ 可用设备："
flutter devices | grep "iOS"
echo ""

# 如果没有指定设备，让 flutter 自动选择真机
DEVICE_FLAG="${1:+-d $1}"

DART_DEFINES=""
append_env_file "$APP_DIR/.env.dev"
append_env_file "$APP_DIR/.env.tunnel"

echo "→ flutter run（豆包语音 SDK 已开启）..."
flutter run $DEVICE_FLAG $DART_DEFINES \
  --dart-define=VOLC_VOICE_SDK=${VOLC_VOICE_SDK:-true} \
  --dart-define=VOLC_E2E_VOICE=${VOLC_E2E_VOICE:-true} \
  --dart-define=VOLC_APP_ID=${VOLC_APP_ID} \
  --dart-define=VOLC_APP_TOKEN=${VOLC_APP_TOKEN} \
  --dart-define=VOLC_DIALOG_MODEL=${VOLC_DIALOG_MODEL:-1.2.1.1} \
  --dart-define=VOLC_TTS_SPEAKER=${VOLC_TTS_SPEAKER:-zh_female_vv_jupiter_bigtts} \
  --dart-define=VOLC_ENABLE_AEC=${VOLC_ENABLE_AEC:-true}
