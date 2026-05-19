defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetProfileTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetProfile

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
    test "fetches Outlook profile successfully" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "id" => "user-123",
          "displayName" => "Megan Bowen",
          "mail" => "meganb@contoso.com",
          "userPrincipalName" => "meganb@contoso.com"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{profile: profile}} = GetProfile.run(%{}, context)

      assert profile.user_id == "user-123"
      assert profile.display_name == "Megan Bowen"
      assert profile.email == "meganb@contoso.com"
      assert profile.user_principal_name == "meganb@contoso.com"
    end

    test "returns profile with minimal fields" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "id" => "user-456"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{profile: profile}} = GetProfile.run(%{}, context)
      assert profile.user_id == "user-456"
      refute Map.has_key?(profile, :display_name)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetProfile.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{"message" => "Insufficient privileges"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetProfile.run(%{}, context)
    end
  end
end
