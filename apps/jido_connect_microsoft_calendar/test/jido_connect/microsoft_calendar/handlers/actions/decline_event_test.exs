defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeclineEventTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeclineEvent

  setup do
    Application.put_env(:jido_connect_microsoft, :microsoft_graph_base_url, "https://graph.test")

    Application.put_env(:jido_connect_microsoft, :microsoft_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)
      Application.delete_env(:jido_connect_microsoft, :microsoft_req_options)
    end)
  end

  describe "run/2" do
    test "declines an event with comment" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/events/AAMkEV_DEC_001/decline"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["comment"] == "Conflict with another meeting"

        conn
        |> Plug.Conn.put_status(202)
        |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{declined: true, event_id: "AAMkEV_DEC_001"}} =
               DeclineEvent.run(
                 %{event_id: "AAMkEV_DEC_001", comment: "Conflict with another meeting"},
                 context
               )
    end

    test "declines an event without comment" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded == %{}

        conn
        |> Plug.Conn.put_status(202)
        |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{declined: true, event_id: "AAMkEV_DEC_002"}} =
               DeclineEvent.run(%{event_id: "AAMkEV_DEC_002"}, context)
    end

    test "returns error when event_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :event_id_required} = DeclineEvent.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = DeclineEvent.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified event was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               DeclineEvent.run(%{event_id: "nonexistent"}, context)
    end
  end
end
