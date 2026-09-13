defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListLists do
  @moduledoc false

  alias Jido.Connect.MicrosoftSharepoint.Client.Lists

  def run(input, %{credentials: %{access_token: token}}) when is_binary(token),
    do: Lists.list(token, input)

  def run(_input, _context), do: {:error, :missing_access_token}
end
