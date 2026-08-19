defmodule Jido.Connect.Bitbucket.Handlers.Actions.ListPullRequests do
  @moduledoc false

  alias Jido.Connect.Bitbucket.{Client, Input.PullRequests}

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, input} <- PullRequests.validate(input),
         {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <-
           client.list_pull_requests(input.workspace, input.repository, request,
             state: input.state,
             limit: input.limit,
             page: input.page
           ) do
      {:ok, result}
    end
  end
end
