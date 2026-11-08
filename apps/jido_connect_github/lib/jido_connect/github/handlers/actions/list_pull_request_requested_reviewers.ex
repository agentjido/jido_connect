defmodule Jido.Connect.GitHub.Handlers.Actions.ListPullRequestRequestedReviewers do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime) do
      client.list_pull_request_requested_reviewers(
        Map.fetch!(input, :repo),
        Map.fetch!(input, :pull_number),
        token
      )
    end
  end
end
