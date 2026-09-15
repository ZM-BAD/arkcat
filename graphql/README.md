# ArkTsGraphQL

A native GraphQL-over-HTTP client library for HarmonyOS NEXT (ArkTS/ArkUI), built on
`@kit.NetworkKit`. Zero third-party dependencies, UI-free and resource-free — usable from
any HarmonyOS Stage application as a local HAR dependency or a published ohpm package.

> Extracted from [ArkCat](https://github.com/ZM-BAD/arkcat) (a native GitHub client for
> HarmonyOS), where it powers all GitHub GraphQL v4 traffic. License: GPL-3.0-only
> (inherited from the host repository).

## Features

- **GraphQLClient** — POST endpoint and `data` extraction with **protocol-neutral** error
  handling. GraphQL errors always return HTTP 200; the host injects its error vocabulary via
  `errorTypeToCode` (consulted on `errors[].type`, then `extensions.code`) so callers can
  branch on `ApiError.code`. Without a mapper, errors surface with the original HTTP status
  and the original message.
- **HttpClient** — generic transport: timeouts, user agent, non-2xx → `ApiError` with the
  response `message` body, case-insensitive header lookup (`getHeader`), optional
  exponential-backoff retry for transient network failures (`retries`, idempotent calls
  only), and `Retry-After` surfaced on `ApiError.retryAfter`.
- **Pagination** — Relay cursor primitives: `Page<T>`, `readConnectionPage` (nodes/edges),
  `fetchAllPages` (hasNextPage-driven with a page cap and per-page graceful degradation).
- **AliasQuery** — single-request multi-alias document builders
  (`aliasField`/`aliasQueryDocument`) with mandatory string escaping
  (`escapeGraphQLString`).
- **RequestOps** — `RequestSequencer` (stale-response guard), `withFallback`
  (decorative-request soft failure), `runBounded` (bounded concurrency pool).
- **Json** — safe JSON access for ArkTS (no `any`): `Json.str/num/bool/obj/arr/parse`.
- **RateLimit** — `readRateLimit(headers)` parses `x-ratelimit-*` response headers.

## Install (local HAR)

```json5
// entry/oh-package.json5
{
  "dependencies": {
    "graphql": "file:../graphql"
  }
}
```

```ts
import { GraphQLClient, fetchAllPages, readConnectionPage } from 'graphql';

const client = new GraphQLClient('https://api.github.com/graphql', {
  userAgent: 'MyApp/1.0.0',
  // optional: map the backend's error vocabulary to semantic HTTP codes
  errorTypeToCode: (type: string): number => (type === 'NOT_FOUND' ? 404 : 200)
});

const data = await client.query('query { viewer { login } }', null, { token });
```

## Usage conventions

- Queries as static template constants; dynamic values always via `variables`.
- Alias-batch documents via `aliasField` — never interpolate raw strings.
- Cursor pagination via `fetchAllPages` (driven by `hasNextPage`; the final page may
  still carry a non-empty `endCursor`).
- Decorative data: wrap with `withFallback` so a failure never breaks the main flow.

## Test

Pure logic is host-testable with node:test + esbuild (see ArkCat's `scripts/ut/`,
which maps the bare specifier `graphql` straight to the library source).

## License

GPL-3.0-only. © 2026 周铭 (zm_bad).
