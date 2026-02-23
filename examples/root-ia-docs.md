# Project Name - IA-docs
> Updated: 2025-01-15
> Root-level context for the entire project.

## Tech Stack

- **Runtime**: Node.js 20 + TypeScript 5.4
- **Framework**: Express with custom middleware chain
- **Database**: MongoDB with Mongoose ODM
- **Queue**: BullMQ + Redis for async jobs
- **Auth**: JWT + refresh tokens, passwordless login via email

## Architecture

DDD + Hexagonal. Each module in `src/app/` is a self-contained bounded context:

```
src/app/{module}/
  domain/       → Interfaces (I*), factories, business logic
  schemas/      → Zod validation schemas
  repository.ts → Database access (only place that uses Mongoose)
  *Api.ts       → Public API for other modules to consume
  *Controller.ts → HTTP layer (receives requests, delegates to Api)
  routes.ts     → Express routes
```

**Cross-module communication**: Modules call each other ONLY through `*Api.ts` classes. Never import from another module's domain, repository, or controller.

## Modules

| Module | Responsibility |
|--------|---------------|
| `auth` | Authentication, JWT tokens, session management |
| `billing` | Stripe integration, subscriptions, invoices |
| `crm` | Customer lifecycle, onboarding, email campaigns |
| `analytics` | Event tracking, usage metrics, reporting |

## Conventions

- **IDs**: `string` in domain layer, `ObjectId` only in repository layer
- **Logging**: Always use `formatLog(businessName, 'MODULE', 'action')`
- **Error handling**: Domain errors extend `AppError`, never throw raw Error
