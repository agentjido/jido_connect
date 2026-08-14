defmodule Jido.Connect.Nextcloud do
  @moduledoc """
  Nextcloud integration authored with the `Jido.Connect` Spark DSL.

  The connector is intentionally packaged as one provider because Files, Office,
  groupware, and Talk share the same Nextcloud instance, credential model, and
  host policy boundary. Internals are split by capability through fragments,
  clients, handlers, and catalog packs.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Nextcloud.Actions.Files,
      Jido.Connect.Nextcloud.Actions.Shares,
      Jido.Connect.Nextcloud.Actions.Office
    ]

  integration do
    id(:nextcloud)
    name("Nextcloud")
    description("Nextcloud files, sharing, Office, and collaboration tools.")
    category(:productivity)

    docs([
      "https://docs.nextcloud.com/server/stable/developer_manual/client_apis/WebDAV/basic.html",
      "https://docs.nextcloud.com/server/stable/developer_manual/client_apis/OCS/ocs-share-api.html",
      "https://docs.nextcloud.com/server/stable/developer_manual/client_apis/LoginFlow/index.html"
    ])
  end

  catalog do
    package(:jido_connect_nextcloud)
    status(:experimental)
    tags([:nextcloud, :files, :storage, :office, :collaboration])

    capability :webdav_files do
      kind(:runtime)
      feature(:files)
      label("Nextcloud Files")
      description("Read, search, upload, move, copy, and delete files through WebDAV.")
    end

    capability :ocs_sharing do
      kind(:runtime)
      feature(:sharing)
      label("Nextcloud OCS sharing")
      description("Manage file shares and search share recipients through OCS APIs.")
    end

    capability :office_external_app do
      kind(:setup)
      feature(:office)
      label("Nextcloud Office external app")

      description(
        "Fetch richdocuments launch metadata when external-app access is configured by the host."
      )
    end
  end

  auth do
    api_key :app_password do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Nextcloud app password")
      setup(:nextcloud_app_password)
      credential_fields([:base_url, :login_name, :app_password])
      lease_fields([:base_url, :login_name, :app_password])

      scopes([
        "files:read",
        "files:write",
        "files:share",
        "office:launch"
      ])

      default_scopes(["files:read"])
      optional_scopes(["files:write", "files:share", "office:launch"])
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Nextcloud OAuth2 user")
      authorize_url("https://cloud.example.org/apps/oauth2/authorize")
      token_url("https://cloud.example.org/apps/oauth2/api/v1/token")
      callback_path("/integrations/nextcloud/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:base_url, :access_token, :refresh_token])
      lease_fields([:base_url, :access_token])
      scopes(["account"])
      default_scopes(["account"])
      refresh?(true)
    end
  end

  policies do
    policy :nextcloud_instance_access do
      label("Nextcloud instance access")

      description(
        "Host verifies the actor may use this connection for the configured Nextcloud instance."
      )

      subject({:credential, :base_url})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Nextcloud.CatalogPacks, as: :all
  defdelegate files_readonly_pack, to: Jido.Connect.Nextcloud.CatalogPacks, as: :files_readonly
  defdelegate files_write_pack, to: Jido.Connect.Nextcloud.CatalogPacks, as: :files_write

  defdelegate files_destructive_pack,
    to: Jido.Connect.Nextcloud.CatalogPacks,
    as: :files_destructive

  defdelegate sharing_pack, to: Jido.Connect.Nextcloud.CatalogPacks, as: :sharing
  defdelegate office_pack, to: Jido.Connect.Nextcloud.CatalogPacks, as: :office
  defdelegate full_pack, to: Jido.Connect.Nextcloud.CatalogPacks, as: :full
end
