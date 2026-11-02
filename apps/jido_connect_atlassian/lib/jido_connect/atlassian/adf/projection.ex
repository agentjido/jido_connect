defmodule Jido.Connect.Atlassian.ADF.Projection do
  @moduledoc false

  # One pass over an ADF document that renders the supported subset as text,
  # records each unsupported node or text mark type once, and enforces the
  # depth and node-count limits. See `Jido.Connect.Atlassian.ADF.project/2`
  # for the contract.
  #
  # Every node is visited, including the nodes inside a skipped unsupported
  # node, so that structure checks and limits cover the whole document in both
  # modes. Rendering produces fragments:
  #
  #   {:inline, text}        inline text without a link
  #   {:link, text, href}    inline text under a link mark
  #   {:lines, lines}        block content as a list of lines
  #   {:list, lines}         a rendered list; a directly enclosing list
  #                          indents it under the item before it
  #   {:item, lines}         a list item; the enclosing list adds its marker
  #   :none                  a skipped node

  alias Jido.Connect.Atlassian.ADF.Vocabulary
  alias Jido.Connect.Error

  @type_name ~r/\A[A-Za-z][A-Za-z0-9]{0,63}\z/

  @list_nodes ~w(bulletList orderedList taskList decisionList)
  @item_nodes ~w(listItem taskItem decisionItem)
  @line_nodes ~w(paragraph heading codeBlock)
  @block_nodes Vocabulary.container_nodes() -- (@list_nodes ++ @item_nodes ++ @line_nodes)
  @formatting_marks Vocabulary.formatting_marks()

  defstruct [:mode, :max_depth, :max_nodes, nodes: 0, unsupported: [], seen: MapSet.new()]

  @type result :: %{text: String.t(), unsupported_nodes: [String.t()]}

  @spec project(term(), keyword()) :: {:ok, result()} | {:error, Error.ValidationError.t()}
  def project(%{"type" => "doc", "version" => 1} = document, opts) do
    state = %__MODULE__{
      mode: Keyword.fetch!(opts, :on_unsupported),
      max_depth: Keyword.fetch!(opts, :max_depth),
      max_nodes: Keyword.fetch!(opts, :max_nodes)
    }

    with {:ok, content} <- document_content(document),
         {:ok, state} <- count_node(state),
         {:ok, fragments, state} <- render_nodes(content, 1, state) do
      fragments
      |> lines()
      |> trim_blank_lines()
      |> Enum.join("\n")
      |> finish(state)
    end
  end

  def project(_document, _opts), do: malformed(:doc_root)

  defp document_content(%{"content" => content}) when is_list(content), do: {:ok, content}
  defp document_content(_document), do: malformed(:content)

  defp finish(_text, %__MODULE__{mode: :fail, unsupported: [_ | _]} = state) do
    {:error,
     Error.validation("ADF document contains unsupported content",
       reason: :unsupported_adf_content,
       subject: :adf,
       details: %{unsupported_nodes: Enum.reverse(state.unsupported)}
     )}
  end

  defp finish(text, %__MODULE__{} = state),
    do: {:ok, %{text: text, unsupported_nodes: Enum.reverse(state.unsupported)}}

  # Walking

  defp render_nodes(nodes, depth, state) do
    nodes
    |> Enum.reduce_while({:ok, [], state}, fn node, {:ok, fragments, state} ->
      case render_node(node, depth, state) do
        {:ok, fragment, state} -> {:cont, {:ok, [fragment | fragments], state}}
        {:error, _error} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, fragments, state} -> {:ok, Enum.reverse(fragments), state}
      {:error, _error} = error -> error
    end
  end

  defp render_node(node, depth, state) do
    with {:ok, type, content, state} <- visit(node, depth, state) do
      render(type, node, content, depth + 1, state)
    end
  end

  defp scan_nodes(nodes, depth, state) do
    Enum.reduce_while(nodes, {:ok, state}, fn node, {:ok, state} ->
      with {:ok, _type, content, state} <- visit(node, depth, state),
           {:ok, state} <- scan_nodes(content, depth + 1, state) do
        {:cont, {:ok, state}}
      else
        {:error, _error} = error -> {:halt, error}
      end
    end)
  end

  defp visit(node, depth, state) do
    with :ok <- within_depth(depth, state),
         {:ok, state} <- count_node(state),
         {:ok, type} <- node_type(node),
         {:ok, content} <- node_content(node),
         :ok <- text_shape(type, node) do
      {:ok, type, content, state}
    end
  end

  defp within_depth(depth, %__MODULE__{max_depth: max_depth}) when depth > max_depth do
    {:error,
     Error.validation("ADF document exceeds the nesting depth limit",
       reason: :adf_depth_limit_exceeded,
       subject: :adf,
       details: %{max_depth: max_depth}
     )}
  end

  defp within_depth(_depth, _state), do: :ok

  defp count_node(%__MODULE__{nodes: nodes, max_nodes: max_nodes}) when nodes >= max_nodes do
    {:error,
     Error.validation("ADF document exceeds the node count limit",
       reason: :adf_node_limit_exceeded,
       subject: :adf,
       details: %{max_nodes: max_nodes}
     )}
  end

  defp count_node(%__MODULE__{} = state), do: {:ok, %{state | nodes: state.nodes + 1}}

  defp node_type(%{"type" => type}) when is_binary(type) do
    if Regex.match?(@type_name, type), do: {:ok, type}, else: malformed(:node_type)
  end

  defp node_type(node) when is_map(node), do: malformed(:node_type)
  defp node_type(_node), do: malformed(:node)

  defp node_content(%{"content" => content}) when is_list(content), do: {:ok, content}
  defp node_content(%{"content" => _content}), do: malformed(:content)
  defp node_content(_node), do: {:ok, []}

  defp text_shape("text", node) do
    with :ok <- text_value(Map.get(node, "text")) do
      marks_shape(text_marks_of(node))
    end
  end

  defp text_shape(_type, _node), do: :ok

  defp text_value(text) when is_binary(text), do: :ok
  defp text_value(_text), do: malformed(:text)

  # A missing or null `marks` means no marks, as in the strict rendering. Any
  # other value must pass `marks_shape/1`.
  defp text_marks_of(node) do
    case Map.get(node, "marks") do
      nil -> []
      marks -> marks
    end
  end

  defp marks_shape(marks) when is_list(marks) do
    if Enum.all?(marks, &mark_shape?/1), do: :ok, else: malformed(:marks)
  end

  defp marks_shape(_marks), do: malformed(:marks)

  defp mark_shape?(%{"type" => type}) when is_binary(type), do: Regex.match?(@type_name, type)
  defp mark_shape?(_mark), do: false

  # Rendering

  defp render("text", node, content, depth, state) do
    {href, state} = text_marks(text_marks_of(node), state)
    text = Map.fetch!(node, "text")
    fragment = if href, do: {:link, text, href}, else: {:inline, text}
    leaf(fragment, content, depth, state)
  end

  defp render("hardBreak", _node, content, depth, state),
    do: leaf({:inline, "\n"}, content, depth, state)

  defp render("rule", _node, content, depth, state),
    do: leaf({:lines, ["---"]}, content, depth, state)

  defp render(type, _node, content, depth, state) when type in @line_nodes do
    with {:ok, fragments, state} <- render_nodes(content, depth, state) do
      {:ok, {:lines, at_least_one_line(lines(fragments))}, state}
    end
  end

  defp render(type, _node, content, depth, state) when type in @item_nodes do
    with {:ok, fragments, state} <- render_nodes(content, depth, state) do
      {:ok, {:item, lines(fragments)}, state}
    end
  end

  defp render("orderedList", node, content, depth, state) do
    with {:ok, fragments, state} <- render_nodes(content, depth, state) do
      {:ok, {:list, list_lines(fragments, first_number(node))}, state}
    end
  end

  defp render(type, _node, content, depth, state) when type in @list_nodes do
    with {:ok, fragments, state} <- render_nodes(content, depth, state) do
      {:ok, {:list, list_lines(fragments, nil)}, state}
    end
  end

  defp render(type, _node, content, depth, state) when type in @block_nodes do
    with {:ok, fragments, state} <- render_nodes(content, depth, state) do
      {:ok, {:lines, lines(fragments)}, state}
    end
  end

  defp render(type, node, content, depth, state) when type in ~w(emoji mention status) do
    case node do
      %{"attrs" => %{"text" => text}} when is_binary(text) ->
        leaf({:inline, text}, content, depth, state)

      %{"attrs" => %{"shortName" => text}} when is_binary(text) ->
        leaf({:inline, text}, content, depth, state)

      _node ->
        skip(type, content, depth, state)
    end
  end

  defp render("inlineCard", %{"attrs" => %{"url" => url}}, content, depth, state)
       when is_binary(url),
       do: leaf({:inline, url}, content, depth, state)

  defp render(type, _node, content, depth, state), do: skip(type, content, depth, state)

  # Leaf nodes have no content to render, but any content they carry still
  # counts against the limits and must be well formed.
  defp leaf(fragment, content, depth, state) do
    with {:ok, state} <- scan_nodes(content, depth, state), do: {:ok, fragment, state}
  end

  defp skip(type, content, depth, state) do
    with {:ok, state} <- scan_nodes(content, depth, note_unsupported(state, type)),
         do: {:ok, :none, state}
  end

  # Returns the link target of a text node, if any, and records unsupported
  # marks. A link mark without a usable target is unsupported; the text stays.
  defp text_marks(marks, state), do: Enum.reduce(marks, {nil, state}, &text_mark/2)

  defp text_mark(%{"type" => "link"} = mark, {href, state}) do
    case link_href(mark) do
      nil -> {href, note_unsupported(state, "link")}
      target -> {href || target, state}
    end
  end

  defp text_mark(%{"type" => type}, {href, state}) when type in @formatting_marks,
    do: {href, state}

  defp text_mark(%{"type" => type}, {href, state}), do: {href, note_unsupported(state, type)}

  defp link_href(%{"attrs" => %{"href" => href}}) when is_binary(href) and href != "", do: href
  defp link_href(_mark), do: nil

  defp note_unsupported(%__MODULE__{} = state, type) do
    if MapSet.member?(state.seen, type) do
      state
    else
      %{state | unsupported: [type | state.unsupported], seen: MapSet.put(state.seen, type)}
    end
  end

  defp first_number(%{"attrs" => %{"order" => order}}) when is_integer(order) and order >= 0,
    do: order

  defp first_number(_node), do: 1

  # Lines

  defp lines(fragments) do
    fragments
    |> Enum.reject(&(&1 == :none))
    |> Enum.chunk_by(&inline?/1)
    |> Enum.flat_map(fn [first | _rest] = chunk ->
      if inline?(first), do: inline_lines(chunk), else: Enum.flat_map(chunk, &block_lines/1)
    end)
  end

  defp inline?({:inline, _text}), do: true
  defp inline?({:link, _text, _href}), do: true
  defp inline?(_fragment), do: false

  defp block_lines({:lines, lines}), do: lines
  defp block_lines({:list, lines}), do: lines
  defp block_lines({:item, lines}), do: item_lines(lines, "- ")

  defp inline_lines(fragments) do
    fragments
    |> merge_links()
    |> Enum.map(&inline_text/1)
    |> IO.iodata_to_binary()
    |> String.split("\n")
  end

  defp merge_links(fragments) do
    fragments
    |> Enum.reduce([], fn
      {:link, text, href}, [{:link, previous, href} | rest] ->
        [{:link, previous <> text, href} | rest]

      fragment, acc ->
        [fragment | acc]
    end)
    |> Enum.reverse()
  end

  defp inline_text({:inline, text}), do: text
  defp inline_text({:link, href, href}), do: href
  defp inline_text({:link, text, href}), do: [text, " (", href, ")"]

  # A list directly inside a list, as ADF nests task lists, is indented under
  # the item before it, like a list inside a list item.
  defp list_lines(fragments, number) do
    {lines, _acc} =
      fragments
      |> Enum.reject(&(&1 == :none))
      |> Enum.flat_map_reduce({number, marker(number)}, fn
        {:item, lines}, {number, _marker} ->
          marker = marker(number)
          {item_lines(lines, marker), {next_number(number), marker}}

        {:list, lines}, {_number, marker} = acc ->
          {indent(lines, marker), acc}

        fragment, acc ->
          {lines([fragment]), acc}
      end)

    lines
  end

  defp marker(nil), do: "- "
  defp marker(number), do: "#{number}. "

  defp next_number(nil), do: nil
  defp next_number(number), do: number + 1

  defp item_lines([], marker), do: [String.trim_trailing(marker)]
  defp item_lines(["" | rest], marker), do: [String.trim_trailing(marker) | indent(rest, marker)]
  defp item_lines([first | rest], marker), do: [marker <> first | indent(rest, marker)]

  defp indent(lines, marker) do
    padding = String.duplicate(" ", String.length(marker))

    Enum.map(lines, fn
      "" -> ""
      line -> padding <> line
    end)
  end

  defp at_least_one_line([]), do: [""]
  defp at_least_one_line(lines), do: lines

  defp trim_blank_lines(lines) do
    lines
    |> Enum.drop_while(&blank?/1)
    |> Enum.reverse()
    |> Enum.drop_while(&blank?/1)
    |> Enum.reverse()
  end

  defp blank?(line), do: String.trim(line) == ""

  defp malformed(problem) do
    {:error,
     Error.validation("ADF document is malformed",
       reason: :invalid_adf,
       subject: :adf,
       details: %{problem: problem}
     )}
  end
end
