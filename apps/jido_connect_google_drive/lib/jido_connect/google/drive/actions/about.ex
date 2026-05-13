defmodule Jido.Connect.Google.Drive.Actions.About do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver

  actions do
    action :get_about do
      id("google.drive.about.get")
      resource(:drive)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get Drive account metadata")
      description("Fetch Google Drive user, quota, and system capability metadata.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetAbout)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:fields, :string)
      end

      output do
        field(:about, :map)
      end
    end
  end
end
