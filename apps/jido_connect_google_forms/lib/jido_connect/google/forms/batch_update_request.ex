defmodule Jido.Connect.Google.Forms.BatchUpdateRequest do
  @moduledoc """
  Normalized Google Forms batchUpdate request envelope.

  Each request in the `requests` list must contain exactly one operation.
  Supported operation keys provide safe schema boundaries for the most common
  Google Forms batch update operations.
  """

  @supported_operations MapSet.new(~w(
    create_item
    update_item
    delete_item
    update_form_info
    update_settings
    move_item
    update_form_title
    update_form_description
  ))

  @max_requests 100

  @schema Zoi.struct(
            __MODULE__,
            %{
              form_id: Zoi.string(),
              requests: Zoi.list(Zoi.map()),
              write_control: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)

  @doc "Returns the set of supported batch update operation keys."
  def supported_operations, do: @supported_operations

  @doc "Returns the maximum allowed number of requests in a single batch."
  def max_requests, do: @max_requests

  @doc """
  Validates that each request map contains exactly one supported operation key.

  Returns `:ok` or `{:error, reason}`.
  """
  def validate_requests(requests) when is_list(requests) do
    cond do
      requests == [] ->
        {:error, :empty_requests}

      length(requests) > @max_requests ->
        {:error, {:too_many_requests, length(requests), @max_requests}}

      true ->
        validate_each(requests, 0)
    end
  end

  def validate_requests(_), do: {:error, :not_a_list}

  defp validate_each([], _index), do: :ok

  defp validate_each([request | rest], index) when is_map(request) do
    keys = Map.keys(request)

    cond do
      length(keys) != 1 ->
        {:error, {:invalid_request, index, "must contain exactly one operation"}}

      not supported_key?(hd(keys)) ->
        {:error, {:unsupported_operation, index, hd(keys)}}

      true ->
        validate_each(rest, index + 1)
    end
  end

  defp validate_each([_request | _rest], index) do
    {:error, {:invalid_request, index, "must be a map"}}
  end

  defp supported_key?(key) when is_atom(key),
    do: MapSet.member?(@supported_operations, Atom.to_string(key))

  defp supported_key?(key) when is_binary(key), do: MapSet.member?(@supported_operations, key)
  defp supported_key?(_), do: false
end
