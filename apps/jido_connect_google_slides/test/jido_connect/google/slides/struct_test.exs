defmodule Jido.Connect.Google.Slides.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Slides.{
    BatchUpdateResult,
    PageElement,
    Presentation,
    Slide,
    Thumbnail
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "presentation struct validates with Zoi" do
    presentation =
      ConnectorContracts.assert_struct_defaults(
        Presentation,
        %{presentation_id: "pres_abc123"},
        slides: [],
        metadata: %{}
      )

    assert presentation.presentation_id == "pres_abc123"
    assert {:error, _error} = Presentation.new(%{})
  end

  test "presentation struct accepts full attributes" do
    presentation =
      Presentation.new!(%{
        presentation_id: "pres_abc123",
        title: "Q4 Review",
        locale: "en_US",
        revision_id: "rev001",
        page_width: %{"magnitude" => 9_144_000, "unit" => "EMU"},
        page_height: %{"magnitude" => 6_858_000, "unit" => "EMU"},
        slides: []
      })

    assert presentation.title == "Q4 Review"
    assert presentation.locale == "en_US"
    assert presentation.revision_id == "rev001"
    assert presentation.page_width == %{"magnitude" => 9_144_000, "unit" => "EMU"}
    assert presentation.page_height == %{"magnitude" => 6_858_000, "unit" => "EMU"}
  end

  test "slide struct validates with Zoi" do
    slide =
      ConnectorContracts.assert_struct_defaults(
        Slide,
        %{object_id: "slide_title"},
        elements: [],
        metadata: %{}
      )

    assert slide.object_id == "slide_title"
  end

  test "slide struct accepts empty optional fields" do
    slide = Slide.new!(%{})
    assert slide.elements == []
    assert slide.metadata == %{}
  end

  test "slide struct accepts layout and master references" do
    slide =
      Slide.new!(%{
        object_id: "slide_1",
        layout_object_id: "layout_title",
        master_object_id: "master_default"
      })

    assert slide.layout_object_id == "layout_title"
    assert slide.master_object_id == "master_default"
  end

  test "page element struct validates with Zoi" do
    element =
      ConnectorContracts.assert_struct_defaults(
        PageElement,
        %{object_id: "elem_1", element_type: "shape"},
        metadata: %{}
      )

    assert element.object_id == "elem_1"
    assert element.element_type == "shape"
  end

  test "page element struct accepts all optional fields" do
    element =
      PageElement.new!(%{
        object_id: "elem_2",
        element_type: "image",
        transform: %{"scaleX" => 1.0, "scaleY" => 1.0},
        size: %{"width" => %{"magnitude" => 100}, "height" => %{"magnitude" => 100}},
        title: "Chart Title",
        description: "A detailed chart"
      })

    assert element.element_type == "image"
    assert element.title == "Chart Title"
    assert element.description == "A detailed chart"
  end

  test "thumbnail struct validates with Zoi" do
    thumbnail =
      ConnectorContracts.assert_struct_defaults(
        Thumbnail,
        %{width: 800, height: 450},
        metadata: %{}
      )

    assert thumbnail.width == 800
    assert thumbnail.height == 450
  end

  test "thumbnail struct accepts all optional fields" do
    thumbnail =
      Thumbnail.new!(%{
        width: 1024,
        height: 768,
        content_url: "https://example.com/thumb.png",
        mime_type: "image/png"
      })

    assert thumbnail.content_url == "https://example.com/thumb.png"
    assert thumbnail.mime_type == "image/png"
  end

  test "batch update result struct validates with Zoi" do
    result =
      ConnectorContracts.assert_struct_defaults(
        BatchUpdateResult,
        %{presentation_id: "pres_abc123"},
        replies: [],
        metadata: %{}
      )

    assert result.presentation_id == "pres_abc123"
    assert result.replies == []
  end

  test "batch update result struct accepts all optional fields" do
    result =
      BatchUpdateResult.new!(%{
        presentation_id: "pres_abc123",
        replies: [%{"createShape" => %{"objectId" => "new_1"}}],
        write_control: %{"requiredRevisionId" => "rev003"}
      })

    assert length(result.replies) == 1
    assert result.write_control == %{"requiredRevisionId" => "rev003"}
  end
end
