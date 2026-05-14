defmodule Jido.Connect do
  @moduledoc """
  Core integration authoring and runtime contracts.

  `use Jido.Connect` enables the Spark integration DSL. The DSL compiles into
  Zoi-backed structs under `Jido.Connect.*`; those structs are runtime truth,
  not the Spark entities.

  Host apps and tests can pass either a provider module or a compiled
  `%Jido.Connect.Spec{}` into the top-level runtime functions:

      Jido.Connect.invoke(Jido.Connect.GitHub, "github.issue.list", params,
        context: context,
        credential_lease: lease
      )

  Generated Jido modules call the same runtime boundary. Provider handlers are
  invoked only after context, connection, credential lease, auth profile, and
  scope checks pass.
  """

  @typedoc "Field type supported by the Spark DSL and generated Zoi schemas."
  @type field_type :: :string | :integer | :boolean | :map | {:array, field_type()}
  @typedoc "Owner type for durable host-owned connections and credential leases."
  @type owner_type :: :user | :tenant | :org | :system | :installation | :app_user
  @typedoc "Auth profile kind supported by the core contract."
  @type auth_kind ::
          :oauth2
          | :api_key
          | :app_installation
          | :service_account
          | :domain_delegated_service_account
          | :none
  @typedoc "Trigger transport supported by generated sensors."
  @type trigger_kind :: :webhook | :poll
  @typedoc "Provider module implementing `integration/0` or an already compiled spec."
  @type integration_ref :: module() | Spec.t()
  @typedoc "Runtime options accepted by `invoke/4` and `poll/4`."
  @type runtime_opts :: keyword() | map()

  alias Jido.Connect.{
    ActionSpec,
    Error,
    Provider,
    Runtime,
    Schema,
    Spec,
    TriggerSpec
  }

  use Spark.Dsl,
    default_extensions: [extensions: Jido.Connect.Dsl.Extension]

  @doc """
  Returns a compiled integration spec from a provider module or spec.

  This keeps host-facing calls ergonomic while still making `%Jido.Connect.Spec{}`
  the runtime source of truth.
  """
  @spec spec(integration_ref()) :: {:ok, Spec.t()} | {:error, Error.error()}
  defdelegate spec(integration_ref), to: Provider

  @doc "Returns the action specs for an integration."
  @spec actions(integration_ref()) :: {:ok, [ActionSpec.t()]} | {:error, Error.error()}
  def actions(integration_ref) do
    with {:ok, %Spec{actions: actions}} <- spec(integration_ref) do
      {:ok, actions}
    end
  end

  @doc "Returns the trigger specs for an integration."
  @spec triggers(integration_ref()) :: {:ok, [TriggerSpec.t()]} | {:error, Error.error()}
  def triggers(integration_ref) do
    with {:ok, %Spec{triggers: triggers}} <- spec(integration_ref) do
      {:ok, triggers}
    end
  end

  @doc "Returns the auth profiles for an integration."
  @spec auth_profiles(integration_ref()) ::
          {:ok, [Jido.Connect.AuthProfile.t()]} | {:error, Error.error()}
  def auth_profiles(integration_ref) do
    with {:ok, %Spec{auth_profiles: auth_profiles}} <- spec(integration_ref) do
      {:ok, auth_profiles}
    end
  end

  @doc "Looks up one action by id."
  @spec action(integration_ref(), String.t()) :: {:ok, ActionSpec.t()} | {:error, Error.error()}
  def action(integration_ref, action_id) when is_binary(action_id) do
    with {:ok, %Spec{} = integration} <- spec(integration_ref) do
      find_action(integration, action_id)
    end
  end

  def action(_integration_ref, action_id) do
    {:error,
     Error.validation("Action id must be a string",
       reason: :invalid_action_id,
       subject: action_id
     )}
  end

  @doc "Looks up one trigger by id."
  @spec trigger(integration_ref(), String.t()) ::
          {:ok, TriggerSpec.t()} | {:error, Error.error()}
  def trigger(integration_ref, trigger_id) when is_binary(trigger_id) do
    with {:ok, %Spec{} = integration} <- spec(integration_ref) do
      find_trigger(integration, trigger_id)
    end
  end

  def trigger(_integration_ref, trigger_id) do
    {:error,
     Error.validation("Trigger id must be a string",
       reason: :invalid_trigger_id,
       subject: trigger_id
     )}
  end

  defp find_action(%Spec{} = integration, action_id) do
    case Enum.find(integration.actions, &(&1.id == action_id)) do
      %ActionSpec{} = action -> {:ok, action}
      nil -> {:error, Error.unknown_action(action_id)}
    end
  end

  defp find_trigger(%Spec{} = integration, trigger_id) do
    case Enum.find(integration.triggers, &(&1.id == trigger_id)) do
      %TriggerSpec{} = trigger -> {:ok, trigger}
      nil -> {:error, Error.unknown_trigger(trigger_id)}
    end
  end

  @doc """
  Invokes an action through the core runtime boundary.

  `integration_ref` may be a provider module or `%Jido.Connect.Spec{}`. `opts`
  must include `:context` and `:credential_lease`; both may be structs or maps
  that coerce into `Jido.Connect.Context` and `Jido.Connect.CredentialLease`.
  """
  @spec invoke(integration_ref(), String.t(), map(), runtime_opts()) ::
          {:ok, map()} | {:error, Error.error()}
  def invoke(integration_ref, action_id, input, opts \\ [])

  def invoke(integration_ref, action_id, input, opts)
      when is_binary(action_id) and is_map(input) and (is_list(opts) or is_map(opts)) do
    with {:ok, integration} <- spec(integration_ref) do
      Runtime.invoke(integration, action_id, input, opts)
    end
  end

  def invoke(_integration_ref, action_id, _input, _opts) when not is_binary(action_id) do
    {:error,
     Error.validation("Action id must be a string",
       reason: :invalid_action_id,
       subject: action_id
     )}
  end

  def invoke(_integration_ref, action_id, input, opts) do
    {:error,
     Error.validation("Invalid action invocation",
       reason: :invalid_invocation,
       subject: action_id,
       details: %{input_type: type_name(input), opts_type: type_name(opts)}
     )}
  end

  @doc """
  Executes one poll trigger through the core runtime boundary.

  `opts` accepts the same `:context` and `:credential_lease` values as
  `invoke/4`, plus an optional `:checkpoint`.
  """
  @spec poll(integration_ref(), String.t(), map(), runtime_opts()) ::
          {:ok, %{signals: [map()], checkpoint: term()}} | {:error, Error.error()}
  def poll(integration_ref, trigger_id, config, opts \\ [])

  def poll(integration_ref, trigger_id, config, opts)
      when is_binary(trigger_id) and is_map(config) and (is_list(opts) or is_map(opts)) do
    with {:ok, integration} <- spec(integration_ref) do
      Runtime.poll(integration, trigger_id, config, opts)
    end
  end

  def poll(_integration_ref, trigger_id, _config, _opts) when not is_binary(trigger_id) do
    {:error,
     Error.validation("Trigger id must be a string",
       reason: :invalid_trigger_id,
       subject: trigger_id
     )}
  end

  def poll(_integration_ref, trigger_id, config, opts) do
    {:error,
     Error.validation("Invalid trigger poll",
       reason: :invalid_poll,
       subject: trigger_id,
       details: %{config_type: type_name(config), opts_type: type_name(opts)}
     )}
  end

  @doc "Validates a compiled integration spec and raises on structural errors."
  @spec validate_spec!(Spec.t()) :: Spec.t()
  def validate_spec!(%Spec{} = spec), do: Jido.Connect.Spec.Validator.validate!(spec)

  @doc false
  def zoi_schema_from_fields(fields), do: Schema.zoi_schema_from_fields(fields)

  defp type_name(value) when is_map(value), do: :map
  defp type_name(value) when is_list(value), do: :list
  defp type_name(value) when is_binary(value), do: :string
  defp type_name(value) when is_atom(value), do: :atom
  defp type_name(value) when is_integer(value), do: :integer
  defp type_name(value) when is_float(value), do: :float
  defp type_name(_value), do: :unknown
end
