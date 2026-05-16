defmodule Jido.Connect.Calendly.Handlers.Actions.GetInvitee do
  @moduledoc false

  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, invitee} <- client.get_invitee(input, token) do
      {:ok, %{invitee: ResourceHelpers.public_map(invitee)}}
    end
  end
end
