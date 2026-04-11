"""
Kimi Code LLM Gateway
官方文档: https://www.kimi.com/code/docs/en/more/third-party-agents.html

端点:    https://api.kimi.com/coding/v1
模型:    kimi-for-coding
API Key: sk-kimi-... （从 Kimi Code 会员页面获取）
"""

import os
import json
import httpx
from typing import AsyncGenerator

_DEFAULT_BASE_URL = "https://api.kimi.com/coding/v1"
_DEFAULT_MODEL = "kimi-for-coding"

# Kimi Code 需要此 User-Agent 才能被识别
_USER_AGENT = "claude-code/1.0.0"


def reset_client() -> None:
    """占位方法，保持接口兼容。"""
    pass


def _get_model() -> str:
    return os.getenv("LLM_MODEL", _DEFAULT_MODEL)


def _clamp_temperature(t: float) -> float:
    return max(0.0, min(1.0, t))


async def stream_chat_completion(
    system_prompt: str,
    messages: list[dict],
    temperature: float = 0.7,
    max_tokens: int = 32768,
) -> AsyncGenerator[str, None]:
    """
    流式调用 Kimi Code API。

    Yields:
        普通 token:   直接 yield 文本字符串
        思考 token:   yield "\x00think\x00{text}"（前端可据此展示推理过程）
    """
    api_key = os.getenv("KIMI_CODE_API_KEY", "")
    base_url = os.getenv("KIMI_CODE_BASE_URL", _DEFAULT_BASE_URL)
    model = _get_model()
    temperature = _clamp_temperature(temperature)

    if not api_key:
        raise RuntimeError(
            "KIMI_CODE_API_KEY 未配置，请在 ai-service/.env 中填写。\n"
            "前往获取: https://www.kimi.com/code → 会员页面 → API Keys"
        )

    full_messages = [{"role": "system", "content": system_prompt}]
    full_messages.extend(messages)

    payload = {
        "model": model,
        "messages": full_messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": True,
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "User-Agent": _USER_AGENT,
    }

    async with httpx.AsyncClient(timeout=120.0) as http:
        try:
            async with http.stream(
                "POST",
                f"{base_url}/chat/completions",
                json=payload,
                headers=headers,
            ) as response:
                if response.status_code == 401:
                    raise RuntimeError(
                        "Kimi Code API 认证失败（401）：\n"
                        "请检查 KIMI_CODE_API_KEY 是否正确（格式应为 sk-kimi-...）\n"
                        "前往获取: https://www.kimi.com/code → 会员页面 → API Keys"
                    )
                if response.status_code == 403:
                    raise RuntimeError(
                        "Kimi Code API 访问被拒绝（403）：\n"
                        "请确认已订阅 Kimi Code 会员，且 API Key 有效"
                    )
                if response.status_code == 429:
                    raise RuntimeError("Kimi Code API 请求频率超限（429），请稍后再试")
                if response.status_code != 200:
                    body = await response.aread()
                    raise RuntimeError(
                        f"Kimi Code API 错误 {response.status_code}: {body.decode()}"
                    )

                async for line in response.aiter_lines():
                    # 标准 SSE 格式 "data: {json}" 或 "data:{json}"
                    if not line.startswith("data:"):
                        continue
                    data_str = line[5:].strip()
                    if data_str == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue

                    if chunk.get("error"):
                        raise RuntimeError(
                            chunk["error"].get("message", "Kimi Code API 错误")
                        )

                    choices = chunk.get("choices", [])
                    if not choices:
                        continue
                    delta = choices[0].get("delta", {})

                    # reasoning_content = 推理/思考过程（Kimi Code 独有字段）
                    reasoning = delta.get("reasoning_content")
                    if reasoning:
                        yield f"\x00think\x00{reasoning}"

                    # content = 正式回复
                    content = delta.get("content")
                    if content:
                        yield content

        except httpx.RequestError as e:
            raise RuntimeError(f"无法连接到 Kimi Code API: {e}") from e


async def get_chat_completion(
    system_prompt: str,
    messages: list[dict],
    temperature: float = 0.3,
    max_tokens: int = 4096,
) -> str:
    """非流式调用（用于内部任务，如记忆提取）。"""
    result = ""
    async for token in stream_chat_completion(
        system_prompt, messages, temperature, max_tokens
    ):
        if not token.startswith("\x00think\x00"):
            result += token
    return result
