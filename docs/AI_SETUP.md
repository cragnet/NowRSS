# AI Provider Setup Guide

NowRSS supports multiple AI providers for article summarization and translation.

## Supported Providers

### Ollama Cloud

**Base URL:** `https://api.ollama.com/v1`

1. Sign up at [ollama.com](https://ollama.com)
2. Get your API key from your account settings
3. In NowRSS Settings → AI Providers, add:
   - Name: `Ollama Cloud`
   - Type: `ollama`
   - Base URL: `https://api.ollama.com/v1`
   - API Key: your key
   - Model: `llama3.2` (or your preferred model)

### Ollama Local

**Base URL:** `http://localhost:11434`

1. Install Ollama locally: [ollama.com/download](https://ollama.com/download)
2. Pull a model: `ollama pull llama3.2`
3. In NowRSS Settings → AI Providers, add:
   - Name: `Ollama Local`
   - Type: `ollama`
   - Base URL: `http://localhost:11434`
   - API Key: leave empty
   - Model: `llama3.2`

### OpenAI

**Base URL:** `https://api.openai.com/v1`

1. Get your API key from [platform.openai.com](https://platform.openai.com)
2. In NowRSS Settings → AI Providers, add:
   - Name: `OpenAI`
   - Type: `openai`
   - Base URL: `https://api.openai.com/v1`
   - API Key: your key
   - Model: `gpt-4o-mini`

### Custom Provider

Any OpenAI-compatible API works:

- **Groq:** `https://api.groq.com/openai/v1`
- **Together AI:** `https://api.together.xyz/v1`
- **Anyscale:** `https://api.endpoints.anyscale.com/v1`
- **Local endpoint:** Your own server

## Customizing Summarization Prompt

You can customize how articles are summarized in Settings:

```
You are a helpful assistant. Summarize the following article concisely.
Focus on the key points, main arguments, and any actionable takeaways.
Keep it under 150 words.

Title: {title}
Content: {content}

Summary:
```

Variables:
- `{title}` — Article title
- `{content}` — Article body text

## Security Notes

- API keys are stored locally in your settings file
- Keys are **not** included when exporting settings by default
- You can optionally include keys in exports (with warning)
- Never commit API keys to source control
