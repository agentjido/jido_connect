defmodule Jido.Connect.Nextcloud.Client.XML do
  @moduledoc false

  @doc "Parses XML into a simple map/list tree using xmerl."
  def parse_document(xml) when is_binary(xml) do
    xml = String.to_charlist(xml)

    try do
      {doc, _rest} = :xmerl_scan.string(xml, namespace_conformant: true, quiet: true)
      {:ok, element(doc)}
    catch
      :exit, reason -> {:error, reason}
      kind, reason -> {:error, {kind, reason}}
    end
  end

  def parse_document(_xml), do: {:error, :invalid_xml}

  def text(%{children: children}) do
    children
    |> Enum.map(fn
      value when is_binary(value) -> value
      _other -> ""
    end)
    |> Enum.join()
    |> String.trim()
  end

  def children(%{children: children}, local_name) do
    Enum.filter(children, fn
      %{local_name: ^local_name} -> true
      _other -> false
    end)
  end

  def children(_element, _local_name), do: []

  def child(element, local_name) do
    element
    |> children(local_name)
    |> List.first()
  end

  def child_text(element, local_name, default \\ nil) do
    case child(element, local_name) do
      nil -> default
      child -> text(child)
    end
  end

  def deep_text(element, local_name, default \\ nil) do
    case find_deep(element, local_name) do
      nil -> default
      child -> text(child)
    end
  end

  def find_deep(%{local_name: local_name} = element, local_name), do: element

  def find_deep(%{children: children}, local_name) do
    Enum.find_value(children, fn
      %{local_name: _} = child -> find_deep(child, local_name)
      _other -> nil
    end)
  end

  def find_deep(_element, _local_name), do: nil

  def elements_by_name(%{local_name: local_name} = element, local_name), do: [element]

  def elements_by_name(%{children: children}, local_name) do
    Enum.flat_map(children, fn
      %{local_name: _} = child -> elements_by_name(child, local_name)
      _other -> []
    end)
  end

  def elements_by_name(_element, _local_name), do: []

  defp element(
         {:xmlElement, name, expanded_name, _nsinfo, _namespace, _parents, _pos, attrs, children,
          _lang, _xmlbase, _elementdef}
       ) do
    %{
      name: to_string(name),
      local_name: local_name(name, expanded_name),
      attributes: attributes(attrs),
      children: Enum.flat_map(children, &child/1)
    }
  end

  defp child({:xmlElement, _, _, _, _, _, _, _, _, _, _, _} = element), do: [element(element)]

  defp child({:xmlText, _parents, _pos, _language, value, :text}) do
    value = value |> to_string()

    if String.trim(value) == "" do
      []
    else
      [value]
    end
  end

  defp child(_other), do: []

  defp attributes(attrs) do
    Map.new(attrs, fn {:xmlAttribute, name, _expanded_name, _nsinfo, _namespace, _parents, _pos,
                       _lang, value, _normalized} ->
      {to_string(name), to_string(value)}
    end)
  end

  defp local_name(_name, {_, local}) when is_atom(local), do: Atom.to_string(local)
  defp local_name(_name, {_, local}) when is_binary(local), do: local

  defp local_name(name, _expanded_name) do
    name
    |> to_string()
    |> String.split(":", parts: 2)
    |> List.last()
  end
end
