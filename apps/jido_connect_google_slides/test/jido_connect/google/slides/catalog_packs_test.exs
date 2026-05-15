defmodule Jido.Connect.Google.Slides.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Slides

  test "catalog packs are well-formed" do
    packs = Slides.catalog_packs()

    assert length(packs) == 2

    for pack <- packs do
      assert pack.filters == %{provider: :google_slides}
      assert pack.metadata.package == :jido_connect_google_slides
      assert is_binary(pack.label)
      assert is_binary(pack.description)
    end
  end

  test "readonly and editor pack delegates return expected ids" do
    assert %{id: :google_slides_readonly} = Slides.readonly_pack()
    assert %{id: :google_slides_editor} = Slides.editor_pack()
  end

  test "pack ids match delegate ordering" do
    ids = Enum.map(Slides.catalog_packs(), & &1.id)
    assert ids == [:google_slides_readonly, :google_slides_editor]
  end
end
