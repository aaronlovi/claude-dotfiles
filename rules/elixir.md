---
paths:
  - "**/*.ex"
  - "**/*.exs"
  - "**/mix.lock"
---

# Elixir Projects

- Add `{:excoveralls, "~> 0.18", only: :test}` for coverage reporting. Configure with `test_coverage: [tool: ExCoveralls]` in `project/0` and coveralls tasks in `preferred_envs` in `cli/0`.
- Add a `precommit` alias in `mix.exs` that runs in this order: `deps.unlock --unused`, `format`, `compile --warning-as-errors`, `credo`, `sobelow --config`, `test`. Run `mix precommit` before every commit. Always commit `mix.lock` alongside dependency changes.
- Add `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` and `{:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}`.
- At the end of development, verify the Docker build passes with `docker build -t <name> .` before considering the project done.
- **When a GenServer does database writes inside `handle_call/3` or `handle_info/2`, use `Ecto.Adapters.SQL.Sandbox.allow/3` in tests to grant the GenServer process access to the test's sandbox connection.** DB writes inside GenServer callbacks are normal and common — the GenServer serialises state and DB writes together atomically. The sandbox issue is that the GenServer process doesn't share the test's connection by default; `allow/3` fixes this. Pattern: after obtaining the GenServer's PID (e.g. via `find_or_create`), call `Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)` before exercising the GenServer in the test. Alternatively, DB writes can be done in the caller's process (before sending the message or after receiving the reply) — this avoids the `allow` setup but adds complexity to production code and creates a brief window where in-memory state and DB are out of sync.
- **Add database comments to all Ecto migrations.** Every `create table` call must include a `comment` option on the table itself and on each column. Use concise, human-readable descriptions. For `alter table` calls that add new columns, add `comment` to each new column. Example: `add :email, :string, null: false, comment: "Primary email address for login and notifications"`.
- **Use structured (JSON) logging in all environments.** Add `{:logger_json, "~> 7.0"}` (no `only:` restriction) and configure it in `config/config.exs` as the default handler: `config :logger, :default_handler, formatter: {LoggerJSON.Formatters.Basic, metadata: :all}`. Do not add a plain-text formatter override in `dev.exs`. Configure the credo check `{Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, [metadata_keys: :all]}` in `.credo.exs` to silence false positives. The field is named `severity` (not `level`) — this is intentional and follows Google Cloud Logging convention.
- **Log every API request and response.** For Phoenix apps, add a `Plugs.RequestLogger` plug to all API pipelines. On ingress it logs method, path, query string, and merged params; on egress (via `register_before_send/2`) it logs status and JSON-decoded response body. **WARNING: sensitive values (client secrets, tokens) appear in plaintext — do NOT use in production. Dev/test only.**
- **Add CORS support with Corsica.** Add `{:corsica, "~> 2.0"}` and wire it in `endpoint.ex` (before the router), not in router pipelines: `plug Corsica, origins: "*", allow_headers: :all, max_age: 3600`. Endpoint placement is required so OPTIONS preflight requests are intercepted before routing (no router route matches OPTIONS). Use `origins: "*"` — the atom `:all` is invalid in Corsica 2.x and raises a `FunctionClauseError`.
