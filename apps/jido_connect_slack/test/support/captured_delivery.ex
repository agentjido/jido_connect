defmodule Jido.Connect.Slack.TestSupport.CapturedDelivery do
  @moduledoc false

  # Sanitized deliveries from the Slack test workspace, written to
  # test/fixtures/slack/captured by the live smoke tests with
  # JIDO_CONNECT_RECORD=1. They are signed with `LiveSmoke.replay_secret/0`.
  # Events API deliveries carry a JSON body; interactivity deliveries carry a
  # form body whose `payload` field holds the JSON.

  alias Jido.Connect.Slack.{Interactivity, Webhook}
  alias Jido.Connect.TestSupport.LiveSmoke

  @dir Path.expand("../fixtures/slack/captured", __DIR__)

  def path(name), do: Path.join(@dir, "#{name}.json")

  def capture!(name), do: name |> path() |> File.read!() |> Jason.decode!()

  def payload!(name), do: name |> capture!() |> decode_payload()

  @doc """
  Passes a capture, given by name or as a map, through the package's
  `verify_delivery/4` at its captured time: `Jido.Connect.Slack.Webhook` for
  an Events API delivery, `Jido.Connect.Slack.Interactivity` for a form
  body. See `LiveSmoke.replay/2` for `opts`.
  """
  def replay(capture, opts \\ [])

  def replay(name, opts) when is_binary(name), do: name |> capture!() |> replay(opts)

  def replay(capture, opts) when is_map(capture),
    do: LiveSmoke.replay(capture, Keyword.put(opts, :webhook, verifier(capture)))

  @doc """
  Returns the capture `name` with the payload that `change` makes of its
  payload, encoded like the captured body and signed again with
  `LiveSmoke.replay_secret/0` at the captured timestamp, for a variant of a
  captured delivery that a test names as derived.
  """
  def derive(name, change) when is_function(change, 1) do
    capture = capture!(name)
    body = capture |> decode_payload() |> change.() |> Jason.encode!() |> encode_body(capture)
    timestamp = capture["headers"]["x-slack-request-timestamp"]
    base = "v0:#{timestamp}:#{body}"

    hmac =
      :hmac
      |> :crypto.mac(:sha256, LiveSmoke.replay_secret(), base)
      |> Base.encode16(case: :lower)

    headers =
      Map.merge(capture["headers"], %{
        "content-length" => Integer.to_string(byte_size(body)),
        "x-slack-signature" => "v0=" <> hmac
      })

    %{capture | "body" => body, "headers" => headers}
  end

  defp decode_payload(%{"body" => body} = capture) do
    if form?(capture),
      do: body |> URI.decode_query() |> Map.fetch!("payload") |> Jason.decode!(),
      else: Jason.decode!(body)
  end

  defp encode_body(json, capture) do
    if form?(capture), do: "payload=" <> URI.encode_www_form(json), else: json
  end

  defp verifier(capture), do: if(form?(capture), do: Interactivity, else: Webhook)

  defp form?(%{"headers" => headers}),
    do: String.starts_with?(headers["content-type"] || "", "application/x-www-form-urlencoded")
end
