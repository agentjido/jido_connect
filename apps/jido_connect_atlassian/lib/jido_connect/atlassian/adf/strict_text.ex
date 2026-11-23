defmodule Jido.Connect.Atlassian.ADF.StrictText do
  @moduledoc false

  # The strict ADF-to-text rendering of the former `Jido.Connect.Confluence.ADF`,
  # moved without behavior changes. It fails the whole document on any node or
  # text mark outside the supported subset and on links that are not HTTPS. It
  # renders links without their target and flattens nested lists.

  alias Jido.Connect.Atlassian.ADF.Vocabulary

  @container_nodes Vocabulary.container_nodes()
  @formatting_marks Vocabulary.formatting_marks()

  @spec to_text(term()) :: {:ok, String.t()} | :error
  def to_text(%{"version" => 1, "type" => "doc", "content" => content})
      when is_list(content) do
    case render_nodes(content) do
      {:ok, text} -> {:ok, String.trim(text)}
      :error -> :error
    end
  end

  def to_text(_value), do: :error

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
        Vocabulary.https_url?(href)

      %{"type" => type} when type in @formatting_marks ->
        true

      _mark ->
        false
    end)
  end
end
