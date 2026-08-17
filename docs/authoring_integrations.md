# Authoring Integrations

Provider packages use `use Jido.Connect` and declare integration identity,
catalog metadata, auth profiles, host policy requirements, actions, and
triggers. The Spark DSL compiles the declaration into a `Jido.Connect.Spec`,
Zoi-backed contract structs, catalog records, and generated Jido modules.

Generated modules are adapters. Provider business logic belongs in handler
modules referenced by the DSL.

## Provider Package Shape

A connector should stay narrow:

- `integration.ex` declares provider identity, catalog capabilities, schemas,
  auth profiles, shared policy requirements, and fragment imports.
- `actions/*.ex` and `triggers/*.ex` group resource-specific Spark fragments
  so large providers do not turn into one giant DSL file.
- `oauth.ex` wraps provider-specific OAuth exchange and credential lease shaping.
- `client.ex` owns provider HTTP paths and response normalization.
- `webhook.ex` owns provider webhook verification and signal normalization.
- handlers contain provider business logic and read credentials only from
  `CredentialLease.fields`.

Start a new package scaffold with:

```sh
mix jido.connect.gen.provider google_sheets
```

## Shared Core Helpers

- `Jido.Connect.CredentialLease` for short-lived credential material normalized
  from OAuth, app installation, API key, or bridge credentials.
- `Jido.Connect.ProviderResponse` for reusable provider response and error
  envelopes.
- `Jido.Connect.WebhookDelivery` for verified webhook metadata and normalized
  signals.
- `Jido.Connect.ConnectorCapability` for catalog-facing feature metadata.
- `Jido.Connect.OAuth` for authorization URLs, required secret lookup, and Req
  defaults.
- `Jido.Connect.Http` for bearer Req setup and provider error shaping.
- `Jido.Connect.Webhook` for HMAC verification, header lookup, duplicate checks,
  and JSON decoding.
- `Jido.Connect.Polling` for checkpoint params and latest checkpoint selection.
- `Jido.Connect.Catalog` for host-facing connector metadata derived from specs
  and generated projections.
- `Jido.Connect.Policy` for normalizing host-owned policy callbacks.

Provider packages should normalize provider-specific maps into these structs
before exposing data to hosts or generated Jido runtimes.

## V2 DSL Shape

Use first-class DSL sections instead of loose metadata maps:

```elixir
use Jido.Connect

integration do
  id :github
  name "GitHub"
  description "GitHub repository and issue tools."
  category :developer_tools
  docs ["https://docs.github.com/rest"]
end

catalog do
  package :jido_connect_github
  status :available
  tags [:source_control, :issues]

  capability :webhook_verification do
    kind :webhook
    feature :webhook_verification
    label "Webhook verification"
  end
end

auth do
  oauth2 :user do
    default? true
    owner :app_user
    subject :user
    setup :oauth2_authorization_code
    authorize_url "https://github.com/login/oauth/authorize"
    token_url "https://github.com/login/oauth/access_token"
    token_field :access_token
    credential_fields [:access_token]
    lease_fields [:access_token]
    scopes ["repo", "read:user"]
    default_scopes ["read:user"]
  end
end

policies do
  policy :repo_access do
    subject {:input, :repo}
    owner {:connection, :owner}
    decision :allow_operation
  end
end

actions do
  action :list_issues do
    id "github.issue.list"
    resource :issue
    verb :list
    data_classification :workspace_content
    handler MyProvider.Handlers.ListIssues
    effect :read

    access do
      auth :user
      policies [:repo_access]
      scopes ["repo"], resolver: MyProvider.ScopeResolver
    end

    input do
      field :repo, :string, required?: true
    end
  end
end
```

Generated projections preserve the declared resource, verb, policy, auth,
scope, risk, confirmation, and schema metadata for host UIs and policy
callbacks.

New providers should use `access` and `effect`. The older `auth_profiles`,
`requirements`, direct action/trigger `policies`, `mutation?`, `risk`, and
`confirmation` fields remain as compatibility inputs, but should not be mixed
with the canonical form in the same operation. The DSL enforces resource, verb,
and data classification on every action and trigger so catalog search, policy
callbacks, audit trails, and host UIs have stable metadata across providers.

