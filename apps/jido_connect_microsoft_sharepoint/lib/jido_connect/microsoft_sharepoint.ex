defmodule Jido.Connect.MicrosoftSharepoint do
  @moduledoc "Microsoft SharePoint Online integration for Jido Connect."

  use Jido.Connect,
    fragments: [
      Jido.Connect.MicrosoftSharepoint.Actions.Sites,
      Jido.Connect.MicrosoftSharepoint.Actions.Lists,
      Jido.Connect.MicrosoftSharepoint.Actions.ListItems,
      Jido.Connect.MicrosoftSharepoint.Actions.ListItemWrites
    ]

  alias Jido.Connect.Microsoft.Scopes

  integration do
    id(:microsoft_sharepoint)
    name("Microsoft SharePoint")
    description("Microsoft SharePoint Online site, list, and document tools via Microsoft Graph.")
    category(:productivity)
    docs(["https://learn.microsoft.com/en-us/graph/api/resources/sharepoint"])
  end

  catalog do
    package(:jido_connect_microsoft_sharepoint)
    status(:available)
    tags([:microsoft, :sharepoint, :sites, :lists, :documents])
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Microsoft Graph OAuth user")
      authorize_url("https://login.microsoftonline.com/common/oauth2/v2.0/authorize")
      token_url("https://login.microsoftonline.com/common/oauth2/v2.0/token")
      callback_path("/integrations/microsoft/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])
      scopes(Scopes.user_default() ++ Scopes.product(:sharepoint) ++ Scopes.product(:files))
      default_scopes(Scopes.user_default())
      optional_scopes(Scopes.product(:sharepoint) ++ Scopes.product(:files))
      pkce?(true)
      refresh?(true)
    end

    oauth2 :application do
      owner(:tenant)
      subject(:service_principal)
      label("Microsoft Graph application")
      authorize_url("https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize")
      token_url("https://login.microsoftonline.com/organizations/oauth2/v2.0/token")
      setup(:oauth2_client_credentials)
      credential_fields([:client_id, :client_secret, :tenant_id])
      lease_fields([:access_token])
      scopes(Scopes.product(:sharepoint) ++ Scopes.product(:files))
      default_scopes([])
      optional_scopes(Scopes.product(:sharepoint) ++ Scopes.product(:files))

      metadata(%{
        token_scope: "https://graph.microsoft.com/.default",
        tenant_specific_token_url: true
      })
    end
  end

  policies do
    policy :sharepoint_resource_access do
      label("SharePoint resource access")

      description(
        "Host verifies that the actor and connection can access the requested SharePoint site."
      )

      subject({:input, :site_id})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end
end
