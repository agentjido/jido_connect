defmodule Jido.Connect.DemoWeb.CaptureTest do
  use Jido.Connect.DemoWeb.ConnCase, async: false

  alias Jido.Connect.Error.AuthError
  alias Jido.Connect.Slack.Webhook
  alias Jido.Connect.TestSupport.LiveSmoke

  @secret "capture-test-signing-secret"

  setup do
    dir = tmp_dir("capture")

    put_env("SLACK_CAPTURE_DIR", dir)
    put_env("JIRA_CAPTURE_DIR", dir)
    put_env("SLACK_SIGNING_SECRET", @secret)
    put_env("JIDO_CONNECT_DEMO_SECRET_DIR", tmp_dir("secrets"))

    {:ok, dir: dir}
  end

  test "a signed Slack event capture replays through verify_delivery/4 and a tampered one fails",
       %{conn: conn, dir: dir} do
    body =
      Jason.encode!(%{
        type: "event_callback",
        event_id: "EvCapture1",
        team_id: "T1",
        event: %{type: "message", user: "U1", channel: "C1", ts: "1.0", text: "ask ada@corp.test"}
      })

    timestamp = Integer.to_string(System.system_time(:second))

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-slack-request-timestamp", timestamp)
      |> put_req_header("x-slack-signature", slack_signature(@secret, timestamp, body))
      |> post(~p"/integrations/slack/events", body)

    assert %{"ok" => true} = json_response(conn, 200)

    assert [path] = Path.wildcard(Path.join(dir, "slack-events-*.json"))
    raw = path |> File.read!() |> Jason.decode!()

    assert raw["body"] == body
    assert raw["path"] == "/integrations/slack/events"
    assert raw["headers"]["x-slack-request-timestamp"] == timestamp

    assert {:ok, %{delivery_id: "EvCapture1"}} =
             LiveSmoke.replay(path, webhook: Webhook, secret: @secret)

    sanitized = LiveSmoke.sanitize_capture(path, secret: @secret)
    refute sanitized["body"] =~ "ada@corp.test"

    assert {:ok, %{delivery_id: "EvCapture1", payload: payload}} =
             LiveSmoke.replay(sanitized, webhook: Webhook)

    assert payload["event"]["text"] == "ask person-1@example.com"

    for {capture, secret} <- [{raw, @secret}, {sanitized, LiveSmoke.replay_secret()}] do
      tampered = Map.update!(capture, "body", &String.replace(&1, "ask", "tell"))

      assert {:error, %AuthError{reason: :invalid_signature}} =
               LiveSmoke.replay(tampered, webhook: Webhook, secret: secret)
    end

    forged = Map.update!(raw, "body", &String.replace(&1, "ask", "tell"))

    assert_raise ArgumentError, ~r/does not verify/, fn ->
      LiveSmoke.sanitize_capture(forged, secret: @secret)
    end
  end

  test "Slack interactivity requests are captured and stay verifiable after sanitizing",
       %{conn: conn, dir: dir} do
    payload = Jason.encode!(%{type: "block_actions", user: %{id: "U1", name: "ada@corp.test"}})
    body = URI.encode_query(%{"payload" => payload})
    timestamp = Integer.to_string(System.system_time(:second))

    conn =
      conn
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> put_req_header("x-slack-request-timestamp", timestamp)
      |> put_req_header("x-slack-signature", slack_signature(@secret, timestamp, body))
      |> post(~p"/integrations/slack/interactivity", body)

    assert %{"ok" => true} = json_response(conn, 200)
    assert [path] = Path.wildcard(Path.join(dir, "slack-interactivity-*.json"))
    assert Jason.decode!(File.read!(path))["body"] == body

    sanitized = LiveSmoke.sanitize_capture(path, secret: @secret)

    refute URI.decode_www_form(sanitized["body"]) =~ "ada@corp.test"

    assert :ok =
             Webhook.verify_signature(
               sanitized["body"],
               sanitized["headers"],
               LiveSmoke.replay_secret(),
               now: sanitized["captured_at"]
             )
  end

  test "the Jira webhook route captures deliveries only in capture mode", %{conn: conn, dir: dir} do
    body = ~s({"webhookEvent":"jira:issue_updated","user":{"emailAddress":"ada@corp.test"}})

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-hub-signature", "sha256=" <> hmac("jira-secret", body))
      |> post(~p"/integrations/jira/webhook", body)

    assert %{"ok" => true, "captured" => true} = json_response(response, 200)
    assert [path] = Path.wildcard(Path.join(dir, "jira-webhook-*.json"))

    sanitized = LiveSmoke.sanitize_capture(path, secret: "jira-secret")
    refute sanitized["body"] =~ "ada@corp.test"

    assert sanitized["headers"]["x-hub-signature"] ==
             "sha256=" <> hmac(LiveSmoke.replay_secret(), sanitized["body"])

    System.delete_env("JIRA_CAPTURE_DIR")

    response =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/integrations/jira/webhook", body)

    assert %{"ok" => false} = json_response(response, 404)
  end

  defp slack_signature(secret, timestamp, body),
    do: "v0=" <> hmac(secret, "v0:#{timestamp}:#{body}")

  defp hmac(secret, data) do
    :hmac
    |> :crypto.mac(:sha256, secret, data)
    |> Base.encode16(case: :lower)
  end

  defp put_env(name, value) do
    previous = System.get_env(name)
    System.put_env(name, value)

    on_exit(fn ->
      if previous, do: System.put_env(name, previous), else: System.delete_env(name)
    end)
  end

  defp tmp_dir(prefix) do
    path =
      Path.join(System.tmp_dir!(), "jido-demo-#{prefix}-#{System.unique_integer([:positive])}")

    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end
end
