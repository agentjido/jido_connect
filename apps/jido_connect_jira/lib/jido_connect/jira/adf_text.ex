defmodule Jido.Connect.Jira.ADFText do
  @moduledoc """
  Renders Jira rich-text values with the shared Atlassian ADF projection.

  Jira REST v3 returns issue descriptions and comment bodies as ADF documents.
  Administrator webhooks send comment bodies as plain strings. This module
  projects ADF with `Jido.Connect.Atlassian.ADF.project/2` in `:degrade` mode
  and passes strings through unchanged:

    * `nil` returns `{:ok, nil}`.
    * A string returns it as `text` with no `unsupported_nodes`.
    * Any other value is projected. Unsupported node and mark types are
      skipped and listed; malformed content, including values that are not
      ADF documents, returns the projection's `Jido.Connect.Error.ValidationError`.
  """

  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Error

  @type projection :: %{text: String.t(), unsupported_nodes: [String.t()]}

  @doc "Projects a Jira rich-text value; see the module documentation."
  @spec project(term()) :: {:ok, projection() | nil} | {:error, Error.ValidationError.t()}
  def project(nil), do: {:ok, nil}
  def project(text) when is_binary(text), do: {:ok, %{text: text, unsupported_nodes: []}}
  def project(document), do: ADF.project(document, on_unsupported: :degrade)

  @doc "Returns the text of a projection, or `nil` for a missing value."
  @spec text(projection() | nil) :: String.t() | nil
  def text(nil), do: nil
  def text(%{text: text}), do: text

  @doc "Returns the skipped node and mark types of a projection, or `nil` for a missing value."
  @spec unsupported_nodes(projection() | nil) :: [String.t()] | nil
  def unsupported_nodes(nil), do: nil
  def unsupported_nodes(%{unsupported_nodes: types}), do: types
end
