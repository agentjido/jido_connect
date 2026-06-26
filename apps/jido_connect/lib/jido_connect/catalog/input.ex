defmodule Jido.Connect.Catalog.Input do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @runtime_keys [
    :modules,
    :ranker,
    :packs,
    :context,
    :credential_lease,
    :connection,
    :connection_id,
    :connection_resolver,
    :connection_selector,
    :policy,
    :policy_context
  ]

  @filter_keys [
    :provider,
    :type,
    :resource,
    :verb,
    :data_classification,
    :risk,
    :confirmation,
    :auth_kind,
    :auth_profile,
    :scope,
    :tool
  ]

  @doc false
  def search_params(params, action_context) do
    with {:ok, params} <- require_map(params, :search_params),
         {:ok, opts} <- catalog_opts(params, action_context),
         {:ok, limit} <- limit(Data.get(params, :limit)) do
      {:ok, Data.get(params, :query, ""), opts, limit}
    end
  end

  @doc false
  def describe_params(params, action_context) do
    with {:ok, params} <- require_map(params, :describe_params),
         {:ok, tool_ref} <- tool_ref(params),
         {:ok, opts} <- catalog_opts(params, action_context) do
      {:ok, tool_ref, opts}
    end
  end

  @doc false
  def call_params(params, action_context) do
    with {:ok, params} <- require_map(params, :call_params),
         {:ok, tool_ref} <- tool_ref(params),
         {:ok, input} <- call_input(params),
         {:ok, opts} <- catalog_opts(params, action_context) do
      {:ok, tool_ref, input, opts}
    end
  end

  defp catalog_opts(params, action_context) do
    with {:ok, filters} <- filters(Data.get(params, :filters, %{})) do
      opts =
        action_context
        |> plugin_config()
        |> normalize_opts()
        |> Keyword.merge(context_opts(action_context))
        |> Keyword.merge(direct_filter_opts(params))
        |> Keyword.merge(filters)
        |> maybe_put(:pack, Data.get(params, :pack))

      {:ok, opts}
    end
  end

  defp plugin_config(action_context) do
    Data.get(action_context, :config) ||
      Data.get(action_context, :catalog_config) ||
      Data.get(action_context, :jido_connect_catalog) ||
      case Data.get(action_context, :plugin_spec) do
        %{config: config} -> config
        _other -> %{}
      end
  end

  defp context_opts(action_context) when is_map(action_context) do
    action_context
    |> normalize_opts()
    |> Keyword.take(@runtime_keys)
  end

  defp context_opts(_action_context), do: []

  defp direct_filter_opts(params) do
    params
    |> normalize_opts()
    |> Keyword.take(@filter_keys ++ [:modules, :ranker, :packs])
  end

  defp filters(filters) when filters in [nil, ""], do: {:ok, []}

  defp filters(filters) when is_map(filters) or is_list(filters) do
    {:ok, Enum.map(filters, fn {key, value} -> {normalize_filter_key(key), value} end)}
  end

  defp filters(filters) do
    {:error,
     Error.validation("Invalid catalog filters",
       reason: :invalid_filters,
       subject: filters
     )}
  end

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

  defp tool_ref(params) do
    provider = Data.get(params, :provider)
    tool_id = Data.get(params, :tool_id) || Data.get(params, :id)

    cond do
      blank?(tool_id) ->
        {:error,
         Error.validation("Catalog tool id is required",
           reason: :invalid_tool_ref,
           subject: params
         )}

      blank?(provider) ->
        {:ok, tool_id}

      true ->
        {:ok, {provider, tool_id}}
    end
  end

  defp call_input(params) do
    case Data.get(params, :input, %{}) do
      input when is_map(input) ->
        {:ok, Data.atomize_existing_keys(input)}

      input ->
        {:error,
         Error.validation("Invalid catalog tool invocation",
           reason: :invalid_tool_invocation,
           details: %{input_type: type_name(input)}
         )}
    end
  end

  defp limit(nil), do: {:ok, nil}
  defp limit(""), do: {:ok, nil}
  defp limit(limit) when is_integer(limit) and limit >= 0, do: {:ok, limit}

  defp limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {value, ""} when value >= 0 -> {:ok, value}
      _other -> invalid_limit(limit)
    end
  end

  defp limit(limit), do: invalid_limit(limit)

  defp invalid_limit(limit) do
    {:error,
     Error.validation("Invalid catalog search limit",
       reason: :invalid_limit,
       subject: limit
     )}
  end

  defp require_map(params, _subject) when is_map(params), do: {:ok, params}

  defp require_map(params, subject) do
    {:error,
     Error.validation("Catalog action params must be a map",
       reason: :invalid_catalog_action_params,
       subject: subject,
       details: %{params_type: type_name(params)}
     )}
  end

  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(_opts), do: []

  defp maybe_put(opts, _key, value) when value in [nil, ""], do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp type_name(value) when is_list(value), do: :list
  defp type_name(value) when is_binary(value), do: :string
  defp type_name(value) when is_atom(value), do: :atom
  defp type_name(value) when is_integer(value), do: :integer
  defp type_name(value) when is_float(value), do: :float
  defp type_name(_value), do: :unknown
end
