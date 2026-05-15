defmodule Jido.Connect.Google.Slides.Normalizer do
  @moduledoc "Normalizes Google Slides API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Google.Slides.{
    BatchUpdateResult,
    PageElement,
    Presentation,
    Slide,
    Thumbnail
  }

  @doc "Normalizes a Google Slides presentation payload."
  @spec presentation(map()) :: {:ok, Presentation.t()} | {:error, term()}
  def presentation(payload) when is_map(payload) do
    %{
      presentation_id: Data.get(payload, "presentationId"),
      title: Data.get(payload, "title"),
      locale: Data.get(payload, "locale"),
      revision_id: Data.get(payload, "revisionId"),
      page_width: page_dimension(payload, "width"),
      page_height: page_dimension(payload, "height"),
      slides: payload |> Data.get("slides", []) |> Enum.map(&slide!/1)
    }
    |> Data.compact()
    |> Presentation.new()
  end

  @doc "Normalizes a Google Slides slide/page payload."
  @spec slide(map()) :: {:ok, Slide.t()} | {:error, term()}
  def slide(payload) when is_map(payload) do
    slide_properties = Data.get(payload, "slideProperties", %{}) || %{}
    layout_object_id = Data.get(slide_properties, "layoutObjectId")
    master_object_id = Data.get(slide_properties, "masterObjectId")

    %{
      object_id: Data.get(payload, "objectId"),
      slide_layout: nil,
      master_object_id: master_object_id,
      layout_object_id: layout_object_id,
      elements: payload |> Data.get("pageElements", []) |> Enum.map(&page_element!/1)
    }
    |> Data.compact()
    |> Slide.new()
  end

  @doc "Normalizes a Google Slides page element payload."
  @spec page_element(map()) :: {:ok, PageElement.t()} | {:error, term()}
  def page_element(payload) when is_map(payload) do
    %{
      object_id: Data.get(payload, "objectId"),
      element_type: element_type(payload),
      transform: Data.get(payload, "transform"),
      size: Data.get(payload, "size"),
      title: Data.get(payload, "title"),
      description: Data.get(payload, "description")
    }
    |> Data.compact()
    |> PageElement.new()
  end

  @doc "Normalizes a Google Slides thumbnail payload."
  @spec thumbnail(map()) :: {:ok, Thumbnail.t()} | {:error, term()}
  def thumbnail(payload) when is_map(payload) do
    %{
      width: Data.get(payload, "width"),
      height: Data.get(payload, "height"),
      content_url: Data.get(payload, "contentUrl"),
      mime_type: Data.get(payload, "mimeType")
    }
    |> Data.compact()
    |> Thumbnail.new()
  end

  @doc "Normalizes a Google Slides batch update result payload."
  @spec batch_update_result(map()) :: {:ok, BatchUpdateResult.t()} | {:error, term()}
  def batch_update_result(payload) when is_map(payload) do
    %{
      presentation_id: Data.get(payload, "presentationId"),
      replies: payload |> Data.get("replies", []) |> Enum.map(&public_map/1),
      write_control: Data.get(payload, "writeControl")
    }
    |> Data.compact()
    |> BatchUpdateResult.new()
  end

  defp page_dimension(payload, axis) do
    case Data.get(payload, "pageSize") do
      nil -> nil
      page_size -> Data.get(page_size, axis)
    end
  end

  defp element_type(payload) do
    element_type_keys =
      ~w(shape image video table chart text_box line group speaker_shape word_art)

    payload
    |> Map.keys()
    |> Enum.find(fn key ->
      key in element_type_keys or
        (is_binary(key) and key in element_type_keys)
    end)
  end

  defp slide!(payload) do
    case slide(payload) do
      {:ok, slide} -> slide
      {:error, error} -> raise error
    end
  end

  defp page_element!(payload) do
    case page_element(payload) do
      {:ok, element} -> element
      {:error, error} -> raise error
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
