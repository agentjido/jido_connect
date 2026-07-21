defmodule Jido.Connect.MicrosoftOnedrive.Privacy do
  @moduledoc """
  Microsoft OneDrive privacy boundary helpers.

  Drive item names, file content, and sharing metadata can contain personal or
  sensitive data. Full file content, sharing links with access tokens, and
  permission details are intentionally excluded from normalized metadata structs.
  """

  @storage_content_fields [
    :name,
    :size,
    :created_date_time,
    :last_modified_date_time,
    :web_url,
    :created_by,
    :last_modified_by
  ]

  @personal_data_fields [
    :display_name,
    :email,
    :name,
    :web_url,
    :created_by,
    :last_modified_by,
    :item_id,
    :parent_reference
  ]

  @raw_content_keys MapSet.new([
                      "content",
                      :content,
                      "@content.downloadUrl",
                      :"@content.downloadUrl"
                    ])

  @doc "Fields that should be treated as storage content."
  def storage_content_fields, do: @storage_content_fields

  @doc "Fields that should be treated as personal data."
  def personal_data_fields, do: @personal_data_fields

  @doc "Returns true for raw content or download URL keys that should not survive default normalization."
  def raw_content_key?(key), do: MapSet.member?(@raw_content_keys, key)
end
