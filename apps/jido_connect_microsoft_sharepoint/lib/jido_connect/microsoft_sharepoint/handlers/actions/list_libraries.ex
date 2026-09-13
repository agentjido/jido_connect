defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListLibraries do
  @moduledoc false

  alias Jido.Connect.MicrosoftSharepoint.Client.DocumentLibraries

  def run(input, %{credentials: %{access_token: token}}) when is_binary(token),
    do: DocumentLibraries.list(token, input)

  def run(_input, _context), do: {:error, :missing_access_token}
end
