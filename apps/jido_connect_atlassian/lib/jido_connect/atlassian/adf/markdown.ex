defmodule Jido.Connect.Atlassian.ADF.Markdown do
  @moduledoc false

  # Bounded Markdown-to-ADF conversion, moved unchanged from the Confluence
  # package. The length bound is now a parameter; `Jido.Connect.Atlassian.ADF`
  # supplies the default and Confluence passes its own contract value.

  alias Jido.Connect.Atlassian.ADF.Vocabulary

  @markdown_link ~r/\[([^\]\r\n]+)\]\((https:\/\/[^\s\)]+)\)/

  @spec from_markdown(term(), pos_integer()) :: {:ok, map()} | :error
  def from_markdown(markdown, max_length) when is_binary(markdown) do
    if String.length(markdown) <= max_length do
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

  def from_markdown(_markdown, _max_length), do: :error

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

        if Vocabulary.https_url?(url) do
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
end