## Safe Write Previews And Idempotency

A write action can declare a provider preview module:

```elixir
defmodule MyProvider.Previews.CreateIssue do
  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _public_context) do
    %{
      repository: input.repo,
      title: input.title,
      body_bytes: byte_size(input.body || "")
    }
  end
end

actions do
  action :create_issue do
    id "provider.issue.create"
    resource :issue
    verb :create
    data_classification :workspace_content
    handler MyProvider.Handlers.CreateIssue
    preview MyProvider.Previews.CreateIssue
    effect :external_write, confirmation: :required_for_ai

    input do
      field :repo, :string, required?: true, min_length: 1, max_length: 200
      field :title, :string, required?: true, min_length: 1, max_length: 256
      field :body, :string, max_length: 65_536
    end
  end
end
```

The preview callback gets parsed input and public action/connection metadata.
It does not get credentials or a credential lease. It must be pure and must not
call the provider. Core sanitizes its result before it stores the preview. Core
also owns the `action_id`, `connection`, and `input_fields` preview keys and
ignores provider values for these reserved keys.

Use `minimum` and `maximum` for number fields. Use `min_length` and `max_length`
for string fields. These rules apply at runtime and appear in strict catalog
JSON schemas.

Action handlers can return normalized provider maps or structs. Before output
validation, the runtime keeps only the top-level fields in the action `output`
declaration. Hosts receive only the declared strict output contract.

Declare provider idempotency only when the provider gives this guarantee and
the handler sends the runtime key:

```elixir
effect :external_write,
  confirmation: :required_for_ai,
  provider_idempotency?: true

idempotency_key = get_in(context, [:execution, :idempotency_key])
```

An action declaration alone does not send a header and does not deduplicate a
request. The handler must use the same key for every allowed retry. Provider
clients must also preserve the delivery state in normalized errors so hosts can
separate a request that was not sent from an uncertain write.

## Splitting Large Providers

Large connectors should split declarations by resource using Spark fragments.
The top-level integration keeps provider identity, auth, and shared policies;
resource files add actions or triggers.

```elixir
defmodule Jido.Connect.GitHub.Issues do
  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_issues do
      id "github.issue.list"
      resource :issue
      verb :list
      data_classification :workspace_content
      label "List issues"
      handler Jido.Connect.GitHub.Handlers.Actions.ListIssues
      effect :read

      access do
        auth [:user, :installation], default: :user
        policies [:repo_access]
        scopes ["repo"], resolver: Jido.Connect.GitHub.ScopeResolver
      end
    end
  end
end

defmodule Jido.Connect.GitHub do
  use Jido.Connect, fragments: [
    Jido.Connect.GitHub.Issues
  ]

  integration do
    id :github
    name "GitHub"
  end
end
```

This keeps generated module names anchored to the parent provider namespace
while allowing provider packages to organize DSL files as `issues.ex`,
`pull_requests.ex`, `repositories.ex`, and so on.

## Discovering The Catalog

Provider packages self-register through application metadata:

```elixir
def application do
  [
    extra_applications: [:logger],
    env: [jido_connect_providers: [Jido.Connect.GitHub]]
  ]
end
```

`use Jido.Connect` generates the provider behavior and catalog manifest from
the DSL, so connector authors should not maintain a second manifest by hand.
Host apps can still pass `modules: [...]` to catalog functions when they need an
explicit subset. Browse installed providers from code:

```elixir
Jido.Connect.Catalog.discover(query: "issue")
Jido.Connect.Catalog.discover(auth_kind: :oauth2)
Jido.Connect.Catalog.discover(tag: :issues)
Jido.Connect.Catalog.discover(tool: "github.issue.list")
Jido.Connect.Catalog.discover(capability: :webhook_verification)
Jido.Connect.Catalog.tools(query: "message", type: :action)
Jido.Connect.Catalog.tools(resource: :message, verb: :create)
Jido.Connect.Catalog.tools(scope: "chat:write")
```

For local inspection, use:

```sh
mix jido.connect.catalog --query issue
mix jido.connect.catalog --format json --query slack
```
