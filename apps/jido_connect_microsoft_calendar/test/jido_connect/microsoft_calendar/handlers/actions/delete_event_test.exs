defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeleteEventTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeleteEvent

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
    test "deletes an event from default calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/me/events/AAMkEV_DEL_001"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        conn
        |> Plug.Conn.put_status(204)
        |> Plug.Conn.send_resp(204, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{deleted: true, event_id: "AAMkEV_DEL_001"}} =
               DeleteEvent.run(%{event_id: "AAMkEV_DEL_001"}, context)
    end

    test "deletes an event from a specific calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/calendars/CAL789/events/AAMkEV_DEL_002"

        conn
        |> Plug.Conn.put_status(204)
        |> Plug.Conn.send_resp(204, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{deleted: true, event_id: "AAMkEV_DEL_002"}} =
               DeleteEvent.run(
                 %{event_id: "AAMkEV_DEL_002", calendar_id: "CAL789"},
                 context
               )
    end

    test "returns error when event_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :event_id_required} = DeleteEvent.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = DeleteEvent.run(%{}, %{})
    end

    test "returns error for HTTP 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified event was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 404}} =
               DeleteEvent.run(%{event_id: "nonexistent"}, context)
    end

    test "returns error for HTTP 403 forbidden" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{
            "code" => "ErrorAccessDenied",
            "message" => "Cannot delete events in this calendar."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               DeleteEvent.run(%{event_id: "restricted"}, context)
    end
  end
end
