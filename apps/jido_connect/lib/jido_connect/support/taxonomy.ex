defmodule Jido.Connect.Taxonomy do
  @moduledoc """
  Shared catalog vocabulary for provider DSLs and generated metadata.

  This module intentionally keeps the first vocabulary small. Connector packages
  should prefer these values so host UIs can group, search, and filter hundreds
  of integrations consistently.
  """

  @categories [
    :accounting,
    :calendar,
    :collaboration,
    :crm,
    :customer_support,
    :data,
    :developer_tools,
    :ecommerce,
    :email,
    :file_storage,
    :hr,
    :marketing,
    :messaging,
    :payments,
    :productivity,
    :project_management,
    :sales,
    :security,
    :social,
    :task_management,
    :tool_bridge,
    :test
  ]

  @statuses [:available, :planned, :experimental, :deprecated]
  @visibilities [:public, :private, :internal]

  @verbs [
    :append,
    :archive,
    :call,
    :cancel,
    :clear,
    :create,
    :delete,
    :dispatch,
    :download,
    :get,
    :list,
    :merge,
    :poll,
    :read,
    :search,
    :send,
    :share,
    :sync,
    :unarchive,
    :update,
    :upload,
    :watch
  ]

  @data_classifications [
    :external_tool_input,
    :financial_data,
    :identity,
    :message_content,
    :personal_data,
    :tool_metadata,
    :workspace_content,
    :workspace_metadata
  ]

  @risks [:metadata, :read, :write, :external_write, :destructive]
  @confirmations [:none, :required_for_ai, :always]

  def categories, do: @categories
  def statuses, do: @statuses
  def visibilities, do: @visibilities
  def verbs, do: @verbs
  def data_classifications, do: @data_classifications
  def risks, do: @risks
  def confirmations, do: @confirmations

  def known_category?(nil), do: true
  def known_category?(category), do: category in @categories

  def known_status?(status), do: status in @statuses
  def known_visibility?(visibility), do: visibility in @visibilities

  def known_verb?(nil), do: false
  def known_verb?(verb), do: verb in @verbs

  def known_data_classification?(nil), do: false
  def known_data_classification?(classification), do: classification in @data_classifications

  def known_risk?(risk), do: risk in @risks
  def known_confirmation?(confirmation), do: confirmation in @confirmations
end
