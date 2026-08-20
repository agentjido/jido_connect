defmodule Jido.Connect.Jira.Client.Normalizer.Board do
  @moduledoc false

  alias Jido.Connect.Jira.Client.Normalizer.{Collection, Value}

  @types ["scrum", "kanban", "simple"]

  def list(payload, defaults) when is_map(payload) do
    values = Value.get(payload, :values)

    with true <- is_list(values),
         {:ok, boards} <- Collection.normalize_all(values, &one/1),
         {:ok, offset} <- Value.non_negative(Value.get(payload, :startAt) || defaults[:offset]),
         {:ok, limit} <- Value.positive(Value.get(payload, :maxResults) || defaults[:limit]),
         {:ok, total} <- Value.optional_non_negative(Value.get(payload, :total)),
         {:ok, is_last} <- Value.optional_boolean(Value.get(payload, :isLast)) do
      {:ok, %{boards: boards, offset: offset, limit: limit, total: total, is_last: is_last}}
    else
      _other -> :error
    end
  end

  def list(_payload, _defaults), do: :error

  def one(payload) when is_map(payload) do
    with {:ok, id} <- Value.id(Value.get(payload, :id)),
         {:ok, name} <- Value.required_string(Value.get(payload, :name)),
         type when type in @types <- Value.get(payload, :type),
         {:ok, self} <- Value.https_url(Value.get(payload, :self)),
         {:ok, location} <- location(Value.get(payload, :location)) do
      uri = URI.parse(self)

      url =
        URI.to_string(%URI{
          uri
          | path: "/secure/RapidBoard.jspa",
            query: "rapidView=#{id}",
            fragment: nil
        })

      {:ok, %{id: id, name: name, type: type, location: location, url: url}}
    else
      _other -> :error
    end
  end

  def one(_payload), do: :error

  defp location(nil), do: {:ok, nil}

  defp location(value) when is_map(value) do
    case Value.get(value, :type) do
      "user" -> {:ok, %{type: "user", project: nil}}
      "project" -> project_location(value)
      nil -> inferred_location(value)
      _other -> :error
    end
  end

  defp location(_value), do: :error

  defp project_location(value) do
    project =
      Value.get(value, :projectKey) || Value.get(value, :projectName) || Value.get(value, :name)

    with {:ok, project} <- Value.required_string(project),
         do: {:ok, %{type: "project", project: project}}
  end

  defp inferred_location(value) do
    cond do
      project = Value.get(value, :projectKey) ->
        with {:ok, project} <- Value.required_string(project),
             do: {:ok, %{type: "project", project: project}}

      project = Value.get(value, :projectName) ->
        with {:ok, project} <- Value.required_string(project),
             do: {:ok, %{type: "project", project: project}}

      user = Value.get(value, :userAccountId) ->
        with {:ok, _user} <- Value.required_string(user), do: {:ok, %{type: "user", project: nil}}

      true ->
        :error
    end
  end
end
