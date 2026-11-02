defmodule Jido.Connect.Atlassian.ADF do
  @default_max_depth 64
  @default_max_nodes 50_000
  @default_max_markdown_length 100_000

  @moduledoc """
  Atlassian Document Format (ADF) conversion shared by the Jira and Confluence
  packages.

  ## Projection to text

  `project/2` renders an ADF v1 document as plain text in one pass, in
  document order:

    * Paragraphs, headings and code blocks end a line. A hard break starts a
      new line.
    * List items start with `- `, or with their number in an ordered list,
      counted from `attrs.order` or 1. Nested lists and further lines of an
      item are indented under the item.
    * Text loses its formatting. Linked text is followed by its target in
      parentheses; when the text equals the target, only the target remains.
    * Mentions, emoji and status lozenges render their display text, inline
      cards their URL, a rule `---`.
    * Panels, block quotes, expands, layouts and tables render their content
      line by line.

  Leading and trailing blank lines are dropped. The supported node and mark
  types are those of `to_text/1`. Unlike `to_text/1`, links of any scheme keep
  their target, because the result is text and not markup.

  ## Unsupported content

  Other node and text mark types, such as `mediaSingle`, `media`,
  `extension`, `bodiedExtension`, `inlineExtension`, `date` and the
  `annotation` mark, are unsupported. So are a mention or emoji without
  display text, an inline card without URL and a link mark without target.
  Option `:on_unsupported` chooses the outcome:

    * `:fail`, the default, returns a `Jido.Connect.Error.ValidationError`
      with reason `:unsupported_adf_content`. Its `details.unsupported_nodes`
      names the types.
    * `:degrade` skips them and returns the remaining text. `unsupported_nodes`
      lists each skipped node or mark type once, in document order. Nodes
      inside a skipped node are skipped with it and not listed separately,
      so their text is missing as well: the body of a macro with content
      (`bodiedExtension`, such as an excerpt or page properties macro) and
      the caption of an image (`caption` inside `mediaSingle`) do not appear
      in the text.

  ## Malformed documents and limits

  In both modes a malformed document returns reason `:invalid_adf`, with
  `details.problem` naming the defect: `:doc_root` (no `doc` root with
  `version` 1), `:content` (content that is not a list), `:node` (a node that
  is not a map), `:node_type` (a node without a type name), `:text` (a text
  node without string text) or `:marks` (text marks that are not a list of
  typed maps). Missing or `null` marks count as no marks. A type name has at
  most 64 letters and digits.

  Two limits bound the work per document, in both modes and including the
  nodes inside skipped content:

    * nesting depth below the `doc` root, default #{@default_max_depth},
      reason `:adf_depth_limit_exceeded`;
    * node count including the `doc` root, without marks, default
      #{@default_max_nodes}, reason `:adf_node_limit_exceeded`.

  The defaults sit well above what issue descriptions, comments and pages
  usually contain. Pass `:max_depth` and `:max_nodes` per call, or change the
  defaults for all callers, including the Jira package:

      config :jido_connect_atlassian, Jido.Connect.Atlassian.ADF,
        max_depth: 32,
        max_nodes: 20_000

  Error details carry node types, defect names and limits, never document
  text.

  ## Strict text and Markdown

  `to_text/1` is the strict rendering that Confluence page reads use through
  `Jido.Connect.Confluence.ADF`. It fails the whole document on any node or
  text mark outside its supported subset and on links that are not HTTPS. It
  renders links without their target and flattens nested lists.

  `from_markdown/2` converts bounded Markdown into a fixed ADF v1 subset for
  paragraphs, headings, lists, block quotes, fenced code, hard line breaks,
  horizontal rules and HTTPS links.
  """

  alias Jido.Connect.Atlassian.ADF.{Markdown, Projection, StrictText}
  alias Jido.Connect.Error

  @typedoc "Text of a document and the node and mark types the projection skipped."
  @type projection :: %{text: String.t(), unsupported_nodes: [String.t()]}

  @type project_option ::
          {:on_unsupported, :fail | :degrade}
          | {:max_depth, pos_integer()}
          | {:max_nodes, pos_integer()}

  @doc """
  Projects an ADF v1 document to text.

  Returns `{:ok, %{text: text, unsupported_nodes: types}}` or
  `{:error, %Jido.Connect.Error.ValidationError{subject: :adf}}`. See the
  module documentation for the rendering, the modes and the limits.

  ## Options

    * `:on_unsupported` - `:fail` (default) or `:degrade`.
    * `:max_depth` - nesting depth limit; defaults to the configured or
      built-in default of #{@default_max_depth}.
    * `:max_nodes` - node count limit; defaults to the configured or built-in
      default of #{@default_max_nodes}.

  Unknown options and invalid values raise `ArgumentError`.
  """
  @spec project(term(), [project_option()]) ::
          {:ok, projection()} | {:error, Error.ValidationError.t()}
  def project(document, opts \\ []) when is_list(opts) do
    Projection.project(document, project_options(opts))
  end

  @doc """
  Returns the depth and node-count limits that `project/2` applies when the
  caller passes none: the application configuration if set, else the built-in
  defaults.
  """
  @spec default_limits() :: [max_depth: pos_integer(), max_nodes: pos_integer()]
  def default_limits do
    configured = Application.get_env(:jido_connect_atlassian, __MODULE__, [])

    [
      max_depth: Keyword.get(configured, :max_depth, @default_max_depth),
      max_nodes: Keyword.get(configured, :max_nodes, @default_max_nodes)
    ]
  end

  defp project_options(opts) do
    opts = Keyword.validate!(opts, [{:on_unsupported, :fail} | default_limits()])

    unless opts[:on_unsupported] in [:fail, :degrade] do
      raise ArgumentError,
            "expected :on_unsupported to be :fail or :degrade, got: #{inspect(opts[:on_unsupported])}"
    end

    Enum.each([:max_depth, :max_nodes], &positive_integer!(opts, &1))
    opts
  end

  defp positive_integer!(opts, key) do
    case Keyword.fetch!(opts, key) do
      value when is_integer(value) and value > 0 ->
        value

      value ->
        raise ArgumentError,
              "expected #{inspect(key)} to be a positive integer, got: #{inspect(value)}"
    end
  end

  @doc """
  Renders an ADF v1 document as text with the strict rendering.

  Returns `:error` for a document outside the supported subset.
  """
  @spec to_text(term()) :: {:ok, String.t()} | :error
  defdelegate to_text(document), to: StrictText

  @doc """
  Converts bounded Markdown into an ADF v1 document.

  Option `:max_length` bounds the input in characters; the default is
  #{@default_max_markdown_length}. Longer input and non-strings return `:error`.
  Unknown options and a `:max_length` that is not a positive integer raise
  `ArgumentError`.
  """
  @spec from_markdown(term(), [{:max_length, pos_integer()}]) :: {:ok, map()} | :error
  def from_markdown(markdown, opts \\ []) when is_list(opts) do
    max_length =
      opts
      |> Keyword.validate!(max_length: @default_max_markdown_length)
      |> positive_integer!(:max_length)

    Markdown.from_markdown(markdown, max_length)
  end
end
