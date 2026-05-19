defmodule Jido.Connect.Intercom.Handlers.Actions.ListAdminsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.ListAdmins

  describe "run/2" do
    test "lists admins with mock client" do
      input = %{}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListAdmins.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).id == "991"
      assert hd(result.items).name == "Carol Chen"
      assert hd(result.items).email == "carol@example.com"
      assert result.pagination != nil
    end

    test "passes pagination params" do
      input = %{per_page: 10}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListAdmins.run(input, runtime)
      assert length(result.items) == 2
    end
  end
end
