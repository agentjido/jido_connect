defmodule Jido.Connect.Google.Docs.Normalizer do
  @moduledoc "Normalizes Google Docs API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Google.Docs.{
    Document,
    DocumentRequest,
    DocumentResult,
    Tab
  }

  @doc "Normalizes a Google Docs document payload."
  @spec document(map()) :: {:ok, Document.t()} | {:error, term()}
  def document(payload) when is_map(payload) do
    %{
      document_id: Data.get(payload, "documentId"),
      title: Data.get(payload, "title"),
      revision_id: Data.get(payload, "revisionId"),
      suggestions_view_mode: Data.get(payload, "suggestionsViewMode"),
      body: Data.get(payload, "body"),
      document_style: Data.get(payload, "documentStyle"),
      tabs: payload |> Data.get("tabs", []) |> Enum.map(&tab!/1),
      named_styles: Data.get(payload, "namedStyles")
    }
    |> Data.compact()
    |> Document.new()
  end

  @doc "Normalizes a Google Docs tab payload."
  @spec tab(map()) :: {:ok, Tab.t()} | {:error, term()}
  def tab(payload) when is_map(payload) do
    tab_properties = Data.get(payload, "tabProperties", %{}) || %{}

    %{
      tab_id: Data.get(tab_properties, "id"),
      title: Data.get(tab_properties, "title"),
      body: Data.get(payload, "body")
    }
    |> Data.compact()
    |> Tab.new()
  end

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

  defp tab!(payload) do
    case tab(payload) do
      {:ok, tab} -> tab
      {:error, error} -> raise error
    end
  end
end
