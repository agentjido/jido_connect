defmodule Jido.Connect.Confluence.ADF do
  @moduledoc "Bounded Markdown-to-ADF and strict ADF-to-text conversion."

  alias Jido.Connect.Confluence.Contract

  @markdown_link ~r/\[([^\]\r\n]+)\]\((https:\/\/[^\s\)]+)\)/
  @container_nodes ~w(
    blockquote bulletList decisionItem decisionList expand layoutColumn layoutSection
    listItem nestedExpand orderedList panel paragraph table tableCell tableHeader tableRow
    taskItem taskList
  )

  @spec from_markdown(String.t()) :: {:ok, map()} | :error
  def from_markdown(markdown) when is_binary(markdown) do
    if String.length(markdown) <= Contract.maximum_markdown_length() do
      content =
        markdown
        |> String.replace("\r\n", "\n")
        |> String.trim()
        |> blocks()
        |> Enum.map(&block/1)

      {:ok, %{"version" => 1, "type" => "doc", "content" => content}}
    else
      :error
    end
  end

  def from_markdown(_markdown), do: :error

  @spec to_text(map()) :: {:ok, String.t()} | :error
  def to_text(%{"version" => 1, "type" => "doc", "content" => content})
      when is_list(content) do
    case render_nodes(content) do
      {:ok, text} -> {:ok, String.trim(text)}
      :error -> :error
    end
  end

  def to_text(_value), do: :error

  defp blocks(""), do: []
  defp blocks(markdown), do: Regex.split(~r/\n[ \t]*\n+/, markdown, trim: true)

  defp block(value) do
    lines = String.split(value, "\n")

    cond do
      fenced_code?(lines) ->
        code_block(lines)

      heading?(lines) ->
        heading(hd(lines))

      list?(lines, ~r/^[ \t]*[-*][ \t]+/) ->
        list(lines, "bulletList", ~r/^[ \t]*[-*][ \t]+/)

      list?(lines, ~r/^[ \t]*[0-9]+\.[ \t]+/) ->
        list(lines, "orderedList", ~r/^[ \t]*[0-9]+\.[ \t]+/)

      quote?(lines) ->
        quote_block(lines)

      value == "---" ->
        %{"type" => "rule"}

      true ->
        paragraph(lines)
    end
  end

  defp fenced_code?([first | _rest] = lines) do
    String.starts_with?(first, "```") and String.trim(List.last(lines)) == "```"
  end

  defp fenced_code?([]), do: false

  defp code_block([first | rest]) do
    language = first |> String.trim_leading("```") |> String.trim()
    content = rest |> Enum.drop(-1) |> Enum.join("\n")
    node = %{"type" => "codeBlock", "content" => text_content(content)}
    if language == "", do: node, else: Map.put(node, "attrs", %{"language" => language})
  end

  defp heading?([line]), do: Regex.match?(~r/^[#]{1,6}[ \t]+\S/, line)
  defp heading?(_lines), do: false

  defp heading(line) do
    [markers, text] = Regex.run(~r/^([#]{1,6})[ \t]+(.+)$/, line, capture: :all_but_first)

    %{
      "type" => "heading",
      "attrs" => %{"level" => String.length(markers)},
      "content" => text_content(text)
    }
  end

  defp list?(lines, pattern), do: lines != [] and Enum.all?(lines, &Regex.match?(pattern, &1))

  defp list(lines, type, pattern) do
    items =
      Enum.map(lines, fn line ->
        text = Regex.replace(pattern, line, "")

        %{
          "type" => "listItem",
          "content" => [%{"type" => "paragraph", "content" => text_content(text)}]
        }
      end)

    %{"type" => type, "content" => items}
  end

  defp quote?(lines), do: lines != [] and Enum.all?(lines, &Regex.match?(~r/^[ \t]*>[ \t]?/, &1))

  defp quote_block(lines) do
    text = lines |> Enum.map(&Regex.replace(~r/^[ \t]*>[ \t]?/, &1, "")) |> Enum.join("\n")
    %{"type" => "blockquote", "content" => [paragraph(String.split(text, "\n"))]}
  end

  defp paragraph(lines) do
    content = lines |> Enum.map(&text_content/1) |> Enum.intersperse([%{"type" => "hardBreak"}])
    %{"type" => "paragraph", "content" => List.flatten(content)}
  end

  defp text_content(""), do: []

  defp text_content(text) do
    case Regex.run(@markdown_link, text, return: :index) do
      [{start, length}, {label_start, label_length}, {url_start, url_length}] ->
        prefix = binary_part(text, 0, start)
        label = binary_part(text, label_start, label_length)
        url = binary_part(text, url_start, url_length)
        rest_start = start + length
        rest = binary_part(text, rest_start, byte_size(text) - rest_start)

        if safe_https_url?(url) do
          plain_text(prefix) ++
            [
              %{
                "type" => "text",
                "text" => label,
                "marks" => [%{"type" => "link", "attrs" => %{"href" => url}}]
              }
            ] ++ text_content(rest)
        else
          plain_text(prefix <> binary_part(text, start, length)) ++ text_content(rest)
        end

      nil ->
        plain_text(text)
    end
  end

  defp plain_text(""), do: []
  defp plain_text(text), do: [%{"type" => "text", "text" => text}]

  defp safe_https_url?(url) do
    uri = URI.parse(url)

    uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and is_nil(uri.userinfo) and
      uri.port == 443
  end

  defp render_nodes(nodes) do
    Enum.reduce_while(nodes, {:ok, []}, fn node, {:ok, output} ->
      case render_node(node) do
        {:ok, text} -> {:cont, {:ok, [text | output]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, output} -> {:ok, output |> Enum.reverse() |> IO.iodata_to_binary()}
      :error -> :error
    end
  end

  defp render_node(%{"type" => "text", "text" => text} = node) when is_binary(text) do
    case Map.get(node, "marks") do
      nil -> {:ok, text}
      marks when is_list(marks) -> if valid_marks?(marks), do: {:ok, text}, else: :error
      _marks -> :error
    end
  end

  defp render_node(%{"type" => "hardBreak"}), do: {:ok, "\n"}
  defp render_node(%{"type" => "rule"}), do: {:ok, "---\n"}

  defp render_node(%{"type" => "heading", "attrs" => %{"level" => level}, "content" => content})
       when level in 1..6 and is_list(content),
       do: render_container(content, "\n")

  defp render_node(%{"type" => "codeBlock", "content" => content}) when is_list(content),
    do: render_container(content, "\n")

  defp render_node(%{"type" => "listItem", "content" => content}) when is_list(content) do
    case render_nodes(content) do
      {:ok, text} -> {:ok, "- " <> String.trim(text) <> "\n"}
      :error -> :error
    end
  end

  defp render_node(%{"type" => type, "content" => content})
       when type in @container_nodes and is_list(content) do
    suffix = if type in ~w(paragraph blockquote panel expand nestedExpand), do: "\n", else: ""
    render_container(content, suffix)
  end

  defp render_node(%{"type" => type, "attrs" => attrs})
       when type in ["emoji", "mention", "status"] and is_map(attrs) do
    text = Map.get(attrs, "text") || Map.get(attrs, "shortName")
    if is_binary(text), do: {:ok, text}, else: :error
  end

  defp render_node(%{"type" => "inlineCard", "attrs" => %{"url" => url}})
       when is_binary(url),
       do: {:ok, url}

  defp render_node(_node), do: :error

  defp render_container(content, suffix) do
    case render_nodes(content) do
      {:ok, text} -> {:ok, text <> suffix}
      :error -> :error
    end
  end

  defp valid_marks?(marks) do
    Enum.all?(marks, fn
      %{"type" => "link", "attrs" => %{"href" => href}} ->
        safe_https_url?(href)

      %{"type" => type}
      when type in ~w(backgroundColor code em strike strong subsup textColor underline) ->
        true

      _mark ->
        false
    end)
  end
end
