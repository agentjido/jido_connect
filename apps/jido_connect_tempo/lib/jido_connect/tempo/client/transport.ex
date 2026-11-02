defmodule Jido.Connect.Tempo.Client.Transport do
  @moduledoc """
  Tempo REST v4 transport boundary.

  Both profiles send their leased token as a Bearer credential through
  `Jido.Connect.Provider.Transport.bearer_request/3`, with the connection's
  `api_origin` as base URL.

  The token never leaves that origin:

  - Every request built by `request/2` checks its final URL before it is
    sent. Scheme, host and port must equal the connection's origin;
    otherwise Req returns `{:error, %OriginError{}}`, which `get/3`
    normalizes to a `:request_error` with `details.reason: :foreign_origin`
    and `delivery: :not_sent`.
  - Redirects are not followed. A 3xx response becomes a
    `Jido.Connect.Error.ProviderError`, so a `Location` on another origin
    never receives the `authorization` header.
  - Req options from `:tempo_req_options` and `:req_options`, used for
    `Req.Test` and the live smoke recorder, cannot set `:base_url`, `:url`,
    `:auth`, `:redirect` or `:redirect_trusted`, nor the legacy
    `:follow_redirects` and `:location_trusted`, which Req 0.7 still reads
    before the current names.

  Automatic retries are off by default; a caller may enable them through
  `:req_options`. Failures carry `retry_after` for the host's own retry
  policy. JSON bodies are decoded by the step of
  `Response.attach_json_decoder/1`, not by Req, so a malformed error body
  keeps its status and a response step added by an adapter, such as the
  live smoke recorder's, sees the decoded body.
  """

  alias Jido.Connect.Provider.Transport
  alias Jido.Connect.Tempo.Client.{Request, Response}

  defmodule OriginError do
    @moduledoc "Returned by Req when a Tempo request targets another origin."
    defexception reason: :foreign_origin,
                 message: "Tempo requests must stay at the connection's API origin"
  end

  @locked_options [
    :base_url,
    :url,
    :auth,
    :redirect,
    :redirect_trusted,
    :follow_redirects,
    :location_trusted
  ]

  @doc "Builds the Bearer request for one Tempo connection."
  @spec request(Request.t(), keyword()) :: Req.Request.t()
  def request(%Request{} = request, opts \\ []) when is_list(opts) do
    req_options =
      [retry: false]
      |> Keyword.merge(Application.get_env(:jido_connect_tempo, :tempo_req_options, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))
      |> Keyword.drop(@locked_options)
      |> Keyword.put(:redirect, false)

    request.api_origin
    |> Transport.bearer_request(Request.token(request),
      headers: [{"accept", "application/json"}],
      req_options: req_options
    )
    |> Req.Request.append_request_steps(tempo_origin_guard: origin_guard(request.api_origin))
    |> Response.attach_json_decoder()
  end

  @doc """
  Sends a GET request for `path` and returns the decoded JSON body.

  `path` is relative to the connection's origin. Options: `:params` (query
  parameters) and `:req_options`.
  """
  @spec get(Request.t(), String.t(), keyword()) ::
          {:ok, map() | list()} | {:error, Jido.Connect.Error.ProviderError.t()}
  def get(%Request{} = request, path, opts \\ []) when is_binary(path) do
    request
    |> request(opts)
    |> Transport.request(:get, url: path, params: Keyword.get(opts, :params, []))
    |> handle()
  end

  # The origin guard halts before the adapter runs, so nothing was sent.
  defp handle({:error, %OriginError{}} = result), do: Response.handle(result, delivery: :not_sent)
  defp handle(result), do: Response.handle(result)

  defp origin_guard(api_origin) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(api_origin)

    fn %Req.Request{url: url} = req ->
      if {url.scheme, url.host, url.port} == {scheme, host, port} do
        req
      else
        Req.Request.halt(req, %OriginError{})
      end
    end
  end
end
