import os
import json
import httpx
from typing import AsyncGenerator
from openai import AsyncOpenAI, AuthenticationError as OpenAIAuthError

_client: AsyncOpenAI | None = None


def get_client() -> AsyncOpenAI:
    global _client
    if _client is None:
        api_key = os.getenv("MOONSHOT_API_KEY", "")
        base_url = os.getenv("MOONSHOT_BASE_URL", "https://api.kimi.com/coding/v1")
        if not api_key:
            raise RuntimeError("MOONSHOT_API_KEY 未配置，请检查 ai-service/.env 文件")
        # Kimi Code requires User-Agent to identify as a recognized coding agent
        _client = AsyncOpenAI(
            api_key=api_key,
            base_url=base_url,
            default_headers={"User-Agent": "claude-code/1.0.0"},
        )
    return _client


def reset_client() -> None:
    """Force re-read env vars and recreate the client (useful after .env changes)."""
    global _client
    _client = None


def _get_model() -> str:
    return os.getenv("LLM_MODEL", "kimi-for-coding")


def _clamp_temperature(t: float) -> float:
    """Kimi supports temperature in [0, 1]."""
    return max(0.0, min(1.0, t))


async def stream_chat_completion(
    system_prompt: str,
    messages: list[dict],
    temperature: float = 0.8,
    max_tokens: int = 2048,
) -> AsyncGenerator[str, None]:
    """
    Stream chat completion tokens from Kimi Code.

    Yields (token_type, content) pairs:
      - ("thinking", text)  — reasoning / thinking phase
      - ("content", text)   — final response text
    but here we yield plain strings; callers receive only content tokens by default.
    """
    api_key = os.getenv("MOONSHOT_API_KEY", "")
    base_url = os.getenv("MOONSHOT_BASE_URL", "https://api.kimi.com/coding/v1")
    model = _get_model()
    temperature = _clamp_temperature(temperature)

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
        "User-Agent": "claude-code/1.0.0",
    }

    # Use httpx directly to handle the non-standard reasoning_content field
    async with httpx.AsyncClient(timeout=60.0) as http:
        try:
            async with http.stream(
                "POST",
                f"{base_url}/chat/completions",
                json=payload,
                headers=headers,
            ) as response:
                if response.status_code == 401:
                    raise RuntimeError(
                        "Kimi API 认证失败（401）：请检查 MOONSHOT_API_KEY 是否正确，"
                        "或前往 https://www.kimi.com/code/console 重新获取 API Key"
                    )
                if response.status_code == 403:
                    raise RuntimeError(
                        "Kimi Code 访问被拒绝（403）：此 API Key 不允许直接调用，"
                        "请确认已订阅 Kimi Code 会员"
                    )
                if response.status_code != 200:
                    body = await response.aread()
                    raise RuntimeError(f"Kimi API 错误 {response.status_code}: {body.decode()}")

                async for line in response.aiter_lines():
                    # Kimi Code uses "data:{json}" (no space), standard SSE uses "data: {json}"
                    if line.startswith("data:"):
                        data_str = line[5:].strip()
                    else:
                        continue
                    if data_str == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue

                    if chunk.get("error"):
                        raise RuntimeError(chunk["error"].get("message", "Kimi API 错误"))

                    choices = chunk.get("choices", [])
                    if not choices:
                        continue
                    delta = choices[0].get("delta", {})

                    # reasoning_content = thinking phase (we yield it prefixed so UI can distinguish)
                    reasoning = delta.get("reasoning_content")
                    if reasoning:
                        yield f"\x00think\x00{reasoning}"

                    # content = actual reply
                    content = delta.get("content")
                    if content:
                        yield content

        except httpx.RequestError as e:
            raise RuntimeError(f"无法连接到 Kimi API: {e}") from e


async def get_chat_completion(
    system_prompt: str,
    messages: list[dict],
    temperature: float = 0.3,
    max_tokens: int = 512,
) -> str:
    """Non-streaming chat completion (for internal tasks like memory extraction)."""
    result = ""
    async for token in stream_chat_completion(
        system_prompt, messages, temperature, max_tokens
    ):
        # Skip thinking tokens for internal tasks
        if not token.startswith("\x00think\x00"):
            result += token
    return result
