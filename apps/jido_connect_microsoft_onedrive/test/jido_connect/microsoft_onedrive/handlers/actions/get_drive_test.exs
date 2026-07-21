defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetDriveTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetDrive

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
    test "fetches the authenticated user's default drive" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/drive"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "id" => "b!DRIVE1",
          "driveType" => "personal",
          "name" => "OneDrive",
          "webUrl" => "https://contoso-my.sharepoint.com/personal/user/Documents",
          "quota" => %{
            "total" => 1_099_511_627_776,
            "used" => 536_870_912,
            "remaining" => 1_098_974_756_864,
            "state" => "normal"
          },
          "owner" => %{
            "user" => %{"displayName" => "Adele Vance", "email" => "adele@contoso.com"}
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}
      assert {:ok, %{drive: drive}} = GetDrive.run(%{}, context)

      assert drive.drive_id == "b!DRIVE1"
      assert drive.drive_type == "personal"
      assert drive.name == "OneDrive"
      assert drive.quota["total"] == 1_099_511_627_776
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetDrive.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(401), %{
          "error" => %{"message" => "Invalid authentication token."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetDrive.run(%{}, context)
    end
  end
end
