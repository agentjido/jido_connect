defmodule Jido.Connect.Google.Calendar do
  @moduledoc """
  Google Calendar integration authored with the `Jido.Connect` Spark DSL.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Calendar.Actions.Read,
      Jido.Connect.Google.Calendar.Actions.Write,
      Jido.Connect.Google.Calendar.Actions.FreeBusy,
      Jido.Connect.Google.Calendar.Actions.Calendars,
      Jido.Connect.Google.Calendar.Actions.CalendarList,
      Jido.Connect.Google.Calendar.Actions.Acl,
      Jido.Connect.Google.Calendar.Actions.EventUtilities,
      Jido.Connect.Google.Calendar.Actions.Watch,
      Jido.Connect.Google.Calendar.Triggers.Events,
      Jido.Connect.Google.Calendar.Triggers.Push
    ]

  integration do
    id(:google_calendar)
    name("Google Calendar")
    description("Google Calendar calendar, event, freebusy, availability, and change tools.")
    category(:calendar)
    docs(["https://developers.google.com/calendar/api/guides/overview"])
  end

  catalog do
    package(:jido_connect_google_calendar)
    status(:available)
    tags([:google, :workspace, :calendar, :productivity])
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Google OAuth user")
      authorize_url("https://accounts.google.com/o/oauth2/v2/auth")
      token_url("https://oauth2.googleapis.com/token")
      callback_path("/integrations/google/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes(
        Jido.Connect.Google.Scopes.user_default() ++
          Jido.Connect.Google.Scopes.product(:calendar)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:calendar))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Google.Calendar.CatalogPacks, as: :all
  defdelegate reader_pack, to: Jido.Connect.Google.Calendar.CatalogPacks, as: :reader
  defdelegate scheduler_pack, to: Jido.Connect.Google.Calendar.CatalogPacks, as: :scheduler
  defdelegate watch_pack, to: Jido.Connect.Google.Calendar.CatalogPacks, as: :watch
  defdelegate manager_pack, to: Jido.Connect.Google.Calendar.CatalogPacks, as: :manager
end
