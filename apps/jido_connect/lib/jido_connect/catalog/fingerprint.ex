defmodule Jido.Connect.Catalog.Fingerprint do
  @moduledoc """
  Versioned fingerprints for reviewed connector contracts.

  The reviewed-descriptor and remote-input scopes have different meanings.
  Callers must only compare values from the same scope.
  """

  @domain "jido_connect.catalog.fingerprint.v1"
  @reviewed_descriptor_scope "reviewed_descriptor"
  @remote_input_scope "remote_input"

  @type scope :: :reviewed_descriptor | :remote_input

  @spec reviewed_descriptor(term()) :: String.t()
  def reviewed_descriptor(value), do: fingerprint(:reviewed_descriptor, value)

  @spec remote_input(term()) :: String.t()
  def remote_input(value), do: fingerprint(:remote_input, value)

  @spec fingerprint(scope(), term()) :: String.t()
  def fingerprint(scope, value) when scope in [:reviewed_descriptor, :remote_input] do
    scope_name = scope_name(scope)

    digest =
      %{
        "domain" => @domain,
        "scope" => scope_name,
        "value" => value
      }
      |> canonical_json()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    "#{@domain}:#{scope_name}:#{digest}"
  end

  @doc false
  @spec canonical_json(term()) :: String.t()
  def canonical_json(%_module{} = value), do: value |> Map.from_struct() |> canonical_json()

  def canonical_json(map) when is_map(map) do
    entries =
      map
      |> Enum.map(fn {key, value} -> {map_key(key), value} end)
      |> Enum.sort_by(&elem(&1, 0))

    reject_duplicate_keys!(entries)

    "{" <> Enum.map_join(entries, ",", &encode_entry/1) <> "}"
  end

  def canonical_json(list) when is_list(list) do
    "[" <> Enum.map_join(list, ",", &canonical_json/1) <> "]"
  end

  def canonical_json(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> canonical_json()

  def canonical_json(value) when is_atom(value) and value not in [true, false, nil],
    do: Jason.encode!(Atom.to_string(value))

  def canonical_json(value), do: Jason.encode!(value)

  defp encode_entry({key, value}), do: Jason.encode!(key) <> ":" <> canonical_json(value)

  defp reject_duplicate_keys!(entries) do
    if entries |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() != length(entries) do
      raise ArgumentError, "canonical JSON cannot encode duplicate normalized map keys"
    end
  end

  defp map_key(key) when is_binary(key), do: key
  defp map_key(key) when is_atom(key), do: Atom.to_string(key)
  defp map_key(key), do: to_string(key)

  defp scope_name(:reviewed_descriptor), do: @reviewed_descriptor_scope
  defp scope_name(:remote_input), do: @remote_input_scope
end
