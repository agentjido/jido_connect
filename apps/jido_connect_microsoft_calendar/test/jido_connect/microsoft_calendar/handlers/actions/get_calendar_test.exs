defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetCalendarTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetCalendar

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
    test "fetches a single calendar by id" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/calendars/AAMkAGI2TG93AAA="
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "id" => "AAMkAGI2TG93AAA=",
          "name" => "Calendar",
          "color" => "auto",
          "hexColor" => "#0078D4",
          "isDefaultCalendar" => true,
          "isShared" => false,
          "canEdit" => true,
          "canShare" => true,
          "canViewPrivateItems" => true,
          "owner" => %{
            "name" => "Megan Bowen",
            "address" => "meganb@contoso.com"
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{calendar: calendar}} =
               GetCalendar.run(%{calendar_id: "AAMkAGI2TG93AAA="}, context)

      assert calendar.calendar_id == "AAMkAGI2TG93AAA="
      assert calendar.name == "Calendar"
      assert calendar.is_default_calendar == true
      assert calendar.owner.name == "Megan Bowen"
    end

    test "returns error when calendar_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :calendar_id_required} = GetCalendar.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetCalendar.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified calendar was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetCalendar.run(%{calendar_id: "nonexistent"}, context)
    end

    test "returns error for HTTP 403 forbidden" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{
            "code" => "ErrorAccessDenied",
            "message" => "Access is denied."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               GetCalendar.run(%{calendar_id: "restricted"}, context)
    end
  end
end
