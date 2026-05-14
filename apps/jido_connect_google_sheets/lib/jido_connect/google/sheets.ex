defmodule Jido.Connect.Google.Sheets do
  @moduledoc """
  Google Sheets integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Sheets surface is implemented.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Sheets.Actions.Read,
      Jido.Connect.Google.Sheets.Actions.Write,
      Jido.Connect.Google.Sheets.Actions.ManageSpreadsheets,
      Jido.Connect.Google.Sheets.Actions.ManageSheets
    ]

  integration do
    id :google_sheets
    name "Google Sheets"
    description "Google Sheets spreadsheet, values, sheet, and batch update tools."
    category :productivity
    docs ["https://developers.google.com/workspace/sheets/api"]
  end

  catalog do
    package :jido_connect_google_sheets
    status :available
    tags [:google, :workspace, :spreadsheets, :productivity]
  end

  auth do
    oauth2 :user do
      default? true
      owner :app_user
      subject :user
      label "Google OAuth user"
      authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
      token_url "https://oauth2.googleapis.com/token"
      callback_path "/integrations/google/oauth/callback"
      token_field :access_token
      refresh_token_field :refresh_token
      setup :oauth2_authorization_code
      credential_fields [:access_token, :refresh_token]
      lease_fields [:access_token]

      scopes Jido.Connect.Google.Scopes.user_default() ++
               Jido.Connect.Google.Scopes.product(:sheets)

      default_scopes Jido.Connect.Google.Scopes.user_default()
      optional_scopes Jido.Connect.Google.Scopes.product(:sheets)
      pkce? true
      refresh? true
      revoke? true
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Google.Sheets.CatalogPacks, as: :all
  defdelegate readonly_pack, to: Jido.Connect.Google.Sheets.CatalogPacks, as: :readonly
  defdelegate writer_pack, to: Jido.Connect.Google.Sheets.CatalogPacks, as: :writer
end
