defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.SearchSites do
  @moduledoc false

  alias Jido.Connect.MicrosoftSharepoint.Client.Sites

  def run(input, %{credentials: %{access_token: token}}) when is_binary(token),
    do: Sites.search(token, input)

  def run(_input, _context), do: {:error, :missing_access_token}
end
