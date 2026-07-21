defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.TentativelyAcceptEventTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.TentativelyAcceptEvent

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
    test "tentatively accepts an event with comment" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/events/AAMkEV_TEN_001/tentativelyAccept"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["comment"] == "Might need to reschedule"

        conn
        |> Plug.Conn.put_status(202)
        |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{tentatively_accepted: true, event_id: "AAMkEV_TEN_001"}} =
               TentativelyAcceptEvent.run(
                 %{event_id: "AAMkEV_TEN_001", comment: "Might need to reschedule"},
                 context
               )
    end

    test "tentatively accepts an event without comment" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded == %{}

        conn
        |> Plug.Conn.put_status(202)
        |> Plug.Conn.send_resp(202, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{tentatively_accepted: true, event_id: "AAMkEV_TEN_002"}} =
               TentativelyAcceptEvent.run(%{event_id: "AAMkEV_TEN_002"}, context)
    end

    test "returns error when event_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :event_id_required} = TentativelyAcceptEvent.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = TentativelyAcceptEvent.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified event was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               TentativelyAcceptEvent.run(%{event_id: "nonexistent"}, context)
    end
  end
end
