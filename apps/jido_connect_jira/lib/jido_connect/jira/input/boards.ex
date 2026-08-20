defmodule Jido.Connect.Jira.Input.Boards do
  @moduledoc false

  alias Jido.Connect.Error

  def create(input) do
    location = Map.get(input, :location, "user")
    project = Map.get(input, :project)

    cond do
      location == "project" and not non_blank?(project) ->
        invalid(:project, "project is required for a project board location")

      location == "user" and not is_nil(project) ->
        invalid(:project, "project is valid only for a project board location")

      true ->
        {:ok, Map.put(input, :location, location)}
    end
  end

  defp non_blank?(value), do: is_binary(value) and String.trim(value) != ""

  defp invalid(field, message) do
    {:error,
     Error.validation("Invalid Jira input",
       reason: :invalid_jira_input,
       subject: field,
       details: %{field: field, message: message}
     )}
  end
end
