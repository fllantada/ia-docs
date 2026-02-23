# Billing Module - IA-docs
> Updated: 2025-01-15
> Stripe integration, subscription management, and invoice handling.

## Responsibility

Billing is responsible for managing Stripe subscriptions, processing payments, handling webhooks, and generating invoices. It owns the entire payment lifecycle from checkout to cancellation.

Billing is NOT responsible for deciding what features a plan grants (that's `entitlements/`), nor for user authentication (that's `auth/`). Although billing checks auth tokens on its routes, the auth logic lives in auth middleware.

## Domain Context

- **Business** = the paying entity (a company or individual). One business can have multiple users.
- **Plan** = Stripe Price object wrapped in our domain. We store plan metadata locally but Stripe is the source of truth for pricing.
- **Trial** = 14-day period where `subscription.status === 'trialing'`. Plan status is calculated at runtime in the mapper — never trust the stored `planStatus` field during trials.

## Gotchas

- **Webhook idempotency**: Stripe may send the same webhook multiple times. All webhook handlers MUST be idempotent. Check `event.id` against processed events before acting.
- **checkout.session.completed**: This is the ONLY webhook that creates a subscription locally. Do not create subscriptions from `customer.subscription.created` — timing issues.
- **Currency**: All amounts are in cents (integer). Display layer divides by 100.

## Legacy / Deprecated

- `BillingApi.createManualInvoice()` — deprecated since migration to Stripe Invoicing. It's a NO-OP that logs a warning. Use Stripe Dashboard for manual invoices.
