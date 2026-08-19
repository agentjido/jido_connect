defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.CreateListItem do
  @moduledoc false

  alias Jido.Connect.MicrosoftSharepoint.Client.ListItems

  def run(input, %{credentials: %{access_token: token}}) when is_binary(token),
    do: ListItems.create(token, input)

  def run(_input, _context), do: {:error, :missing_access_token}
end
