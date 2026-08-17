defmodule Jido.Connect.Error do
  @moduledoc """
  Centralized Jido Connect error taxonomy.

  Provider packages should return these concrete Splode errors instead of raw
  atoms or provider-specific tuples. Keep provider-specific protocol details in
  `details`; keep stable matching data in `reason`, `provider`, and `status`.
  """

  defmodule Invalid do
    @moduledoc false
    use Splode.ErrorClass, class: :invalid
  end

  defmodule Auth do
    @moduledoc false
    use Splode.ErrorClass, class: :auth
  end

  defmodule Provider do
    @moduledoc false
    use Splode.ErrorClass, class: :provider
  end

  defmodule Config do
    @moduledoc false
    use Splode.ErrorClass, class: :config
  end

  defmodule Execution do
    @moduledoc false
    use Splode.ErrorClass, class: :execution
  end

  defmodule Internal do
    @moduledoc false
    use Splode.ErrorClass, class: :internal

    defmodule UnknownError do
      @moduledoc false
      use Splode.Error, class: :internal, fields: [:message, :details, :error]

      @impl true
      def exception(opts) do
        opts = opts |> Jido.Connect.Error.normalize_opts() |> Keyword.put_new(:details, %{})
        message = Keyword.get(opts, :message) || unknown_message(Keyword.get(opts, :error))

        opts
        |> Keyword.put(:message, message)
        |> super()
      end

      defp unknown_message(nil), do: "Unknown Jido Connect error"
      defp unknown_message(error) when is_binary(error), do: error
      defp unknown_message(error), do: inspect(error)
    end
  end

  use Splode,
    error_classes: [
      invalid: Invalid,
      auth: Auth,
      provider: Provider,
      config: Config,
      execution: Execution,
      internal: Internal
    ],
    unknown_error: Internal.UnknownError

  defmodule ValidationError do
    @moduledoc "Invalid input, DSL, schema, or lookup error."
    use Splode.Error, class: :invalid, fields: [:message, :reason, :subject, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            reason: atom() | nil,
            subject: any(),
            details: map()
          }

    @impl true
    def exception(opts) do
      opts
      |> Jido.Connect.Error.normalize_opts()
      |> Keyword.put_new(:message, "Validation failed")
      |> Keyword.put_new(:details, %{})
      |> super()
    end
  end

  defmodule AuthError do
    @moduledoc "Missing, invalid, or insufficient connection/credential context."
    use Splode.Error,
      class: :auth,
      fields: [:message, :reason, :connection_id, :missing_scopes, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            reason: atom() | nil,
            connection_id: String.t() | nil,
            missing_scopes: [String.t()],
            details: map()
          }

    @impl true
    def exception(opts) do
      opts
      |> Jido.Connect.Error.normalize_opts()
      |> Keyword.put_new(:message, "Authorization failed")
      |> Keyword.put_new(:missing_scopes, [])
      |> Keyword.put_new(:details, %{})
      |> super()
    end
  end

  defmodule ProviderError do
    @moduledoc "Provider API, OAuth, or webhook protocol error."
    use Splode.Error,
      class: :provider,
      fields: [
        :message,
        :provider,
        :reason,
        :status,
        :delivery,
        :action_risk,
        :mutation?,
        :provider_idempotency?,
        :details
      ]

    @type t :: %__MODULE__{
            message: String.t(),
            provider: atom() | nil,
            reason: atom() | String.t() | nil,
            status: non_neg_integer() | nil,
            delivery: :not_sent | :rejected | :response_received | :sent_outcome_unknown,
            action_risk: atom() | nil,
            mutation?: boolean(),
            provider_idempotency?: boolean(),
            details: map()
          }

    @impl true
    def exception(opts) do
      opts
      |> Jido.Connect.Error.normalize_opts()
      |> Keyword.put_new(:message, "Provider request failed")
      |> Keyword.put_new(:delivery, :sent_outcome_unknown)
      |> Keyword.put_new(:mutation?, false)
      |> Keyword.put_new(:provider_idempotency?, false)
      |> Keyword.put_new(:details, %{})
      |> super()
    end
  end

  defmodule ConfigError do
    @moduledoc "Local configuration or setup error."
    use Splode.Error, class: :config, fields: [:message, :key, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            key: atom() | String.t() | nil,
            details: map()
          }

    @impl true
    def exception(opts) do
      opts
      |> Jido.Connect.Error.normalize_opts()
      |> Keyword.put_new(:message, "Configuration error")
      |> Keyword.put_new(:details, %{})
      |> super()
    end
  end

  defmodule ExecutionError do
    @moduledoc "Runtime handler, polling, or generated Jido adapter error."
    use Splode.Error, class: :execution, fields: [:message, :phase, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            phase: atom() | nil,
            details: map()
          }

    @impl true
    def exception(opts) do
      opts
      |> Jido.Connect.Error.normalize_opts()
      |> Keyword.put_new(:message, "Execution failed")
      |> Keyword.put_new(:details, %{})
      |> super()
    end
  end

  defmodule InternalError do
    @moduledoc "Unexpected internal package error."
    use Splode.Error, class: :internal, fields: [:message, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            details: map()
          }

    @impl true
    def exception(opts) do
      opts
      |> Jido.Connect.Error.normalize_opts()
      |> Keyword.put_new(:message, "Internal error")
      |> Keyword.put_new(:details, %{})
      |> super()
    end
  end

  @type error ::
          ValidationError.t()
          | AuthError.t()
          | ProviderError.t()
          | ConfigError.t()
          | ExecutionError.t()
          | InternalError.t()

  @spec validation(String.t(), keyword() | map()) :: ValidationError.t()
  def validation(message, opts \\ []) do
    ValidationError.exception(Keyword.put(normalize_opts(opts), :message, message))
  end

  @spec auth(String.t(), keyword() | map()) :: AuthError.t()
  def auth(message, opts \\ []) do
    AuthError.exception(Keyword.put(normalize_opts(opts), :message, message))
  end

  @spec provider(String.t(), keyword() | map()) :: ProviderError.t()
  def provider(message, opts \\ []) do
    opts =
      opts
      |> normalize_opts()
      |> Keyword.put_new(:delivery, infer_delivery(opts))
      |> Keyword.put_new(:mutation?, false)
      |> Keyword.put_new(:provider_idempotency?, false)
      |> sanitize_provider_opts()
      |> Keyword.put(:message, message)

    ProviderError.exception(opts)
  end

  @spec config(String.t(), keyword() | map()) :: ConfigError.t()
  def config(message, opts \\ []) do
    ConfigError.exception(Keyword.put(normalize_opts(opts), :message, message))
  end

  @spec execution(String.t(), keyword() | map()) :: ExecutionError.t()
  def execution(message, opts \\ []) do
    ExecutionError.exception(Keyword.put(normalize_opts(opts), :message, message))
  end

  @spec internal(String.t(), keyword() | map()) :: InternalError.t()
  def internal(message, opts \\ []) do
    InternalError.exception(Keyword.put(normalize_opts(opts), :message, message))
  end

  def unknown_action(action_id) do
    validation("Unknown action", reason: :unknown_action, subject: action_id)
  end

  def unknown_trigger(trigger_id) do
    validation("Unknown trigger", reason: :unknown_trigger, subject: trigger_id)
  end

  def unknown_integration(integration_ref) do
    validation("Unknown integration",
      reason: :unknown_integration,
      subject: integration_ref
    )
  end

  def invalid_integration(integration_ref, value) do
    validation("Integration module did not return a Jido.Connect.Spec",
      reason: :invalid_integration,
      subject: integration_ref,
      details: %{returned: inspect(value)}
    )
  end

  def invalid_provider_manifest(provider, value) do
    validation("Provider module did not return a Jido.Connect.Catalog.Manifest",
      reason: :invalid_provider_manifest,
      subject: provider,
      details: %{returned: inspect(value)}
    )
  end

  def invalid_provider_modules(provider, value) do
    validation("Provider module returned invalid generated module metadata",
      reason: :invalid_provider_modules,
      subject: provider,
      details: %{returned: inspect(value)}
    )
  end

  def zoi(reason, errors, details \\ %{}) do
    validation("Schema validation failed",
      reason: reason,
      details: Map.merge(%{errors: List.wrap(errors)}, details)
    )
  end

  def context_required do
    auth("Integration context is required", reason: :context_required)
  end

  def credential_lease_required do
    auth("Credential lease is required", reason: :credential_lease_required)
  end

  def credential_lease_expired(expires_at) do
    auth("Credential lease has expired",
      reason: :credential_lease_expired,
      details: %{expires_at: expires_at}
    )
  end

  def connection_required(details \\ %{}) do
    auth("Connected provider connection is required",
      reason: :connection_required,
      details: details
    )
  end

  def credential_connection_mismatch(connection_id, lease_connection_id, details \\ %{}) do
    auth("Credential lease does not match connection",
      reason: :credential_connection_mismatch,
      connection_id: connection_id,
      details: Map.put(details, :lease_connection_id, lease_connection_id)
    )
  end

  def unsupported_auth_profile(connection_id, profile, allowed_profiles) do
    auth("Connection auth profile is not allowed for this operation",
      reason: :unsupported_auth_profile,
      connection_id: connection_id,
      details: %{profile: profile, allowed_profiles: allowed_profiles}
    )
  end

  def missing_scopes(connection_id, scopes) do
    auth("Connection is missing required scopes",
      reason: :missing_scopes,
      connection_id: connection_id,
      missing_scopes: scopes
    )
  end

  def policy_denied(connection_id, details \\ %{}) do
    auth("Host policy denied connection use",
      reason: :policy_denied,
      connection_id: connection_id,
      details: Map.new(details)
    )
  end

  @spec to_map(term()) :: map()
  def to_map(error) do
    error = to_error(error)

    %{
      type: type(error),
      class: Map.get(error, :class),
      message: Exception.message(error),
      reason: Map.get(error, :reason),
      delivery: Map.get(error, :delivery),
      action_risk: Map.get(error, :action_risk),
      details: Jido.Connect.Sanitizer.sanitize(Map.get(error, :details, %{}), :transport),
      retryable?: retryable?(error),
      retry_guidance: retry_guidance(error)
    }
  end

  @spec type(term()) :: atom()
  def type(%ValidationError{}), do: :validation_error
  def type(%AuthError{}), do: :auth_error
  def type(%ProviderError{}), do: :provider_error
  def type(%ConfigError{}), do: :config_error
  def type(%ExecutionError{}), do: :execution_error
  def type(%InternalError{}), do: :internal_error
  def type(%Internal.UnknownError{}), do: :unknown_error

  def type(%_module{}), do: :unknown_error
  def type(_other), do: :unknown_error

  @spec error?(term()) :: boolean()
  def error?(%{class: class})
      when class in [:invalid, :auth, :provider, :config, :execution, :internal],
      do: true

  def error?(_error), do: false

  @spec retryable?(term()) :: boolean()
  def retryable?(%ProviderError{
        delivery: :sent_outcome_unknown,
        mutation?: true,
        provider_idempotency?: false
      }),
      do: false

  def retryable?(%ProviderError{delivery: :not_sent}), do: true

  def retryable?(%ProviderError{status: status}) when status == 429 or status in 500..599,
    do: true

  def retryable?(%ProviderError{reason: reason})
      when reason in [:request_error, :timeout, :rate_limited, "rate_limited"],
      do: true

  def retryable?(%ExecutionError{phase: phase}) when phase in [:timeout, :transport],
    do: true

  def retryable?(_error), do: false

  @doc "Returns stable retry guidance for a normalized provider failure."
  @spec retry_guidance(term()) ::
          :safe_to_retry | :retry_with_idempotency | :do_not_retry | :not_applicable
  def retry_guidance(%ProviderError{
        delivery: :sent_outcome_unknown,
        mutation?: true,
        provider_idempotency?: true
      }),
      do: :retry_with_idempotency

  def retry_guidance(%ProviderError{
        delivery: :sent_outcome_unknown,
        mutation?: true,
        provider_idempotency?: false
      }),
      do: :do_not_retry

  def retry_guidance(%ProviderError{} = error) do
    if retryable?(error), do: :safe_to_retry, else: :do_not_retry
  end

  def retry_guidance(_error), do: :not_applicable

  @doc false
  @spec with_action_context(ProviderError.t(), Jido.Connect.ActionSpec.t()) :: ProviderError.t()
  def with_action_context(%ProviderError{} = error, %Jido.Connect.ActionSpec{} = action) do
    %{
      error
      | action_risk: action.risk,
        mutation?: action.mutation?,
        provider_idempotency?: action.provider_idempotency?
    }
  end

  @doc false
  def normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  def normalize_opts(opts), do: opts || []

  defp infer_delivery(opts) do
    opts = normalize_opts(opts)

    cond do
      Keyword.get(opts, :delivery) in [
        :not_sent,
        :rejected,
        :response_received,
        :sent_outcome_unknown
      ] ->
        Keyword.fetch!(opts, :delivery)

      status = Keyword.get(opts, :status) ->
        if status in 200..299, do: :response_received, else: :rejected

      Keyword.get(opts, :reason) in [:econnrefused, :nxdomain, :enetunreach, :ehostunreach] ->
        :not_sent

      true ->
        :sent_outcome_unknown
    end
  end

  defp sanitize_provider_opts(opts) do
    Keyword.update(opts, :details, %{}, fn details ->
      Jido.Connect.Sanitizer.sanitize_provider_details(details, :telemetry,
        max_depth: 6,
        max_binary: 256,
        max_collection: 20
      )
    end)
  end
end
