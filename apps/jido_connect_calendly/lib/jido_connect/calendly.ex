defmodule Jido.Connect.Calendly do
  @moduledoc """
  Calendly integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action and trigger fragments will be
  added as the Calendly surface is implemented in subsequent steps.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Calendly.Actions.Read,
      Jido.Connect.Calendly.Actions.CancellationWebhooks
    ]

  integration do
    id(:calendly)
    name("Calendly")
    description("Calendly scheduling, event type, invitee, and webhook tools.")
    category(:calendar)
    docs(["https://developer.calendly.com/docs/api-v2"])
  end

  catalog do
    package(:jido_connect_calendly)
    status(:experimental)
    tags([:calendly, :scheduling, :booking, :webhooks])
  end

  auth do
    api_key :personal_access_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Calendly personal access token")
      setup(:api_key_bearer_token)
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([])
      default_scopes([])
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Calendly OAuth user")
      authorize_url("https://auth.calendly.com/oauth/authorize")
      token_url("https://auth.calendly.com/oauth/token")
      callback_path("/integrations/calendly/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "view",
        "edit",
        "webhook"
      ])

      default_scopes([])
      optional_scopes(["view", "edit", "webhook"])
      pkce?(true)
      refresh?(true)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Calendly.CatalogPacks, as: :all
end
