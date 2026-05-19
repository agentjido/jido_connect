defmodule Jido.Connect.Microsoft.ScopesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.Scopes

  test "normalizes and checks Microsoft scopes" do
    assert Scopes.user_default() == ["openid", "email", "profile", "offline_access"]
    assert Scopes.normalize("openid email,profile") == ["openid", "email", "profile"]
    assert Scopes.normalize(nil) == []
    assert Scopes.normalize([:openid, "email", :openid]) == ["openid", "email"]
    assert Scopes.encode(["openid", "email"]) == "openid email"
    assert Scopes.include?(["openid", "email"], ["email"])
    assert Scopes.missing(["openid"], ["openid", "email"]) == ["email"]
  end

  test "exposes initial product scope catalog" do
    assert "Mail.Read" in Scopes.product(:mail)
    assert "Mail.ReadWrite" in Scopes.product(:mail)
    assert "Mail.Send" in Scopes.product(:mail)
    assert "Calendars.Read" in Scopes.product(:calendar)
    assert "Calendars.ReadWrite" in Scopes.product(:calendar)
    assert "Files.Read" in Scopes.product(:files)
    assert "Files.ReadWrite.All" in Scopes.product(:files)
    assert "Contacts.Read" in Scopes.product(:contacts)
    assert "Tasks.Read" in Scopes.product(:tasks)
    assert "Team.ReadBasic.All" in Scopes.product(:teams)
    assert Scopes.product(:unknown) == []
    assert Scopes.catalog().identity == ["openid", "email", "profile", "offline_access"]
    assert "Mail.Read" in Scopes.user_optional()
    assert "Calendars.Read" in Scopes.user_optional()
  end
end
