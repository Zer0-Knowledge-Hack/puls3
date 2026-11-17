# Run an agent locally

`puls3 run` runs an agent from its manifest on your machine, with your own model provider credential. It does not need the puls3 server, it never opens a wallet, and it never sends a transaction. Use it to try a manifest before you deploy it from the Studio.

It runs the agent the way the server runtime does: the same manifest rules as deploy, the same request (system prompt, your input, the model id and `max_tokens`), and the same input and output limits.

## 1. Install the workspace

Once, as in the [CLI reference](reference.md#run-it):

```bash
cd puls3
flutter pub get --enforce-lockfile
cd puls3_cli
```

The examples below write `puls3` for `dart run bin/puls3.dart`, run from `puls3_cli/`.

## 2. Write or export a manifest

A manifest is the JSON document the Studio exports: a draft without `version`, or a deployed manifest with `schema` and `version`. The example [`puls3_cli/example/soroban_pre_audit.json`](../../puls3_cli/example/soroban_pre_audit.json) is a Soroban pre-audit agent on Llama 3.3 70B (Workers AI):

```json
{
  "name": "Soroban Pre-Audit",
  "description": "Reviews a Soroban smart contract before a formal audit and lists the security issues it finds, ordered by severity.",
  "skills": [
    {"id": "soroban-security-review", "name": "Soroban security review", "description": "…", "tags": ["soroban", "security", "rust"]},
    {"id": "auth-check", "name": "Authorization check", "description": "…", "tags": ["soroban", "auth"]},
    {"id": "storage-ttl-review", "name": "Storage and TTL review", "description": "…", "tags": ["soroban", "storage"]}
  ],
  "model": {"provider": "workers-ai", "id": "@cf/meta/llama-3.3-70b-instruct-fp8-fast"},
  "system_prompt": "You are a smart contract security reviewer for Stellar Soroban contracts …",
  "input": {"type": "text", "max_chars": 8000},
  "output": {"type": "markdown", "max_chars": 6000},
  "price": {"asset": "USDC", "amount": 5000000}
}
```

`price.amount` is in stroops (7 decimals): `5000000` is 0.50 USDC. A local run does not charge it.

The manifest must pass the deploy rules (`AgentManifestDraft.validate` in `puls3_domain`) with the Studio's model policy:

| `model.provider` | Accepted `model.id` |
|---|---|
| `workers-ai` | `@cf/meta/llama-3.3-70b-instruct-fp8-fast` |
| `anthropic` | any Claude model id, for example `claude-sonnet-5-5` |

## 3. Set your credential

`puls3 run` reads your credential from the environment and sends it only to the provider, in a header. It never prints it.

| `model.provider` | Environment variables | Where to get them |
|---|---|---|
| `workers-ai` | `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` | Cloudflare dashboard: your account id, and an API token with the *Workers AI* permission. |
| `anthropic` | `ANTHROPIC_API_KEY` | The Claude Console. |

These are your own credentials, not the puls3 server's (the server reads `PULS3_WORKERS_AI_ACCOUNT_ID` and a Serverpod password; `puls3 run` does not).

```bash
export CLOUDFLARE_ACCOUNT_ID=<your account id>
export CLOUDFLARE_API_TOKEN=<your Workers AI token>
```

## 4. Run it

```bash
puls3 run --manifest example/soroban_pre_audit.json \
  --input "pub fn withdraw(env: Env, to: Address, amount: i128) { token::Client::new(&env, &asset).transfer(&env.current_contract_address(), &to, &amount); }"
```

The input comes from exactly one of:

| Option | Input |
|---|---|
| `--input <text>` | The text itself. |
| `--input-file <path>` | The content of a file, for example `--input-file src/lib.rs`. |
| `--input -` or `--input-file -` | Standard input: `cat src/lib.rs \| puls3 run --manifest agent.json --input -`. |

The manifest can also be the only positional argument: `puls3 run agent.json --input-file src/lib.rs`.

The agent's output goes to stdout, as the model wrote it (Markdown for this example). With `--json` (before or after `run`) it prints one JSON object:

```json
{"output":"## Summary\n…","model":"workers-ai/@cf/meta/llama-3.3-70b-instruct-fp8-fast","inputChars":152,"outputChars":2311,"elapsedMs":8412}
```

`inputChars` and `outputChars` count characters (Unicode code points), as the manifest limits do.

## Limits

| Limit | What happens |
|---|---|
| Input over `input.max_chars` | `InputTooLong`, exit 65, before the model is called. |
| Output over `output.max_chars`, or blank | `OutputTooLong` or `EmptyOutput`, exit 1. Nothing is printed to stdout. |
| `max_tokens` | Workers AI: `output.max_chars`, at most 4096. Anthropic: `output.max_chars` + 4000, at most 16000. |
| Time | 120 seconds, then the call is aborted: `Unreachable`, exit 69. |

## Errors and exit codes

Every failure writes one `error: <code>: <message>` line to stderr and nothing to stdout. Messages never hold your credential, your prompt or the provider's own message.

| Exit | Code on stderr | When |
|---|---|---|
| 0 | none | The agent answered. |
| 1 | `ProviderError` | The provider answered an error, for example `workers-ai answered HTTP 401 (cloudflare_10000)` for a bad token. |
| 1 | `Refused`, `OutputTruncated`, `OutputTooLong`, `EmptyOutput` | The model declined, stopped at its token limit, or broke the output limit. |
| 64 | `Usage` | No manifest, or not exactly one of `--input` and `--input-file`. |
| 65 | `InvalidManifest` | The manifest is not JSON or breaks a deploy rule (every broken rule is listed). |
| 65 | `InputTooLong` | The input is over `input.max_chars`. |
| 66 | `ManifestUnreadable`, `InputUnreadable` | The manifest or input file cannot be read. |
| 69 | `Unreachable` | The provider did not answer in 120 seconds, or the connection failed. |
| 78 | `MissingCredential` | The credential for the manifest's provider is not set: `error: MissingCredential: workers-ai runs with your own credential: set CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN`. |
