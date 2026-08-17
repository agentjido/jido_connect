defmodule Jido.Connect.PreparedAction do
  @moduledoc """
  A secret-free snapshot of one authorized action before provider execution.

  The host must supply the input, context, credential lease, and binding again
  during commit. Jido Connect rejects the commit if one of their hashes changes.
  """

  @enforce_keys [
    :id,
    :integration_id,
    :action_id,
    :connection_id,
    :input_hash,
    :action_hash,
    :connection_hash,
    :lease_hash,
    :binding_hash,
    :risk,
    :confirmation,
    :confirmation_required?,
    :preview,
    :execution_id,
    :idempotency_key,
    :prepared_at,
    :expires_at
  ]

  defstruct @enforce_keys

  alias Jido.Connect.{Data, Error}

  @format_version 1

  @type t :: %__MODULE__{
          id: String.t(),
          integration_id: String.t(),
          action_id: String.t(),
          connection_id: String.t(),
          input_hash: String.t(),
          action_hash: String.t(),
          connection_hash: String.t(),
          lease_hash: String.t(),
          binding_hash: String.t(),
          risk: atom(),
          confirmation: atom(),
          confirmation_required?: boolean(),
          preview: map(),
          execution_id: String.t() | nil,
          idempotency_key: String.t() | nil,
          prepared_at: DateTime.t(),
          expires_at: DateTime.t()
        }

  @doc "Returns true when the prepared action has expired."
  @spec expired?(t(), DateTime.t()) :: boolean()
  def expired?(%__MODULE__{} = prepared, now \\ DateTime.utc_now()) do
    DateTime.compare(prepared.expires_at, now) != :gt
  end

  @doc "Returns the current portable storage format version."
  @spec format_version() :: pos_integer()
  def format_version, do: @format_version

  @doc """
  Dumps a prepared action to a versioned, JSON-safe, secret-free map.

  The dump contains only the same snapshot and preview data as the prepared
  action. It never contains action input or credential fields.
  """
  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = prepared) do
    %{
      "version" => @format_version,
      "id" => prepared.id,
      "integration_id" => to_string(prepared.integration_id),
      "action_id" => prepared.action_id,
      "connection_id" => prepared.connection_id,
      "input_hash" => prepared.input_hash,
      "action_hash" => prepared.action_hash,
      "connection_hash" => prepared.connection_hash,
      "lease_hash" => prepared.lease_hash,
      "binding_hash" => prepared.binding_hash,
      "risk" => Atom.to_string(prepared.risk),
      "confirmation" => Atom.to_string(prepared.confirmation),
      "confirmation_required" => prepared.confirmation_required?,
      "preview" => json_safe(prepared.preview),
      "execution_id" => prepared.execution_id,
      "idempotency_key" => prepared.idempotency_key,
      "prepared_at" => DateTime.to_iso8601(prepared.prepared_at),
      "expires_at" => DateTime.to_iso8601(prepared.expires_at)
    }
  end

  @doc "Loads a prepared action from the supported portable storage format."
  @spec load(map()) :: {:ok, t()} | {:error, Error.ValidationError.t()}
  def load(payload) when is_map(payload) do
    with :ok <- require_version(payload),
         {:ok, integration_id} <- integration_id(payload),
         {:ok, risk} <- existing_atom(payload, :risk),
         {:ok, confirmation} <- existing_atom(payload, :confirmation),
         {:ok, prepared_at} <- datetime(payload, :prepared_at),
         {:ok, expires_at} <- datetime(payload, :expires_at),
         {:ok, confirmation_required?} <- boolean(payload, :confirmation_required),
         {:ok, preview} <- map_value(payload, :preview),
         {:ok, attrs} <- string_fields(payload) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(attrs, %{
           integration_id: integration_id,
           risk: risk,
           confirmation: confirmation,
           confirmation_required?: confirmation_required?,
           preview: preview,
           prepared_at: prepared_at,
           expires_at: expires_at
         })
       )}
    end
  rescue
    error ->
      invalid_dump(%{error: Exception.message(error)})
  end

  def load(_payload), do: invalid_dump(%{expected: :map})

  @doc "Returns the safe fields that a host can persist with its approval record."
  @spec to_public_map(t()) :: map()
  def to_public_map(%__MODULE__{} = prepared) do
    prepared
    |> Map.from_struct()
    |> Map.update!(:prepared_at, &DateTime.to_iso8601/1)
    |> Map.update!(:expires_at, &DateTime.to_iso8601/1)
  end

  defp require_version(payload) do
    case Data.get(payload, :version, :missing) do
      @format_version ->
        :ok

      :missing ->
        invalid_dump(%{missing: :version})

      version ->
        {:error,
         Error.validation("Prepared action version is not supported",
           reason: :unsupported_prepared_action_version,
           subject: version,
           details: %{supported_versions: [@format_version]}
         )}
    end
  end

  defp string_fields(payload) do
    required = [
      :id,
      :action_id,
      :connection_id,
      :input_hash,
      :action_hash,
      :connection_hash,
      :lease_hash,
      :binding_hash
    ]

    optional = [:execution_id, :idempotency_key]

    with {:ok, required_values} <- collect_strings(payload, required, false),
         {:ok, optional_values} <- collect_strings(payload, optional, true) do
      {:ok, Map.merge(required_values, optional_values)}
    end
  end

  defp collect_strings(payload, fields, optional?) do
    Enum.reduce_while(fields, {:ok, %{}}, fn field, {:ok, values} ->
      value = Data.get(payload, field, :missing)

      cond do
        is_binary(value) ->
          {:cont, {:ok, Map.put(values, field, value)}}

        optional? and is_nil(value) ->
          {:cont, {:ok, Map.put(values, field, nil)}}

        true ->
          {:halt,
           invalid_dump(%{
             field: field,
             expected: if(optional?, do: :string_or_nil, else: :string)
           })}
      end
    end)
  end

  defp integration_id(payload) do
    case Data.get(payload, :integration_id, :missing) do
      value when is_binary(value) -> {:ok, value}
      value when is_atom(value) and value != :missing -> {:ok, Atom.to_string(value)}
      _value -> invalid_dump(%{field: :integration_id, expected: :string})
    end
  end

  defp existing_atom(payload, field) do
    case Data.get(payload, field, :missing) do
      value when is_binary(value) ->
        {:ok, String.to_existing_atom(value)}

      value when is_atom(value) and value != :missing ->
        {:ok, value}

      _value ->
        invalid_dump(%{field: field, expected: :existing_atom_name})
    end
  rescue
    ArgumentError -> invalid_dump(%{field: field, expected: :existing_atom_name})
  end

  defp datetime(payload, field) do
    case Data.get(payload, field, :missing) do
      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} -> {:ok, datetime}
          {:error, _reason} -> invalid_dump(%{field: field, expected: :iso8601_datetime})
        end

      %DateTime{} = datetime ->
        {:ok, datetime}

      _value ->
        invalid_dump(%{field: field, expected: :iso8601_datetime})
    end
  end

  defp boolean(payload, field) do
    case Data.get(payload, field, :missing) do
      value when is_boolean(value) -> {:ok, value}
      _value -> invalid_dump(%{field: field, expected: :boolean})
    end
  end

  defp map_value(payload, field) do
    case Data.get(payload, field, :missing) do
      value when is_map(value) -> {:ok, value}
      _value -> invalid_dump(%{field: field, expected: :map})
    end
  end

  defp invalid_dump(details) do
    {:error,
     Error.validation("Prepared action dump is invalid",
       reason: :invalid_prepared_action_dump,
       details: details
     )}
  end

  defp json_safe(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {json_key(key), json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> json_safe()

  defp json_safe(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  defp json_safe(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value), do: value

  defp json_safe(value), do: inspect(value)

  defp json_key(key) when is_binary(key), do: key
  defp json_key(key) when is_atom(key), do: Atom.to_string(key)
  defp json_key(key), do: to_string(key)
end
