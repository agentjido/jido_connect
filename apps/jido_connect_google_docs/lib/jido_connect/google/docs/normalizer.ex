defmodule Jido.Connect.Google.Docs.Normalizer do
  @moduledoc "Normalizes Google Docs API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Google.Docs.{
    Document,
    DocumentRequest,
    DocumentResult,
    Tab
  }

  @doc """
  Normalizes a Google Docs document payload.

  Returns an error when a tab at any depth does not have the provider's shape.
  """
  @spec document(map()) :: {:ok, Document.t()} | {:error, term()}
  def document(payload) when is_map(payload) do
    with {:ok, tabs} <- normalize_tabs(Data.get(payload, "tabs", [])) do
      %{
        document_id: Data.get(payload, "documentId"),
        title: Data.get(payload, "title"),
        revision_id: Data.get(payload, "revisionId"),
        suggestions_view_mode: Data.get(payload, "suggestionsViewMode"),
        body: Data.get(payload, "body"),
        document_style: Data.get(payload, "documentStyle"),
        tabs: tabs,
        named_styles: Data.get(payload, "namedStyles")
      }
      |> Data.compact()
      |> Document.new()
    end
  end

  @doc """
  Normalizes a Google Docs tab payload.

  Reads `tabProperties.tabId`, `tabProperties.title`, `documentTab.body` and
  the nested `childTabs`. A tab that is not a map, or whose properties,
  document tab or child tabs do not have the provider's shape, returns an
  error.
  """
  @spec tab(term()) :: {:ok, Tab.t()} | {:error, term()}
  def tab(payload) when is_map(payload) do
    with {:ok, tab_properties} <- tab_section(payload, "tabProperties"),
         {:ok, document_tab} <- tab_section(payload, "documentTab"),
         {:ok, child_tabs} <- normalize_tabs(Data.get(payload, "childTabs", [])) do
      %{
        tab_id: Data.get(tab_properties, "tabId"),
        title: Data.get(tab_properties, "title"),
        body: Data.get(document_tab, "body"),
        child_tabs: child_tabs
      }
      |> Data.compact()
      |> Tab.new()
    end
  end

  def tab(_payload), do: {:error, :invalid_tab_payload}

  @doc "Normalizes a Google Docs document create/update request payload."
  @spec document_request(map()) :: {:ok, DocumentRequest.t()} | {:error, term()}
  def document_request(payload) when is_map(payload) do
    %{
      title: Data.get(payload, "title"),
      body: Data.get(payload, "body"),
      revision_id: Data.get(payload, "revisionId")
    }
    |> Data.compact()
    |> DocumentRequest.new()
  end

  @doc "Normalizes a Google Docs document read/create result payload."
  @spec document_result(map()) :: {:ok, DocumentResult.t()} | {:error, term()}
  def document_result(payload) when is_map(payload) do
    %{
      document_id: Data.get(payload, "documentId"),
      title: Data.get(payload, "title"),
      revision_id: Data.get(payload, "revisionId")
    }
    |> Data.compact()
    |> DocumentResult.new()
  end

  @doc """
  Normalizes a Google Docs batch update result payload.

  Keeps `documentId`, the `replies` and Google's `writeControl` object as
  returned. Google's response has no document; an inline `document` that is
  not a map, or that has a tab at any depth without the provider's shape,
  returns an error.
  """
  @spec batch_update_result(map()) :: {:ok, map()} | {:error, term()}
  def batch_update_result(payload) when is_map(payload) do
    with {:ok, document} <- inline_document(Data.get(payload, "document")) do
      replies =
        payload
        |> Data.get("replies", [])
        |> Enum.map(&public_map/1)

      {:ok,
       Data.compact(%{
         document_id: Data.get(payload, "documentId"),
         replies: replies,
         write_control: Data.get(payload, "writeControl"),
         document: document
       })}
    end
  end

  defp inline_document(nil), do: {:ok, nil}

  defp inline_document(payload) when is_map(payload) do
    with {:ok, document} <- document(payload), do: {:ok, public_map(document)}
  end

  defp inline_document(_payload), do: {:error, :invalid_document_payload}

  defp normalize_tabs(tabs) when is_list(tabs) do
    tabs
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case tab(payload) do
        {:ok, tab} -> {:cont, {:ok, [tab | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, tabs} -> {:ok, Enum.reverse(tabs)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_tabs(_tabs), do: {:error, :invalid_tabs_payload}

  defp tab_section(payload, key) do
    case Data.get(payload, key, %{}) do
      section when is_map(section) -> {:ok, section}
      _invalid -> {:error, :invalid_tab_payload}
    end
  end

  defp public_map(struct) when is_struct(struct),
    do: struct |> Map.from_struct() |> public_map()

  defp public_map(map) when is_map(map) do
    map
    |> Map.new(fn {key, value} -> {key, public_map(value)} end)
  end

  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)
  defp public_map(value), do: value
end
