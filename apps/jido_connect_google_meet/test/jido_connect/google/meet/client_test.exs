defmodule Jido.Connect.Google.Meet.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Meet.{Client, Space}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_meet,
      :google_meet_api_base_url,
      "https://meet.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_meet, :google_meet_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "creates a Meet space" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/spaces"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "config" => %{
                 "accessType" => "OPEN",
                 "moderation" => "OFF"
               }
             }

      Req.Test.json(conn, %{
        "name" => "spaces/abc-mnop-xyz",
        "meetingUri" => "https://meet.google.com/abc-mnop-xyz",
        "meetingCode" => "abc-mnop-xyz",
        "config" => %{"accessType" => "OPEN", "moderation" => "OFF"}
      })
    end)

    assert {:ok, %Space{} = space} =
             Client.create_space(%{access_type: "OPEN", moderation: "OFF"}, "token")

    assert space.space_name == "spaces/abc-mnop-xyz"
    assert space.meeting_code == "abc-mnop-xyz"
  end

  test "gets a Meet space" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/spaces/abc-mnop-xyz"
      assert conn.query_params["fields"] == "name,meetingUri,meetingCode"

      Req.Test.json(conn, %{
        "name" => "spaces/abc-mnop-xyz",
        "meetingUri" => "https://meet.google.com/abc-mnop-xyz",
        "meetingCode" => "abc-mnop-xyz"
      })
    end)

    assert {:ok, %Space{} = space} =
             Client.get_space(
               %{space_name: "spaces/abc-mnop-xyz", fields: "name,meetingUri,meetingCode"},
               "token"
             )

    assert space.meeting_uri == "https://meet.google.com/abc-mnop-xyz"
  end

  test "returns provider errors for malformed space responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/spaces/missing-name"

      Req.Test.json(conn, %{"meetingCode" => "missing-name"})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.get_space(%{space_name: "spaces/missing-name"}, "token")
  end
end
