defmodule Jido.Connect.Nextcloud.Actions.Office do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Nextcloud.ScopeResolver

  actions do
    action :get_office_capabilities do
      id("nextcloud.office.capabilities.get")
      resource(:office)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get Nextcloud Office capabilities")
      description("Fetch Nextcloud capabilities and derive Office/richdocuments availability.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.GetOfficeCapabilities)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:read"], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:capabilities, :map)
        field(:office, :map)
      end
    end

    action :get_office_launch_token do
      id("nextcloud.office.launch_token.get")
      resource(:office)
      verb(:get)
      data_classification(:personal_data)
      label("Get Nextcloud Office launch token")

      description(
        "Fetch richdocuments external-app launch data for a file id. Requires host-configured external app credentials."
      )

      handler(Jido.Connect.Nextcloud.Handlers.Actions.GetOfficeLaunchToken)
      effect(:external_write, confirmation: :always)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["office:launch"], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true)
        field(:app_id, :string, required?: true)
        field(:app_secret, :string, required?: true)
      end

      output do
        field(:launch, :map)
      end
    end
  end
end
