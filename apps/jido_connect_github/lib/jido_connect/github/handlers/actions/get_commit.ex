defmodule Jido.Connect.GitHub.Handlers.Actions.GetCommit do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime),
         {:ok, commit} <-
           client.get_commit(Map.fetch!(input, :repo), Map.fetch!(input, :ref), token) do
      {:ok, %{commit: commit}}
    end
  end
end
