defmodule Jido.Connect.Salesforce.Client.LeadsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Client.Leads

  test "create_lead/2 is exported" do
    assert {:module, Leads} = Code.ensure_loaded(Leads)
    assert function_exported?(Leads, :create_lead, 2)
  end

  test "update_lead/2 is exported" do
    assert {:module, Leads} = Code.ensure_loaded(Leads)
    assert function_exported?(Leads, :update_lead, 2)
  end
end
