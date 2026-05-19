defmodule Jido.Connect.MicrosoftTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft

  test "exposes shared Microsoft provider metadata" do
    assert Microsoft.provider() == :microsoft
    assert Microsoft.auth_profiles() == [:user]
  end
end
