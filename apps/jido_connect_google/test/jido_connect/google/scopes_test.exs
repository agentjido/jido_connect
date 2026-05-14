defmodule Jido.Connect.Google.ScopesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Scopes

  test "normalizes and checks Google scopes" do
    assert Scopes.user_default() == ["openid", "email", "profile"]
    assert Scopes.normalize("openid email,profile") == ["openid", "email", "profile"]
    assert Scopes.normalize(nil) == []
    assert Scopes.normalize([:openid, "email", :openid]) == ["openid", "email"]
    assert Scopes.encode(["openid", "email"]) == "openid email"
    assert Scopes.include?(["openid", "email"], ["email"])
    assert Scopes.missing(["openid"], ["openid", "email"]) == ["email"]
  end

  test "exposes initial product scope catalog" do
    assert "https://www.googleapis.com/auth/spreadsheets.readonly" in Scopes.product(:sheets)
    assert "https://www.googleapis.com/auth/gmail.metadata" in Scopes.product(:gmail)
    assert "https://www.googleapis.com/auth/gmail.labels" in Scopes.product(:gmail)
    assert "https://mail.google.com/" in Scopes.product(:gmail)
    assert "https://www.googleapis.com/auth/drive" in Scopes.product(:drive)
    assert "https://www.googleapis.com/auth/drive.file" in Scopes.product(:drive)
    assert "https://www.googleapis.com/auth/calendar" in Scopes.product(:calendar)
    assert "https://www.googleapis.com/auth/calendar.readonly" in Scopes.product(:calendar)
    assert "https://www.googleapis.com/auth/calendar.calendars" in Scopes.product(:calendar)

    assert "https://www.googleapis.com/auth/calendar.calendars.readonly" in Scopes.product(
             :calendar
           )

    assert "https://www.googleapis.com/auth/calendar.calendarlist" in Scopes.product(:calendar)
    assert "https://www.googleapis.com/auth/calendar.acls.readonly" in Scopes.product(:calendar)
    assert "https://www.googleapis.com/auth/calendar.acls" in Scopes.product(:calendar)

    assert "https://www.googleapis.com/auth/calendar.settings.readonly" in Scopes.product(
             :calendar
           )

    assert "https://www.googleapis.com/auth/calendar.events" in Scopes.product(:calendar)
    assert "https://www.googleapis.com/auth/contacts.readonly" in Scopes.product(:contacts)
    assert "https://www.googleapis.com/auth/contacts.other.readonly" in Scopes.product(:contacts)
    assert "https://www.googleapis.com/auth/directory.readonly" in Scopes.product(:contacts)
    assert "https://www.googleapis.com/auth/analytics.readonly" in Scopes.product(:analytics)
    assert "https://www.googleapis.com/auth/meetings.space.created" in Scopes.product(:meet)
    assert "https://www.googleapis.com/auth/meetings.space.readonly" in Scopes.product(:meet)

    assert "https://www.googleapis.com/auth/webmasters.readonly" in Scopes.product(
             :search_console
           )

    assert Scopes.product(:unknown) == []
    assert Scopes.catalog().identity == ["openid", "email", "profile"]
    assert "https://www.googleapis.com/auth/drive" in Scopes.user_optional()
    assert "https://www.googleapis.com/auth/drive.file" in Scopes.user_optional()
  end
end
