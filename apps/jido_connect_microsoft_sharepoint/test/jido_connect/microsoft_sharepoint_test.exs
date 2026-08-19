defmodule Jido.Connect.MicrosoftSharepointTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftSharepoint
  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts

  test "declares SharePoint provider metadata and auth profiles" do
    spec = MicrosoftSharepoint.integration()

    assert spec.id == :microsoft_sharepoint
    assert spec.package == :jido_connect_microsoft_sharepoint
    assert spec.name == "Microsoft SharePoint"
    assert spec.category == :productivity
    assert spec.tags == [:microsoft, :sharepoint, :sites, :lists, :documents]
    assert spec.actions == []
    assert spec.triggers == []

    assert [%{id: :user} = user, %{id: :application} = application] = spec.auth_profiles
    assert user.default?
    assert user.refresh?
    assert "Sites.Read.All" in user.optional_scopes
    assert application.setup == :oauth2_client_credentials
    assert application.owner == :tenant
    assert application.lease_fields == [:access_token]

    ConnectorContracts.assert_generated_surface(MicrosoftSharepoint,
      otp_app: :jido_connect_microsoft_sharepoint,
      action_modules: [],
      sensor_specs: [],
      plugin_module: Jido.Connect.MicrosoftSharepoint.Plugin,
      plugin_name: "microsoft_sharepoint"
    )
  end
end
