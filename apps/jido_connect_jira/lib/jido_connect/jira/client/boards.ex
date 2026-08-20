defmodule Jido.Connect.Jira.Client.Boards do
  @moduledoc "Jira Software board REST operations."

  alias Jido.Connect.Jira.Client.{Normalizer.Board, Request, Transport}

  def list(%Request{} = request, opts \\ []) do
    params =
      %{
        startAt: Keyword.get(opts, :offset, 0),
        maxResults: Keyword.get(opts, :limit, 50)
      }
      |> maybe_put(:name, Keyword.get(opts, :name))
      |> maybe_put(:projectKeyOrId, Keyword.get(opts, :project))
      |> maybe_put(:type, Keyword.get(opts, :type))

    response =
      request
      |> Transport.request(req_options: [retry: false])
      |> Req.get(url: Request.url(request, "/rest/agile/1.0/board"), params: params)

    normalize(response, &Board.list(&1, opts), "Jira board list response was invalid")
  end

  def get(id, %Request{} = request) when is_integer(id) do
    response =
      request
      |> Transport.request(req_options: [retry: false])
      |> Req.get(url: Request.url(request, "/rest/agile/1.0/board/#{id}"))

    normalize(response, &Board.one/1, "Jira board response was invalid")
  end

  def create(attrs, %Request{} = request) when is_map(attrs) do
    location =
      %{type: Map.fetch!(attrs, :location)}
      |> maybe_put(:projectKeyOrId, Map.get(attrs, :project))

    body = %{
      name: Map.fetch!(attrs, :name),
      type: Map.fetch!(attrs, :type),
      filterId: Map.fetch!(attrs, :filter_id),
      location: location
    }

    response =
      request
      |> Transport.request(req_options: [retry: false])
      |> Req.post(url: Request.url(request, "/rest/agile/1.0/board"), json: body)

    normalize(response, &Board.one/1, "Jira board create response was invalid", mutation?: true)
  end

  defp normalize({:ok, %{status: status, body: body}}, fun, message, opts)
       when status in 200..299 do
    case fun.(body) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> Transport.invalid_success_response(message, body, opts)
    end
  end

  defp normalize(response, _fun, message, opts),
    do: Transport.handle_error_response(response, Keyword.put(opts, :message, message))

  defp normalize(response, fun, message), do: normalize(response, fun, message, [])

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
