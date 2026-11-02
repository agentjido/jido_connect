defmodule Jido.Connect.Slack.Client.ResponseTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.Client
  alias Jido.Connect.TestSupport.LiveSmoke

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})

    Application.put_env(:jido_connect_slack, :slack_upload_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_slack, :slack_req_options)
      Application.delete_env(:jido_connect_slack, :slack_upload_req_options)
    end)
  end

  test "post ephemeral sends expected request and normalizes output" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat.postEphemeral"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "channel" => "C123",
               "user" => "U123",
               "text" => "Only you can see this"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        ok: true,
        message_ts: "1700000000.000200"
      })
    end)

    assert {:ok,
            %{
              channel: "C123",
              user: "U123",
              message_ts: "1700000000.000200"
            }} =
             Client.post_ephemeral(
               %{channel: "C123", user: "U123", text: "Only you can see this"},
               "token"
             )
  end

  test "an ok:false rate limit keeps the Retry-After delay as retry metadata" do
    # Not recorded: triggering a 429 would throttle the test app in the
    # shared workspace. Status, header and error code follow the acceptance
    # criteria and Slack's rate-limit documentation; the rest of the body is
    # the recorded ok:false response of a denied history read.
    body =
      :slack
      |> LiveSmoke.fixture!("conversation_history_not_in_channel")
      |> Map.put("error", "ratelimited")

    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("retry-after", "30")
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(body)
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              status: 429,
              reason: "ratelimited",
              details: %{retry_after: 30} = details
            }} =
             Client.get_conversation_history(
               %{channel: "C0CDDP1JEAX", conversation_type: "public_channel"},
               "token"
             )

    refute Map.has_key?(details, :body)
  end

  test "an ok:false error without Retry-After stays an error without the message body" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{ok: false, error: "not_in_channel"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              status: 200,
              reason: "not_in_channel",
              details: details
            }} = Client.list_channels(%{types: "public_channel"}, "token")

    assert details.retry_after == nil
    refute Map.has_key?(details, :body)
  end

  test "HTTP and transport failures stay errors without the message body" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.text("upstream text that must not leak")
    end)

    assert {:error, %Error.ProviderError{provider: :slack, status: 500, details: details}} =
             Client.list_channels(%{types: "public_channel"}, "token")

    refute inspect(details) =~ "must not leak"

    Req.Test.stub(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))

    assert {:error, %Error.ProviderError{provider: :slack, reason: :request_error}} =
             Client.list_channels(%{types: "public_channel"}, "token")
  end

  test "normalizes malformed successful responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{ok: true, channels: %{id: "C123"}})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["channels", "ok"]}}
            }} =
             Client.list_channels(%{types: "public_channel"}, "token")
  end
end
