# site2llm Rails

A Rails 8 application that helps websites generate and publish `llms.txt` files - structured markdown files designed to help AI models understand and accurately read website content.

## Tech Stack

- **Rails 8.1** with Hotwire (Turbo + Stimulus)
- **PostgreSQL** database
- **Sidekiq** for background job processing
- **Redis** for Sidekiq queue
- **Tailwind CSS 4** for styling
- **esbuild** for JavaScript bundling
- **Stripe** for payment processing
- **Firecrawl API** for web crawling
- **OpenAI API** for AI enrichment (optional)

## Requirements

- Ruby 3.3+
- PostgreSQL 14+
- Redis 6+
- Node.js 18+
- Yarn

## Setup

1. **Install dependencies:**

   ```bash
   bundle install
   yarn install
   ```

2. **Configure environment variables:**

   Copy the example environment file and fill in your credentials:

   ```bash
   cp .env.example .env.local
   ```

   Required variables:
   - `DATABASE_URL` - PostgreSQL connection string
   - `REDIS_URL` - Redis connection string
   - `FIRECRAWL_API_KEY` - Firecrawl API key for web crawling
   - `STRIPE_SECRET_KEY` - Stripe secret key
   - `STRIPE_PRICE_ID` - Stripe price ID for the $8 payment
   - `STRIPE_WEBHOOK_SECRET` - Stripe webhook signing secret
   - `CLEANUP_TOKEN` - Token for cleanup endpoint authentication

   Optional variables:
   - `OPENAI_API_KEY` - OpenAI API key for AI enrichment
   - `OPENAI_BASE_URL` - Custom OpenAI endpoint (default: https://api.openai.com/v1)
   - `OPENAI_MODEL` - OpenAI model to use (default: gpt-4o-mini)

3. **Create and migrate the database:**

   ```bash
   bin/rails db:create
   bin/rails db:migrate
   ```

4. **Start the development server:**

   ```bash
   bin/dev
   ```

   This starts:
   - Rails server on http://localhost:3000
   - JavaScript build watcher
   - CSS build watcher
   - Sidekiq worker

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/generate` | POST | Generate llms.txt preview from survey data |
| `/api/checkout` | POST | Create Stripe Checkout session |
| `/api/download` | GET | Download paid llms.txt file |
| `/api/run` | GET | Check run status and payment status |
| `/api/stripe/webhook` | POST | Stripe payment webhooks |
| `/api/cleanup` | GET/POST | Delete expired runs (token-protected) |

## Stripe Webhook Setup

For local development, use the Stripe CLI:

```bash
stripe listen --forward-to localhost:3000/api/stripe/webhook
```

Copy the webhook signing secret to your `.env.local` as `STRIPE_WEBHOOK_SECRET`.

## Background Jobs

The app uses Sidekiq for background job processing. The `CleanupExpiredRunsJob` can be scheduled to run periodically to delete expired runs.

Access the Sidekiq dashboard at `/sidekiq` in development.

## Run Retention

- **Unpaid runs:** Expire after 24 hours
- **Paid runs:** Expire after 30 days

## License

Proprietary - All rights reserved.
