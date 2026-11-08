defmodule Jido.Connect.GitHub.Handlers.Actions.ListPullRequestReviews do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime) do
      client.list_pull_request_reviews(
        %{
          repo: Map.fetch!(input, :repo),
          pull_number: Map.fetch!(input, :pull_number),
          page: Map.get(input, :page, 1),
          per_page: Map.get(input, :per_page, 100)
        },
        token
      )
    end
  end
end
