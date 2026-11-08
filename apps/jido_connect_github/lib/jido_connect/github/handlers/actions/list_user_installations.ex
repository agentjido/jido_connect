defmodule Jido.Connect.GitHub.Handlers.Actions.ListUserInstallations do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime),
         {:ok, result} <- client.list_user_installations(page_params(input), token) do
      {:ok, result}
    end
  end

  defp page_params(input) do
    %{page: Map.get(input, :page, 1), per_page: Map.get(input, :per_page, 100)}
  end
end
