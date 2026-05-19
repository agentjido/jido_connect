defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListCalendarsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListCalendars

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
    test "lists calendars from the authenticated user" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/calendars"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert conn.query_params["$top"] == "25"

        Req.Test.json(conn, %{
          "@odata.context" =>
            "https://graph.microsoft.com/v1.0/$metadata#users('user')/calendars",
          "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/calendars?$skip=10",
          "value" => [
            %{
              "id" => "AAMkAGI2TG93AAA=",
              "name" => "Calendar",
              "color" => "auto",
              "isDefaultCalendar" => true,
              "canEdit" => true,
              "owner" => %{
                "name" => "Megan Bowen",
                "address" => "meganb@contoso.com"
              }
            },
            %{
              "id" => "AAMkAGI2TG93BBB=",
              "name" => "Team Events",
              "color" => "blue",
              "hexColor" => "#0000FF",
              "isDefaultCalendar" => false,
              "isShared" => true,
              "canEdit" => true
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{calendars: calendars, next_link: next_link}} =
               ListCalendars.run(%{}, context)

      assert length(calendars) == 2
      assert [%{name: "Calendar"}, %{name: "Team Events"}] = calendars
      assert next_link =~ "$skip=10"
    end

    test "passes page_size and skip parameters" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["$top"] == "10"
        assert conn.query_params["$skip"] == "20"

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{calendars: []}} =
               ListCalendars.run(%{page_size: 10, skip: 20}, context)
    end

    test "handles empty calendar list" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "@odata.context" =>
            "https://graph.microsoft.com/v1.0/$metadata#users('user')/calendars",
          "value" => []
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{calendars: [], next_link: nil}} = ListCalendars.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ListCalendars.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ListCalendars.run(%{}, context)
    end

    test "returns error for HTTP 401 unauthorized" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(401), %{
          "error" => %{
            "code" => "InvalidAuthenticationToken",
            "message" => "Access token has expired."
          }
        })
      end)

      context = %{credentials: %{access_token: "expired-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 401}} =
               ListCalendars.run(%{}, context)
    end
  end
end
