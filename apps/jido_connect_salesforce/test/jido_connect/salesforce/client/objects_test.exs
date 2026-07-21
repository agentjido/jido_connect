defmodule Jido.Connect.Salesforce.Client.ObjectsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Client.Objects

  test "query/2 is exported" do
    assert {:module, Objects} = Code.ensure_loaded(Objects)
    assert function_exported?(Objects, :query, 2)
  end

  test "get_record/2 is exported" do
    assert {:module, Objects} = Code.ensure_loaded(Objects)
    assert function_exported?(Objects, :get_record, 2)
  end

  test "create_record/2 is exported" do
    assert {:module, Objects} = Code.ensure_loaded(Objects)
    assert function_exported?(Objects, :create_record, 2)
  end

  test "update_record/2 is exported" do
    assert {:module, Objects} = Code.ensure_loaded(Objects)
    assert function_exported?(Objects, :update_record, 2)
  end

  test "describe_object/2 is exported" do
    assert {:module, Objects} = Code.ensure_loaded(Objects)
    assert function_exported?(Objects, :describe_object, 2)
  end

  test "list_recent/2 is exported" do
    assert {:module, Objects} = Code.ensure_loaded(Objects)
    assert function_exported?(Objects, :list_recent, 2)
  end

  test "query_more/2 is exported" do
    assert {:module, Objects} = Code.ensure_loaded(Objects)
    assert function_exported?(Objects, :query_more, 2)
  end
end
