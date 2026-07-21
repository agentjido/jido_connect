defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListDrivesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListDrives

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
    test "lists available drives" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/drives"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert conn.query_params["$top"] == "25"

        Req.Test.json(conn, %{
          "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/drives?$skip=25",
          "value" => [
            %{
              "id" => "b!DRIVE1",
              "driveType" => "personal",
              "name" => "OneDrive"
            },
            %{
              "id" => "b!DRIVE2",
              "driveType" => "business",
              "name" => "Shared Documents"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}
      assert {:ok, %{drives: drives, next_link: next_link}} = ListDrives.run(%{}, context)

      assert length(drives) == 2
      [first, second] = drives
      assert first.drive_id == "b!DRIVE1"
      assert first.drive_type == "personal"
      assert second.drive_id == "b!DRIVE2"
      assert second.drive_type == "business"
      assert next_link =~ "$skip=25"
    end

    test "handles empty result" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}
      assert {:ok, %{drives: [], next_link: nil}} = ListDrives.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ListDrives.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ListDrives.run(%{}, context)
    end

    test "passes custom page_size" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["$top"] == "5"

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{drives: []}} = ListDrives.run(%{page_size: 5}, context)
    end
  end
end
