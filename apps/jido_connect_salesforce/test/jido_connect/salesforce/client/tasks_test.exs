defmodule Jido.Connect.Salesforce.Client.TasksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Client.Tasks

  test "create_task/2 is exported" do
    assert {:module, Tasks} = Code.ensure_loaded(Tasks)
    assert function_exported?(Tasks, :create_task, 2)
  end

  test "update_task/2 is exported" do
    assert {:module, Tasks} = Code.ensure_loaded(Tasks)
    assert function_exported?(Tasks, :update_task, 2)
  end
end
