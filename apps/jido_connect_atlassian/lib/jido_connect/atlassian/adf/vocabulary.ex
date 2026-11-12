defmodule Jido.Connect.Atlassian.ADF.Vocabulary do
  @moduledoc false

  # The ADF node and mark types that both text renderings support, and the
  # HTTPS check that the strict rendering and the Markdown conversion apply to
  # links. Keeping them in one place keeps `to_text/1` and `project/2` on the
  # same supported subset.

  @container_nodes ~w(
    blockquote bulletList decisionItem decisionList expand layoutColumn layoutSection
    listItem nestedExpand orderedList panel paragraph table tableCell tableHeader tableRow
    taskItem taskList
  )

  @formatting_marks ~w(backgroundColor code em strike strong subsup textColor underline)

  @doc "Container node types whose content both renderings walk."
  @spec container_nodes() :: [String.t()]
  def container_nodes, do: @container_nodes

  @doc "Text mark types that change formatting only and carry no text."
  @spec formatting_marks() :: [String.t()]
  def formatting_marks, do: @formatting_marks

  @doc "Returns whether `url` is an absolute HTTPS URL on the default port without user info."
  @spec https_url?(term()) :: boolean()
  def https_url?(url) when is_binary(url) do
    uri = URI.parse(url)

    uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and is_nil(uri.userinfo) and
      uri.port == 443
  end

  def https_url?(_url), do: false
end
