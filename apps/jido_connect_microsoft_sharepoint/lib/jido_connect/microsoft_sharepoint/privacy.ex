defmodule Jido.Connect.MicrosoftSharepoint.Privacy do
  @moduledoc """
  Defines the SharePoint privacy boundary.

  List field values and file content are workspace content. Identity values can
  contain personal data. Raw file content and temporary download URLs must not
  enter telemetry or default metadata payloads.
  """

  @workspace_content_fields [
    :display_name,
    :description,
    :name,
    :fields,
    :content_type,
    :web_url
  ]

  @personal_data_fields [
    :display_name,
    :email,
    :created_by,
    :last_modified_by
  ]

  @raw_content_keys MapSet.new([
                      "content",
                      :content,
                      "contentBytes",
                      :contentBytes,
                      "@microsoft.graph.downloadUrl",
                      :"@microsoft.graph.downloadUrl"
                    ])

  @doc "Fields that can contain SharePoint workspace content."
  def workspace_content_fields, do: @workspace_content_fields

  @doc "Fields that can contain personal data."
  def personal_data_fields, do: @personal_data_fields

  @doc "Returns true for raw file content and temporary download URL keys."
  def raw_content_key?(key), do: MapSet.member?(@raw_content_keys, key)
end
