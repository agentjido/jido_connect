defmodule Jido.Connect.Intercom.Handlers.Actions.UntagContact do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, tag_id} <- validate_tag_id(Map.get(input, :tag_id)),
         {:ok, contact_ids} <- validate_contact_ids(Map.get(input, :contact_ids)),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, tag} <- client.untag_contact(tag_id, contact_ids, token, []) do
      {:ok, tag}
    end
  end

  defp validate_tag_id(tag_id) when is_binary(tag_id) and byte_size(tag_id) > 0, do: {:ok, tag_id}

  defp validate_tag_id(_tag_id) do
    {:error,
     Error.validation("Tag ID is required",
       reason: :invalid_tag_id,
       subject: :tag_id
     )}
  end

  defp validate_contact_ids([_ | _] = ids), do: {:ok, ids}

  defp validate_contact_ids(_ids) do
    {:error,
     Error.validation("At least one contact_id is required",
       reason: :invalid_contact_ids,
       subject: :contact_ids
     )}
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
