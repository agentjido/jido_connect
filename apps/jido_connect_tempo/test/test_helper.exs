ExUnit.start(exclude: [:live_smoke])

unless Code.ensure_loaded?(Jido.Connect.TestSupport.LiveSmoke) do
  Code.require_file("../../jido_connect/test/support/live_smoke.ex", __DIR__)
end

defmodule Jido.Connect.Tempo.Fixture do
  @moduledoc false

  # Replays the live recordings under test/fixtures/tempo/recorded, made with
  # LiveSmoke.record/4.

  @root Path.join([__DIR__, "fixtures", "tempo", "recorded"])

  def recorded!(name) do
    [@root, name <> ".json"] |> Path.join() |> File.read!() |> Jason.decode!()
  end

  @doc """
  Sends a recorded response with its status, content type and body.

  `:status` and `:headers` replace the recorded status or add headers, for
  responses that cannot be triggered safely, such as 429 and 5xx. `:body` is
  a function that changes the recorded body, for malformed or hostile pages
  and for token fields the recorder redacted.
  """
  def respond(conn, name, opts \\ []) do
    fixture = recorded!(name)
    headers = content_type(fixture) ++ Keyword.get(opts, :headers, [])
    status = Keyword.get(opts, :status, fixture["status"])
    body = Keyword.get(opts, :body, & &1).(fixture["body"])

    headers
    |> Enum.reduce(conn, fn {key, value}, conn -> Plug.Conn.put_resp_header(conn, key, value) end)
    |> Plug.Conn.send_resp(status, body(body))
  end

  defp content_type(%{"headers" => %{"content-type" => [value | _rest]}}),
    do: [{"content-type", value}]

  defp content_type(_fixture), do: []

  defp body(body) when is_binary(body), do: body
  defp body(nil), do: ""
  defp body(body), do: Jason.encode!(body)
end

defmodule Jido.Connect.Tempo.LateStepAdapter do
  @moduledoc false

  # A Req adapter shaped like the live smoke recorder: when it runs, it
  # appends a response step behind every step attached when the request was
  # built, and that step sends the body it sees to the calling process as
  # `{:late_step_body, body}`. Instead of calling Tempo it answers with a JSON
  # response under the recorded content type: the recorded code exchange for
  # the token endpoint, the recorded periods for any other path.

  alias Jido.Connect.Tempo.Fixture

  def run(request) do
    request = Req.Request.append_response_steps(request, late_step: &report_body/1)
    {request, response(request.url.path)}
  end

  defp report_body({request, response}) do
    send(self(), {:late_step_body, response.body})
    {request, response}
  end

  defp response("/oauth/token/"), do: json(Fixture.recorded!("oauth_exchange")["body"])
  defp response(_path), do: json(Fixture.recorded!("periods")["body"])

  defp json(body) do
    Req.Response.new(
      status: 200,
      headers: [{"content-type", "application/json"}],
      body: Jason.encode!(body)
    )
  end
end

# Ensure Req.Test.Ownership is running so that client tests can run without the
# full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
