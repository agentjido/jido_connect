defmodule Jido.Connect.Dsl.AuthProfile do
  @moduledoc false

  defstruct [
    :id,
    :__identifier__,
    :__spark_metadata__,
    :kind,
    :owner,
    :subject,
    :label,
    :authorize_url,
    :token_url,
    :callback_path,
    :token_field,
    :refresh_token_field,
    :setup,
    scopes: [],
    default_scopes: [],
    optional_scopes: [],
    credential_fields: [],
    lease_fields: [],
    fields: [],
    pkce?: false,
    refresh?: false,
    revoke?: false,
    default?: false,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Capability do
  @moduledoc false

  defstruct [
    :name,
    :__identifier__,
    :__spark_metadata__,
    :id,
    :kind,
    :feature,
    :label,
    :description,
    status: :available,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.PolicyRequirement do
  @moduledoc false

  defstruct [
    :name,
    :__identifier__,
    :__spark_metadata__,
    :id,
    :label,
    :description,
    :subject,
    :owner,
    decision: :allow_operation,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Requirements do
  @moduledoc false

  defstruct [
    :__spark_metadata__,
    :dynamic_scopes,
    scopes: []
  ]
end

defmodule Jido.Connect.Dsl.ScopeRequirements do
  @moduledoc false

  defstruct [
    :__spark_metadata__,
    :resolver,
    scopes: []
  ]
end

defmodule Jido.Connect.Dsl.AuthProfiles do
  @moduledoc false

  defstruct [
    :profiles,
    :__spark_metadata__,
    default: nil
  ]
end

defmodule Jido.Connect.Dsl.Access do
  @moduledoc false

  defstruct [
    :__spark_metadata__,
    :auth,
    :scopes,
    policies: []
  ]
end

defmodule Jido.Connect.Dsl.Effect do
  @moduledoc false

  defstruct [
    :__spark_metadata__,
    :risk,
    :confirmation,
    mutation?: nil
  ]
end

defmodule Jido.Connect.Dsl.NamedSchema do
  @moduledoc false

  defstruct [
    :name,
    :__identifier__,
    :__spark_metadata__,
    :label,
    :description,
    fields: [],
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Action do
  @moduledoc false

  defstruct [
    :name,
    :__identifier__,
    :__spark_metadata__,
    :id,
    :label,
    :description,
    :resource,
    :verb,
    :data_classification,
    :handler,
    :auth_profiles,
    :access,
    :effect,
    :requirements,
    :input_schema,
    :output_schema,
    tags: [],
    input: [],
    output: [],
    policies: [],
    mutation?: false,
    risk: :read,
    confirmation: :none,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Trigger do
  @moduledoc false

  defstruct [
    :name,
    :__identifier__,
    :__spark_metadata__,
    :id,
    :kind,
    :label,
    :description,
    :resource,
    :verb,
    :data_classification,
    :handler,
    :auth_profiles,
    :access,
    :requirements,
    :config_schema,
    :signal_schema,
    tags: [],
    config: [],
    signal: [],
    policies: [],
    verification: %{kind: :none},
    dedupe: nil,
    checkpoint: nil,
    interval_ms: nil,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Field do
  @moduledoc false

  def transform(%Jido.Connect.Field{} = field), do: {:ok, field}
end

defmodule Jido.Connect.Dsl.FieldGroup do
  @moduledoc false

  defstruct [:__spark_metadata__, fields: []]
end
