defmodule Jido.Connect.GitHub.Handlers.Actions.GetGitTree do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime) do
      client.get_tree(
        Map.fetch!(input, :repo),
        Map.fetch!(input, :sha),
        Map.get(input, :recursive, false),
        token
      )
    end
  end
end
