defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.CancelEventTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.CancelEvent

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
    test "cancels an event with comment" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/events/AAMkEV_CANCEL_001/cancel"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["comment"] == "Rescheduling for next week"

        conn
        |> Plug.Conn.put_status(204)
        |> Plug.Conn.send_resp(204, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{cancelled: true, event_id: "AAMkEV_CANCEL_001"}} =
               CancelEvent.run(
                 %{event_id: "AAMkEV_CANCEL_001", comment: "Rescheduling for next week"},
                 context
               )
    end

    test "cancels an event without comment" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded == %{}

        conn
        |> Plug.Conn.put_status(204)
        |> Plug.Conn.send_resp(204, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{cancelled: true, event_id: "AAMkEV_CANCEL_002"}} =
               CancelEvent.run(%{event_id: "AAMkEV_CANCEL_002"}, context)
    end

    test "returns error when event_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :event_id_required} = CancelEvent.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = CancelEvent.run(%{}, %{})
    end

    test "returns error for HTTP 403 when not organizer" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{
            "code" => "ErrorAccessDenied",
            "message" => "Only the organizer can cancel the event."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               CancelEvent.run(%{event_id: "not-organizer-event"}, context)
    end

    test "returns error for HTTP 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified event was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 404}} =
               CancelEvent.run(%{event_id: "nonexistent"}, context)
    end
  end
end
