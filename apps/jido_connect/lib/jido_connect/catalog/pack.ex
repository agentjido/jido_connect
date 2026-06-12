defmodule Jido.Connect.Catalog.Pack do
  @moduledoc """
  Storage-free curated catalog view.

  Packs are data/configuration only. Hosts can keep them in app config,
  database rows, feature flags, or any other storage layer and pass them into
  catalog calls when they want to expose a restricted subset of tools.
  """

  alias Jido.Connect.{Data, Error, Sanitizer}
  alias Jido.Connect.Catalog.{ToolEntry, ToolLookup}

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.any(description: "Stable pack id"),
              label:
                Zoi.string(description: "Human-facing pack label")
                |> Zoi.nullish()
                |> Zoi.optional(),
              description:
                Zoi.string(description: "Human-facing pack description")
                |> Zoi.nullish()
                |> Zoi.optional(),
              filters: Zoi.map(description: "Restrictive catalog filters") |> Zoi.default(%{}),
              allowed_tools:
                Zoi.list(Zoi.any(), description: "Optional allow-list of tool refs")
                |> Zoi.default([]),
              metadata: Zoi.map(description: "Host-owned metadata") |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for a catalog pack."
  def schema, do: @schema

  @doc "Builds a catalog pack or returns a validation error."
  def new(attrs), do: Zoi.parse(@schema, attrs)

  @doc "Builds a catalog pack or raises on invalid data."
  def new!(attrs), do: Zoi.parse!(@schema, attrs)

  @doc false
  def resolve(nil, _opts), do: {:ok, nil}
  def resolve("", _opts), do: {:ok, nil}
  def resolve(%__MODULE__{} = pack, _opts), do: {:ok, normalize_pack(pack)}

  def resolve(%{} = attrs, _opts) do
    attrs
    |> maybe_put_default_id()
    |> new()
    |> case do
      {:ok, pack} -> {:ok, normalize_pack(pack)}
      {:error, errors} -> invalid_pack(attrs, errors)
    end
  end

  def resolve(pack_ref, opts) do
    packs = opts |> Keyword.get(:packs, []) |> normalize_packs()

    case packs do
      {:ok, packs} ->
        pack_key = key(pack_ref)

        case Enum.find(packs, &(key(&1.id) == pack_key)) do
          nil ->
            {:error,
             Error.validation("Unknown catalog pack",
               reason: :unknown_pack,
               subject: pack_ref
             )}

          pack ->
            {:ok, pack}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc false
  def apply_filters(opts, nil), do: opts

  def apply_filters(opts, %__MODULE__{} = pack) do
    opts
    |> Keyword.drop([:pack, :packs])
    |> Keyword.merge(normalize_filter_opts(pack.filters))
  end

  @doc false
  def filter_tools(tools, nil), do: tools

  def filter_tools(tools, %__MODULE__{} = pack) do
    Enum.filter(tools, &tool_allowed?(pack, &1))
  end

  @doc false
  def filter_search_results(results, nil), do: results

  def filter_search_results(results, %__MODULE__{} = pack) do
    Enum.filter(results, &tool_allowed?(pack, &1.tool))
  end

  @doc false
  def require_tool_allowed(nil, %ToolEntry{}), do: :ok

  def require_tool_allowed(%__MODULE__{} = pack, %ToolEntry{} = tool) do
    if tool_allowed?(pack, tool) do
      :ok
    else
      {:error,
       Error.validation("Catalog tool is not allowed by pack",
         reason: :tool_not_in_pack,
         subject: tool.id,
         details: %{provider: tool.provider, pack: pack.id}
       )}
    end
  end

  defp normalize_packs(%{} = packs) do
    packs
    |> Enum.map(fn {id, attrs} -> normalize_pack_attrs(attrs, id) end)
    |> normalize_pack_list()
  end

  defp normalize_packs(packs) when is_list(packs), do: normalize_pack_list(packs)

  defp normalize_packs(other) do
    {:error,
     Error.validation("Invalid catalog packs",
       reason: :invalid_packs,
       details: %{returned: inspect(other)}
     )}
  end

  defp normalize_pack_list(packs) do
    packs
    |> Enum.reduce_while({:ok, []}, fn attrs, {:ok, acc} ->
      case normalize_one_pack(attrs) do
        {:ok, pack} -> {:cont, {:ok, [pack | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, packs} -> {:ok, Enum.reverse(packs)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_one_pack(%__MODULE__{} = pack), do: {:ok, normalize_pack(pack)}

  defp normalize_one_pack(%{} = attrs) do
    attrs
    |> maybe_put_default_id()
    |> new()
    |> case do
      {:ok, pack} -> {:ok, normalize_pack(pack)}
      {:error, errors} -> invalid_pack(attrs, errors)
    end
  end

  defp normalize_one_pack(other), do: invalid_pack(other, :invalid_pack)

  defp normalize_pack_attrs(%__MODULE__{} = pack, _id), do: pack
  defp normalize_pack_attrs(%{} = attrs, id), do: Map.put_new(attrs, :id, id)
  defp normalize_pack_attrs(attrs, id), do: %{id: id, allowed_tools: List.wrap(attrs)}

  defp maybe_put_default_id(%{} = attrs) do
    cond do
      Data.get(attrs, :id) -> attrs
      Data.get(attrs, "id") -> attrs
      true -> attrs
    end
  end

  defp normalize_pack(%__MODULE__{} = pack) do
    %{
      pack
      | id: key(pack.id),
        filters: Map.new(pack.filters || %{}),
        allowed_tools: Enum.map(pack.allowed_tools || [], &allowed_tool_ref/1),
        metadata: Map.new(pack.metadata || %{})
    }
  end

  defp tool_allowed?(%__MODULE__{allowed_tools: []}, %ToolEntry{}), do: true

  defp tool_allowed?(%__MODULE__{} = pack, %ToolEntry{} = tool) do
    allowed = MapSet.new(pack.allowed_tools)

    MapSet.member?(allowed, ToolLookup.tool_id_key(tool.id)) or
      MapSet.member?(allowed, "#{ToolLookup.provider_key(tool.provider)}.#{tool.id}")
  end

  defp normalize_filter_opts(filters) when is_map(filters) or is_list(filters) do
    Enum.map(filters, fn {key, value} -> {normalize_filter_key(key), value} end)
  end

  defp normalize_filter_opts(_filters), do: []

  defp normalize_filter_key(key) when is_atom(key), do: key

  defp normalize_filter_key(key) when is_binary(key) do
    case key do
      "provider" -> :provider
      "type" -> :type
      "resource" -> :resource
      "verb" -> :verb
      "data_classification" -> :data_classification
      "risk" -> :risk
      "confirmation" -> :confirmation
      "auth_kind" -> :auth_kind
      "auth_profile" -> :auth_profile
      "scope" -> :scope
      "tool" -> :tool
      _other -> :unknown_filter
    end
  end

  defp allowed_tool_ref({provider, tool_id}),
    do: "#{ToolLookup.provider_key(provider)}.#{ToolLookup.tool_id_key(tool_id)}"

  defp allowed_tool_ref(%ToolEntry{} = tool),
    do: "#{ToolLookup.provider_key(tool.provider)}.#{tool.id}"

  defp allowed_tool_ref(ref), do: ToolLookup.tool_id_key(ref)

  defp key(value), do: value |> to_string() |> String.trim()

  defp invalid_pack(subject, errors) do
    {:error,
     Error.validation("Invalid catalog pack",
       reason: :invalid_pack,
       subject: subject,
       details: %{errors: Sanitizer.sanitize(errors, :transport)}
     )}
  end
end
