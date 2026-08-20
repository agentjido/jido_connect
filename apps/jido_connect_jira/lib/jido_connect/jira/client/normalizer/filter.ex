defmodule Jido.Connect.Jira.Client.Normalizer.Filter do
  @moduledoc false

  alias Jido.Connect.Jira.Client.Normalizer.{Collection, Value}

  def list(payload, defaults) when is_map(payload) do
    values = Value.get(payload, :values)

    with true <- is_list(values),
         {:ok, filters} <- Collection.normalize_all(values, &one/1),
         {:ok, offset} <- Value.non_negative(Value.get(payload, :startAt) || defaults[:offset]),
         {:ok, limit} <- Value.positive(Value.get(payload, :maxResults) || defaults[:limit]),
         {:ok, total} <- Value.optional_non_negative(Value.get(payload, :total)),
         {:ok, is_last} <- Value.optional_boolean(Value.get(payload, :isLast)) do
      {:ok, %{filters: filters, offset: offset, limit: limit, total: total, is_last: is_last}}
    else
      _other -> :error
    end
  end

  def list(_payload, _defaults), do: :error

  def one(payload) when is_map(payload) do
    with {:ok, id} <- Value.id(Value.get(payload, :id)),
         {:ok, name} <- Value.required_string(Value.get(payload, :name)),
         {:ok, query} <- Value.required_string(Value.get(payload, :jql)),
         {:ok, description} <- optional_description(Value.get(payload, :description)),
         {:ok, favorite} <- Value.boolean(Value.get(payload, :favourite)),
         {:ok, owner} <- owner(Value.get(payload, :owner)),
         {:ok, shares} <- shares(Value.get(payload, :sharePermissions)),
         {:ok, url} <- filter_url(payload, id) do
      {:ok,
       %{
         id: id,
         name: name,
         query: query,
         description: description,
         favorite: favorite,
         owner: owner,
         share_count: length(shares),
         url: url
       }}
    else
      _other -> :error
    end
  end

  def one(_payload), do: :error

  def columns(payload, filter_id) when is_list(payload) do
    with {:ok, id} <- Value.id(filter_id),
         {:ok, columns} <- Collection.normalize_all(payload, &column/1) do
      {:ok, %{filter_id: id, columns: columns}}
    else
      _other -> :error
    end
  end

  def columns(_payload, _filter_id), do: :error

  def permissions(payload, filter_id, scope) when is_list(payload) do
    with {:ok, id} <- Value.id(filter_id),
         {:ok, permissions} <- Collection.normalize_all(payload, &permission/1) do
      {:ok, %{filter_id: id, scope: scope, permissions: permissions, updated: true}}
    else
      _other -> :error
    end
  end

  def permissions(_payload, _filter_id, _scope), do: :error

  def permission_ids(payload) when is_list(payload) do
    Collection.normalize_all(payload, fn value ->
      case permission(value) do
        {:ok, %{id: id}} -> {:ok, id}
        :error -> :error
      end
    end)
  end

  def permission_ids(_payload), do: :error

  def project_id(payload) when is_map(payload), do: Value.id(Value.get(payload, :id))
  def project_id(_payload), do: :error

  defp optional_description(nil), do: {:ok, nil}
  defp optional_description(value) when is_binary(value), do: {:ok, value}
  defp optional_description(_value), do: :error

  defp owner(nil), do: {:ok, nil}

  defp owner(value) when is_map(value) do
    with {:ok, id} <- Value.required_string(Value.get(value, :accountId)),
         {:ok, display_name} <- Value.required_string(Value.get(value, :displayName)) do
      {:ok, %{id: id, display_name: display_name}}
    else
      _other -> :error
    end
  end

  defp owner(_value), do: :error

  defp shares(nil), do: {:ok, []}
  defp shares(value) when is_list(value), do: {:ok, value}
  defp shares(_value), do: :error

  defp filter_url(payload, id) do
    case Value.get(payload, :viewUrl) do
      nil ->
        with {:ok, self} <- Value.https_url(Value.get(payload, :self)) do
          uri = URI.parse(self)
          {:ok, URI.to_string(%URI{uri | path: "/issues/", query: "filter=#{id}", fragment: nil})}
        end

      value ->
        Value.https_url(value)
    end
  end

  defp column(value) when is_map(value) do
    with {:ok, label} <- Value.required_string(Value.get(value, :label)),
         {:ok, field_value} <- Value.required_string(Value.get(value, :value)) do
      {:ok, %{label: label, value: field_value}}
    else
      _other -> :error
    end
  end

  defp column(_value), do: :error

  defp permission(value) when is_map(value) do
    with {:ok, id} <- Value.id(Value.get(value, :id)),
         {:ok, type} <- Value.required_string(Value.get(value, :type)),
         {:ok, project} <- optional_project(Value.get(value, :project)),
         {:ok, group} <- optional_group(Value.get(value, :group)) do
      {:ok, %{id: id, type: type, project: project, group: group}}
    else
      _other -> :error
    end
  end

  defp permission(_value), do: :error

  defp optional_project(nil), do: {:ok, nil}

  defp optional_project(value) when is_map(value) do
    with {:ok, id} <- Value.id(Value.get(value, :id)),
         {:ok, key} <- Value.required_string(Value.get(value, :key)),
         {:ok, name} <- Value.required_string(Value.get(value, :name)) do
      {:ok, %{id: id, key: key, name: name}}
    else
      _other -> :error
    end
  end

  defp optional_project(_value), do: :error

  defp optional_group(nil), do: {:ok, nil}

  defp optional_group(value) when is_map(value) do
    with {:ok, id} <- Value.required_string(Value.get(value, :groupId)),
         {:ok, name} <- Value.required_string(Value.get(value, :name)) do
      {:ok, %{id: id, name: name}}
    else
      _other -> :error
    end
  end

  defp optional_group(_value), do: :error
end
