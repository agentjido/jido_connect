defmodule Jido.Connect.Salesforce.Handlers.Actions.UpdateTaskTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Handlers.Actions.UpdateTask

  describe "run/2" do
    test "returns task_id and success on update" do
      MockClient.stub(update_task: {:ok, %{success: true}})

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, %{task_id: "00T5g00000ABCdE", success: true}} =
               UpdateTask.run(
                 %{task_id: "00T5g00000ABCdE", status: "Completed"},
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{
           provider: :salesforce,
           message: "INVALID_FIELD"
         }}

      MockClient.stub(update_task: error)

      credentials = %{
        salesforce_client: MockClient,
        access_token: "test-token",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateTask.run(
                 %{task_id: "00T5g00000ABCdE"},
                 %{credentials: credentials}
               )
    end
  end
end
