defmodule Jido.Connect.Things do
  @moduledoc """
  Experimental Things Cloud Inbox integration.

  Things Cloud does not publish or support the write protocol used by this
  package. A protocol change can corrupt or lose data. The provider fails
  closed when the endpoint, account, schema, history head, or prepared plan
  differs from the reviewed contract.

  Direct mutation is always denied. Use `prepare/3` and `commit/3` for create
  and update actions.
  """

  use Jido.Connect, fragments: [Jido.Connect.Things.Actions.Todos]

  integration do
    id :things
    name "Things Cloud"

    description "Experimental Inbox task tools for the unofficial Things Cloud protocol."

    category :task_management
    docs ["https://culturedcode.com/things/cloud/"]
  end

  catalog do
    package :jido_connect_things
    status :experimental
    tags [:tasks, :personal_productivity, :unofficial_api]
  end

  auth do
    api_key :things_cloud_password do
      default? true
      owner :app_user
      subject :user
      label "Things Cloud account"
      setup :things_cloud_password
      credential_fields [:email, :password]
      lease_fields [:email, :password]
    end
  end

  @doc "Prepares one guarded Things write with provider state reads only."
  defdelegate prepare(action_id, input, opts), to: Jido.Connect.Things.Runtime

  @doc "Commits one exact prepared Things write after all checks pass."
  defdelegate commit(prepared, input, opts), to: Jido.Connect.Things.Runtime

  @doc "Invokes the read action with optional ephemeral test or host adapters."
  defdelegate invoke(action_id, input, opts), to: Jido.Connect.Things.Runtime

  defdelegate catalog_packs, to: Jido.Connect.Things.CatalogPacks, as: :all
  defdelegate inbox_reader_pack, to: Jido.Connect.Things.CatalogPacks, as: :reader
  defdelegate inbox_editor_pack, to: Jido.Connect.Things.CatalogPacks, as: :editor
end
