defmodule Jido.Connect.Salesforce.Handlers.Actions.CreateTaskTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.CreateTask

  describe "run/2" do
    test "returns task_id and success on create" do
      result = %{id: "00T5g00000NEWID", success: true, errors: []}

      MockClient.stub(create_task: {:ok, result})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{task_id: "00T5g00000NEWID", success: true}} =
               CreateTask.run(
                 %{subject: "Follow up", status: "Not Started"},
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{
           provider: :salesforce,
           message: "Required field missing"
         }}

      MockClient.stub(create_task: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateTask.run(%{}, %{credentials: credentials})
    end
  end
end
