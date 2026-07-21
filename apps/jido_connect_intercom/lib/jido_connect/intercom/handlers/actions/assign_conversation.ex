defmodule Jido.Connect.Intercom.Handlers.Actions.AssignConversation do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, conversation_id} <-
           validate_conversation_id(Map.get(input, :conversation_id)),
         :ok <- validate_assignee(input),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         attrs <- build_assignment_attrs(input),
         {:ok, part} <-
           client.assign_conversation(conversation_id, attrs, token, []) do
      {:ok, part}
    end
  end

  defp validate_conversation_id(id) when is_binary(id) and byte_size(id) > 0, do: {:ok, id}

  defp validate_conversation_id(_id) do
    {:error,
     Error.validation("Intercom conversation_id is required",
       reason: :invalid_conversation_id,
       subject: :conversation_id
     )}
  end

  defp validate_assignee(input) do
    has_admin = is_binary(Map.get(input, :admin_id)) and byte_size(Map.get(input, :admin_id)) > 0
    has_team = is_binary(Map.get(input, :team_id)) and byte_size(Map.get(input, :team_id)) > 0

    if has_admin or has_team do
      :ok
    else
      {:error,
       Error.validation("Either admin_id or team_id is required for assignment",
         reason: :invalid_assignee,
         subject: :assign_conversation
       )}
    end
  end

  defp build_assignment_attrs(input) do
    attrs = %{admin_id: Map.get(input, :admin_id)}

    attrs =
      case Map.get(input, :team_id) do
        nil -> attrs
        team_id -> Map.put(attrs, :assignee_id, %{type: "team", id: team_id})
      end

    attrs =
      case Map.get(input, :body) do
        nil -> attrs
        body -> Map.put(attrs, :body, body)
      end

    attrs
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
