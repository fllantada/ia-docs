# src/ - IA-docs
> Updated: 2025-01-15
> Conventions and patterns for all code under src/.

## DDD Layers (mandatory for every module)

- **Domain** (`domain/`): Interfaces prefixed with `I`, factory functions, pure business logic. No framework imports.
- **Schemas** (`schemas/`): Zod schemas for input validation. Named `{entity}.schema.ts`.
- **Repository** (`repository.ts`): Single class per module. Only place that touches the database. Returns domain types, never raw DB documents.
- **Api** (`*Api.ts`): The module's public interface. Other modules import ONLY this. Orchestrates domain logic + repository calls.
- **Controller** (`*Controller.ts`): HTTP adapter. Validates input (via schemas), calls Api, formats response. No business logic here.
- **Routes** (`routes.ts`): Express route definitions. Middleware chain → Controller method.

## Anti-Patterns

- **NEVER** import from another module's `domain/`, `repository.ts`, or `schemas/`. Use its `*Api.ts`.
- **NEVER** put business logic in controllers. Controllers validate + delegate.
- **NEVER** return Mongoose documents from repositories. Always map to domain interfaces.

## Creating a New Module

1. Create folder structure: `domain/`, `schemas/`, `repository.ts`, `*Api.ts`, `*Controller.ts`, `routes.ts`
2. Define domain interfaces in `domain/` with `I` prefix
3. Create Zod schemas for all inputs
4. Register routes in the main router
5. Create an `IA-docs.md` for the module (use the `ia-docs-create` agent)
