defmodule Jido.Connect.GitHub.Handlers.Actions.GetGitBlob do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime) do
      client.get_blob(Map.fetch!(input, :repo), Map.fetch!(input, :sha), token)
    end
  end
end
