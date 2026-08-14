defmodule Jido.Connect.Nextcloud.ScopeResolver do
  @moduledoc """
  Resolves package-level Nextcloud scope labels.

  Nextcloud app-password auth does not enforce provider-side scopes. These
  labels still give Jido hosts stable policy handles for least-privilege catalog
  packs and user consent.
  """

  @read "files:read"
  @write "files:write"
  @share "files:share"
  @office "office:launch"

  @write_actions MapSet.new([
                   "nextcloud.folder.create",
                   "nextcloud.file.upload",
                   "nextcloud.node.move",
                   "nextcloud.node.copy",
                   "nextcloud.node.delete"
                 ])

  @share_actions MapSet.new([
                   "nextcloud.shares.list",
                   "nextcloud.share.get",
                   "nextcloud.share.create",
                   "nextcloud.share.update",
                   "nextcloud.share.delete",
                   "nextcloud.sharees.search"
                 ])

  @office_actions MapSet.new([
                    "nextcloud.office.launch_token.get"
                  ])

  @doc "Returns required scope labels for an action and credential context."
  def required_scopes(action, _input, _context) do
    action_id = Map.get(action, :id) || Map.get(action, "id")

    cond do
      MapSet.member?(@write_actions, action_id) -> [@write]
      MapSet.member?(@share_actions, action_id) -> [@share]
      MapSet.member?(@office_actions, action_id) -> [@office]
      true -> [@read]
    end
  end
end
