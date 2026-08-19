defmodule Jido.Connect.Bitbucket.Client.PullRequests do
  @moduledoc "Bitbucket pull-request API boundary."

  alias Jido.Connect.Bitbucket.Client.{Normalizer, Request, Transport}
  alias Jido.Connect.Bitbucket.Input.PullRequests, as: PullRequestInput

  @doc "Lists pull requests in one repository."
  def list(workspace, repository, %Request{} = request, opts \\ []) when is_list(opts) do
    input = %{
      workspace: workspace,
      repository: repository,
      state: Keyword.get(opts, :state, "open"),
      limit: Keyword.get(opts, :limit, 20),
      page: Keyword.get(opts, :page, 1)
    }

    with {:ok, input} <- PullRequestInput.validate(input) do
      request
      |> Transport.request()
      |> Req.get(
        url:
          Request.url(
            request,
            "/repositories/#{input.workspace}/#{input.repository}/pullrequests"
          ),
        params: %{
          state: String.upcase(input.state),
          pagelen: input.limit,
          page: input.page
        }
      )
      |> handle_response(request, input)
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}, request, input)
       when status in 200..299 and is_map(body) do
    context = %{
      account: Request.account(request),
      workspace: input.workspace,
      repository: input.repository,
      state: input.state,
      limit: input.limit,
      page: input.page
    }

    case Normalizer.normalize_list(body, context) do
      {:ok, result} ->
        {:ok, result}

      :error ->
        Transport.invalid_success_response(
          "Bitbucket pull-request list response was invalid",
          body
        )
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}, _request, _input)
       when status in 200..299 do
    Transport.invalid_success_response("Bitbucket pull-request list response was invalid", body)
  end

  defp handle_response(response, _request, _input), do: Transport.handle_error_response(response)
end
