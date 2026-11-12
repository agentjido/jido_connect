defmodule Jido.Connect.Gmail.Handlers.Actions.GetAttachmentContent do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  # The part ID is passed as given: Gmail's root part has the ID "".
  def run(input, %{credentials: credentials}) do
    with {:ok, %{message_id: message_id}} <- Mutation.normalize_required_id(input, :message_id),
         {:ok, part_id} <- part_id(input),
         {:ok, client} <- Mutation.fetch_client(credentials),
         {:ok, attachment} <-
           client.get_attachment_content(
             %{message_id: message_id, part_id: part_id},
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{attachment: Mutation.public_map(attachment)}}
    end
  end

  defp part_id(input) do
    case Data.get(input, :part_id) do
      part_id when is_binary(part_id) ->
        {:ok, part_id}

      _invalid ->
        {:error,
         Error.validation("Gmail part_id must be a string",
           reason: :invalid_gmail_id,
           details: %{field: :part_id, expected: "string"}
         )}
    end
  end
end
