# e2e (Playwright)

Runs against `vite preview` (see `playwright.config.ts`) with the backend mocked
via `page.route()` in `mocks.ts`.

**Known limitation**: real login goes through a Telegram-bot magic link
(`/getlink` → click a link with a token → `POST /api/auth/verify`). That
exchange isn't automatable headlessly, so these specs don't exercise it —
they start every protected-page test already "authenticated" via the mocked
`/api/auth/me`. The `AuthCallback`/`Login` pages themselves are still real
React code being rendered by a real browser; only the network responses are
faked.
