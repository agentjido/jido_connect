defmodule Jido.Connect.TestSupport.LiveSmoke.Recorder do
  @moduledoc false

  # Req adapter that `LiveSmoke.record/4` installs through a package's Req
  # options. It runs the Finch adapter and appends a response step that writes
  # each final response, sanitized, as a fixture file.

  use Agent

  alias Jido.Connect.TestSupport.LiveSmoke.Sanitize

  @step :live_smoke_record

  def start_link(session), do: Agent.start_link(fn -> session end, name: __MODULE__)

  def switch(session), do: Agent.update(__MODULE__, fn _previous -> session end)

  def run(%Req.Request{} = request) do
    request
    |> attach_step()
    |> Req.Finch.run()
  end

  defp attach_step(request) do
    if Keyword.has_key?(request.response_steps, @step) do
      request
    else
      Req.Request.append_response_steps(request, [{@step, &write_response/1}])
    end
  end

  defp write_response({request, response}) do
    session = Agent.get(__MODULE__, & &1)

    case transform(session, request, response.body) do
      :skip -> :ok
      body -> write_fixture(session, request, %{response | body: body}, body !== response.body)
    end

    {request, response}
  end

  defp write_fixture(session, request, response, transformed?) do
    count = session.count + 1
    {fixture, sanitizer} = fixture(request, response, session.sanitizer)
    fixture = if transformed?, do: Map.put(fixture, "transformed", true), else: fixture
    Sanitize.check_leaks!(fixture, sanitizer)

    path = Path.join(session.dir, file_name(session.name, count))
    File.mkdir_p!(session.dir)
    File.write!(path, [Jason.encode_to_iodata!(fixture, pretty: true), "\n"])

    Agent.update(__MODULE__, &%{&1 | count: count, sanitizer: sanitizer})
  end

  # The transform sees the decoded path and the body before sanitizing; the
  # caller keeps the original response. A fixture whose body it changed gets
  # "transformed": true, since its headers still describe the original.
  defp transform(%{transform: transform}, request, body) when is_function(transform, 2),
    do: transform.(URI.decode(request.url.path || "/"), body)

  defp transform(_session, _request, body), do: body

  # The fixture holds the decoded path, so `%40` addresses are found; the
  # sanitizer decides the order in which its parts are read.
  defp fixture(request, response, sanitizer) do
    response.body
    |> body()
    |> Map.merge(%{
      "recorded_at" => Date.to_iso8601(Date.utc_today()),
      "request" => %{
        "method" => request.method |> to_string() |> String.upcase(),
        "path" => URI.decode(request.url.path || "/")
      },
      "status" => response.status,
      "headers" => response.headers
    })
    |> Sanitize.fixture(sanitizer)
  end

  defp body(body) when is_map(body) or is_list(body), do: %{"body" => body}

  defp body(body) when is_binary(body) do
    if String.valid?(body) do
      %{"body" => body}
    else
      digest = :sha256 |> :crypto.hash(body) |> Base.encode16(case: :lower)
      %{"body" => nil, "body_bytes" => byte_size(body), "body_sha256" => digest}
    end
  end

  defp body(_body), do: %{"body" => nil}

  defp file_name(name, 1), do: "#{name}.json"
  defp file_name(name, count), do: "#{name}.#{count}.json"
end
