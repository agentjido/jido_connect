defmodule Jido.Connect.Intercom.Handlers.Actions.TagContact do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, name} <- validate_name(Map.get(input, :name)),
         {:ok, contact_ids} <- validate_contact_ids(Map.get(input, :contact_ids)),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, tag} <- client.tag_contact(name, contact_ids, token, []) do
      {:ok, tag}
    end
  end

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: {:ok, name}

  defp validate_name(_name) do
    {:error,
     Error.validation("Tag name is required",
       reason: :invalid_tag_name,
       subject: :name
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
