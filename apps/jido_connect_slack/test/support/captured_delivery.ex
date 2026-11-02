defmodule Jido.Connect.Slack.TestSupport.CapturedDelivery do
  @moduledoc false

  # Sanitized Events API deliveries from the Slack test workspace, written to
  # test/fixtures/slack/captured by the message ingress live smoke test with
  # JIDO_CONNECT_RECORD=1. They are signed with `LiveSmoke.replay_secret/0`.

  alias Jido.Connect.Slack.Webhook
  alias Jido.Connect.TestSupport.LiveSmoke

  @dir Path.expand("../fixtures/slack/captured", __DIR__)

  def path(name), do: Path.join(@dir, "#{name}.json")

  def capture!(name), do: name |> path() |> File.read!() |> Jason.decode!()

  def payload!(name), do: name |> capture!() |> Map.fetch!("body") |> Jason.decode!()

  @doc """
  Passes a capture, given by name or as a map, through
  `Jido.Connect.Slack.Webhook.verify_delivery/4` at its captured time; see
  `LiveSmoke.replay/2` for `opts`.
  """
  def replay(capture, opts \\ [])

  def replay(name, opts) when is_binary(name), do: name |> capture!() |> replay(opts)

  def replay(capture, opts) when is_map(capture),
    do: LiveSmoke.replay(capture, Keyword.put(opts, :webhook, Webhook))

  @doc """
  Returns the capture `name` with the payload that `change` makes of its
  payload, signed again with `LiveSmoke.replay_secret/0` at the captured
  timestamp, for a variant of a captured delivery that a test names as
  derived.
  """
  def derive(name, change) when is_function(change, 1) do
    capture = capture!(name)
    body = name |> payload!() |> change.() |> Jason.encode!()
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
end
