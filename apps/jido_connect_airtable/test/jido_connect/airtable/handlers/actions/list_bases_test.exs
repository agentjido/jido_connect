defmodule Jido.Connect.Airtable.Handlers.Actions.ListBasesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Base
  alias Jido.Connect.Airtable.Handlers.Actions.ListBases

  describe "run/2" do
    test "returns bases list on success" do
      bases = [
        Base.new!(%{base_id: "appTest1", name: "Test Base"}),
        Base.new!(%{base_id: "appTest2", name: "Other Base"})
      ]

      MockClient.stub(list_bases: {:ok, bases})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListBases.run(%{}, %{credentials: credentials})
      assert length(result.bases) == 2
      assert hd(result.bases).base_id == "appTest1"
      assert hd(result.bases).name == "Test Base"
    end

    test "returns empty list when no bases" do
      MockClient.stub(list_bases: {:ok, []})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListBases.run(%{}, %{credentials: credentials})
      assert result.bases == []
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :airtable, message: "Unauthorized"}}

      MockClient.stub(list_bases: error)
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListBases.run(%{}, %{credentials: credentials})
    end

    test "passes offset param to client" do
      bases = [Base.new!(%{base_id: "appTest1", name: "Test Base"})]

      MockClient.stub(list_bases: {:ok, bases})
      credentials = %{airtable_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListBases.run(%{offset: "itrXXXXXXXXXXXX/recXXXXXXXXXXXX"}, %{
                 credentials: credentials
               })

      assert length(result.bases) == 1
    end
  end
end
