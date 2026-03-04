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
- **Use structured (JSON) logging in all environments.** Add `{:logger_json, "~> 7.0"}` (no `only:` restriction) and configure it in `config/config.exs` as the default handler: `config :logger, :default_handler, formatter: {LoggerJSON.Formatters.Basic, metadata: :all}`. Do not add a plain-text formatter override in `dev.exs`. Configure the credo check `{Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, [metadata_keys: :all]}` in `.credo.exs` to silence false positives. The field is named `severity` (not `level`) — this is intentional and follows Google Cloud Logging convention.
- **Log every API request and response.** For Phoenix apps, add a `Plugs.RequestLogger` plug to all API pipelines. On ingress it logs method, path, query string, and merged params; on egress (via `register_before_send/2`) it logs status and JSON-decoded response body. **WARNING: sensitive values (client secrets, tokens) appear in plaintext — do NOT use in production. Dev/test only.**
- **Add CORS support with Corsica.** Add `{:corsica, "~> 2.0"}` and wire it in `endpoint.ex` (before the router), not in router pipelines: `plug Corsica, origins: "*", allow_headers: :all, max_age: 3600`. Endpoint placement is required so OPTIONS preflight requests are intercepted before routing (no router route matches OPTIONS). Use `origins: "*"` — the atom `:all` is invalid in Corsica 2.x and raises a `FunctionClauseError`.
