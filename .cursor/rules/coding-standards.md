---
description: Coding standards and architecture rules for the Starpath project
globs: ["**/*.dart", "**/*.ts", "**/*.py"]
---

# Starpath Coding Standards

## Tech Stack
- Client: Flutter 3.x + Dart + Riverpod
- Business Backend: NestJS + TypeScript + Prisma
- AI Backend: FastAPI + Python
- Database: PostgreSQL + pgvector + Redis

## Flutter / Dart

### Architecture: Feature-First Modular
```
feature_name/
├── data/         # Data sources, repository implementations, DTOs
├── domain/       # Entities, repository interfaces, use cases
├── presentation/ # Pages, widgets, controllers
└── providers.dart  # Riverpod providers summary
```

### Naming
- Files: `snake_case` (e.g. `agent_studio_page.dart`)
- Classes: `PascalCase` (e.g. `AgentStudioPage`)
- Variables/functions: `camelCase` (e.g. `loadAgentProfile`)
- Constants: `lowerCamelCase` (e.g. `defaultBorderRadius`)
- Private: prefix underscore (e.g. `_internalState`)

### Widget Rules
- Single widget build method must not exceed 80 lines
- Prefer composition over inheritance
- All stateless widgets use `const` constructors
- List items must provide unique `key`

### State Management
- Global state: Riverpod Provider (user/auth/theme)
- Feature state: Riverpod Notifier (chat/content/agent)
- UI state: local State / ValueNotifier
- Never cross-feature import internal state directly

### AI Companion Rendering
- Animation: prefer Rive (interactive), Lottie as supplement
- Gradients: use custom `GradientPainter`, avoid nested `DecoratedBox`
- Performance: wrap companion renders in `RepaintBoundary`
- Frame rate: aura animations at 60fps, use `Ticker` not `Timer`

## NestJS / TypeScript

### Module Boundaries
- Services communicate via event bus, never direct cross-module imports
- All DTOs validated with `class-validator`
- Unified exception filter + standard error format
- API versioning: URL prefix `/api/v1/`

### Code Style
- Strict TypeScript mode enabled
- Prefer `readonly` for immutable properties
- Use `enum` for fixed sets of values
- All async operations must have proper error handling

### Database
- All queries go through Prisma
- Use transactions for multi-table operations
- Soft delete by default (`deletedAt` timestamp)
- Pagination uses cursor-based approach for feeds

## FastAPI / Python

### Code Style
- All function parameters and return types must have type annotations
- All request/response models use Pydantic
- All IO operations use `async/await`
- AI calls go through unified LLM Gateway (supports model switching and fallback)

### AI Service Patterns
- System prompts assembled dynamically: base persona + personality tags + memory context
- Streaming responses via SSE (Server-Sent Events)
- Memory extraction runs asynchronously after conversation ends
- Vector similarity search via pgvector for long-term memory retrieval

## API Conventions
- REST endpoints follow: `GET /resource`, `POST /resource`, `GET /resource/:id`, `PATCH /resource/:id`, `DELETE /resource/:id`
- All responses wrapped in `{ code, message, data }` envelope
- Error codes: 4xx for client errors, 5xx for server errors
- Timestamps in ISO 8601 format, UTC timezone
- IDs use UUID v4
