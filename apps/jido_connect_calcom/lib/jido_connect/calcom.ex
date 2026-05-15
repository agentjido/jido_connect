defmodule Jido.Connect.Calcom do
  @moduledoc """
  Cal.com integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Cal.com surface is implemented.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Calcom.Actions.EventTypes,
      Jido.Connect.Calcom.Actions.Bookings,
      Jido.Connect.Calcom.Actions.Webhooks
    ]

  integration do
    id(:calcom)
    name("Cal.com")
    description("Cal.com scheduling, booking, and event type tools.")
    category(:calendar)
    docs(["https://cal.com/docs/api-reference/v2"])
  end

  catalog do
    package(:jido_connect_calcom)
    status(:experimental)
    tags([:calcom, :scheduling, :booking, :webhooks])
  end

  auth do
    api_key :api_key do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Cal.com API key")
      setup(:api_key_bearer_token)
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "EVENT_TYPE_READ",
        "BOOKING_READ",
        "BOOKING_WRITE",
        "WEBHOOK_READ",
        "WEBHOOK_WRITE"
      ])

      default_scopes([
        "EVENT_TYPE_READ",
        "BOOKING_READ",
        "BOOKING_WRITE",
        "WEBHOOK_READ",
        "WEBHOOK_WRITE"
      ])
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Cal.com OAuth user")
      authorize_url("https://app.cal.com/api/auth/oauth2/authorize")
      token_url("https://app.cal.com/api/auth/oauth2/token")
      callback_path("/integrations/calcom/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "EVENT_TYPE_READ",
        "BOOKING_READ",
        "BOOKING_WRITE",
        "WEBHOOK_READ",
        "WEBHOOK_WRITE"
      ])

      default_scopes(["EVENT_TYPE_READ", "BOOKING_READ"])
      optional_scopes(["BOOKING_WRITE", "WEBHOOK_READ", "WEBHOOK_WRITE"])
      pkce?(true)
      refresh?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Calcom.CatalogPacks, as: :all
  defdelegate reader_pack, to: Jido.Connect.Calcom.CatalogPacks, as: :reader
  defdelegate booking_pack, to: Jido.Connect.Calcom.CatalogPacks, as: :booking
  defdelegate webhook_pack, to: Jido.Connect.Calcom.CatalogPacks, as: :webhook
end
