defmodule Jido.Connect.Google.Slides.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Slides.Normalizer

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes common Google Slides presentation fixture" do
    payload = fixture!("presentation_common.json")

    assert {:ok, presentation} = Normalizer.presentation(payload)
    assert presentation.presentation_id == "pres_abc123"
    assert presentation.title == "Q4 Strategy Review"
    assert presentation.locale == "en_US"
    assert presentation.revision_id == "rev001"
    assert presentation.page_width != nil
    assert presentation.page_height != nil
    assert length(presentation.slides) == 2
  end

  test "normalizes presentation fixture slides and elements" do
    payload = fixture!("presentation_common.json")

    assert {:ok, presentation} = Normalizer.presentation(payload)
    [slide1, slide2] = presentation.slides

    assert slide1.object_id == "slide_title"
    assert slide1.layout_object_id == "layout_title"
    assert slide1.master_object_id == "master_default"
    assert length(slide1.elements) == 1

    assert slide2.object_id == "slide_content"
    assert length(slide2.elements) == 2
  end

  test "normalizes presentation fixture page elements" do
    payload = fixture!("presentation_common.json")

    assert {:ok, presentation} = Normalizer.presentation(payload)
    [elem1 | _rest] = hd(presentation.slides).elements

    assert elem1.object_id == "elem_title_text"
    assert elem1.element_type == "shape"
    assert elem1.size != nil
    assert elem1.transform != nil
  end

  test "normalizes minimal Google Slides presentation fixture" do
    payload = fixture!("presentation_minimal.json")

    assert {:ok, presentation} = Normalizer.presentation(payload)
    assert presentation.presentation_id == "pres_min456"
    assert presentation.title == "Minimal Deck"
    assert presentation.revision_id == "rev002"
    assert presentation.slides == []
    assert presentation.page_width == nil
    assert presentation.page_height == nil
  end

  test "normalizes Google Slides batch update result fixture" do
    payload = fixture!("batch_update_result.json")

    assert {:ok, result} = Normalizer.batch_update_result(payload)
    assert result.presentation_id == "pres_batch789"
    assert length(result.replies) == 2
    assert result.write_control != nil
  end

  test "normalizes Google Slides thumbnail fixture" do
    payload = fixture!("thumbnail_common.json")

    assert {:ok, thumbnail} = Normalizer.thumbnail(payload)
    assert thumbnail.width == 800
    assert thumbnail.height == 450
    assert thumbnail.content_url == "https://lh3.googleusercontent.com/d/slide_thumb_abc"
    assert thumbnail.mime_type == "image/png"
  end

  test "normalizes slide directly" do
    payload = %{
      "objectId" => "slide_direct",
      "slideProperties" => %{
        "layoutObjectId" => "layout_blank",
        "masterObjectId" => "master_default"
      },
      "pageElements" => [
        %{
          "objectId" => "elem_direct_1",
          "shape" => %{"shapeType" => "TEXT_BOX"},
          "transform" => %{"scaleX" => 1.0},
          "size" => %{"width" => %{"magnitude" => 500}}
        }
      ]
    }

    assert {:ok, slide} = Normalizer.slide(payload)
    assert slide.object_id == "slide_direct"
    assert slide.layout_object_id == "layout_blank"
    assert slide.master_object_id == "master_default"
    assert length(slide.elements) == 1

    [elem] = slide.elements
    assert elem.object_id == "elem_direct_1"
    assert elem.element_type == "shape"
  end

  test "normalizes page element directly" do
    payload = %{
      "objectId" => "elem_direct",
      "shape" => %{"shapeType" => "RECTANGLE"},
      "transform" => %{"scaleX" => 2.0, "scaleY" => 2.0},
      "size" => %{"width" => %{"magnitude" => 100}, "height" => %{"magnitude" => 200}},
      "title" => "Box",
      "description" => "A rectangle"
    }

    assert {:ok, element} = Normalizer.page_element(payload)
    assert element.object_id == "elem_direct"
    assert element.element_type == "shape"
    assert element.title == "Box"
    assert element.description == "A rectangle"
  end

  test "normalizes page element with image type" do
    payload = %{
      "objectId" => "elem_image",
      "image" => %{"contentUrl" => "https://example.com/img.png"},
      "transform" => %{"scaleX" => 1.0}
    }

    assert {:ok, element} = Normalizer.page_element(payload)
    assert element.element_type == "image"
  end

  test "normalizes page element with table type" do
    payload = %{
      "objectId" => "elem_table",
      "table" => %{"rows" => 3, "columns" => 4}
    }

    assert {:ok, element} = Normalizer.page_element(payload)
    assert element.element_type == "table"
  end

  test "normalizes batch update result with empty replies" do
    payload = %{
      "presentationId" => "pres_empty_replies",
      "replies" => []
    }

    assert {:ok, result} = Normalizer.batch_update_result(payload)
    assert result.presentation_id == "pres_empty_replies"
    assert result.replies == []
  end

  defp fixture!(name) do
    ConnectorContracts.google_fixture!(:google_slides, name, __DIR__)
  end
end
