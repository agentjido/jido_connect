defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.DeltaListItems do
  @moduledoc false

  alias Jido.Connect.MicrosoftSharepoint.Client.ListItemDelta

  def run(input, %{credentials: %{access_token: token}}) when is_binary(token),
    do: ListItemDelta.read(token, input)

  def run(_input, _context), do: {:error, :missing_access_token}
end
