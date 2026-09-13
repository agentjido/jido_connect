defmodule Jido.Connect.MicrosoftTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft

  test "exposes shared Microsoft provider metadata" do
    assert Microsoft.provider() == :microsoft
    assert Microsoft.auth_profiles() == [:user, :application]
  end

  test "exposes product-area availability ids" do
    areas = Microsoft.availability()
    assert is_list(areas)
    assert :mail in areas
    assert :calendar in areas
    assert :files in areas
    assert :sharepoint in areas
    assert :contacts in areas
    assert :tasks in areas
    assert :teams in areas
  end
end
