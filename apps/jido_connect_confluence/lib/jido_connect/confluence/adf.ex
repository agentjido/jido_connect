defmodule Jido.Connect.Confluence.ADF do
  @moduledoc """
  Confluence entry point for `Jido.Connect.Atlassian.ADF`.

  `to_text/1` delegates unchanged. `from_markdown/1` delegates with the
  Confluence Markdown length limit of 100,000 characters.
  """

  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Confluence.Contract

  @doc "See `Jido.Connect.Atlassian.ADF.from_markdown/2`."
  @spec from_markdown(String.t()) :: {:ok, map()} | :error
  def from_markdown(markdown),
    do: ADF.from_markdown(markdown, max_length: Contract.maximum_markdown_length())

  @doc "See `Jido.Connect.Atlassian.ADF.to_text/1`."
  @spec to_text(map()) :: {:ok, String.t()} | :error
  defdelegate to_text(document), to: ADF
end
