defmodule Jido.Connect.Google.Slides.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Slides
  alias Jido.Connect.Google.Slides.{BatchUpdateResult, Presentation, Thumbnail}

  defmodule FakeSlidesClient do
    def get_presentation(%{presentation_id: "pres_abc123"}, "token") do
      {:ok,
       Presentation.new!(%{
         presentation_id: "pres_abc123",
         title: "Q4 Strategy Review",
         revision_id: "rev001"
       })}
    end

    def create_presentation(%{title: "New Deck"}, "token") do
      {:ok,
       Presentation.new!(%{
         presentation_id: "pres_new001",
         title: "New Deck",
         revision_id: "rev001"
       })}
    end

    def batch_update(
          %{presentation_id: "pres_abc123", requests: [%{"createSlide" => _}]},
          "token"
        ) do
      {:ok,
       BatchUpdateResult.new!(%{
         presentation_id: "pres_abc123",
         replies: [%{"createSlide" => %{"objectId" => "new_slide_1"}}]
       })}
    end

    def get_page_thumbnail(
          %{presentation_id: "pres_abc123", page_object_id: "slide_title"},
          "token"
        ) do
      {:ok,
       Thumbnail.new!(%{
         width: 800,
         height: 450,
         content_url: "https://lh3.googleusercontent.com/d/slide_thumb_abc",
         mime_type: "image/png"
       })}
    end
  end

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

  test "readonly pack restricts search and describe to read tools" do
    results =
      Catalog.search_tools("slides",
        modules: [Slides],
        packs: Slides.catalog_packs(),
        pack: :google_slides_readonly
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.slides.presentation.get" in ids
    assert "google.slides.presentation.page.get_thumbnail" in ids
    refute "google.slides.presentation.create" in ids
    refute "google.slides.presentation.batch_update" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.slides.presentation.get",
               modules: [Slides],
               packs: Slides.catalog_packs(),
               pack: :google_slides_readonly
             )

    assert descriptor.tool.id == "google.slides.presentation.get"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.slides.presentation.page.get_thumbnail",
               modules: [Slides],
               packs: Slides.catalog_packs(),
               pack: :google_slides_readonly
             )

    assert descriptor.tool.id == "google.slides.presentation.page.get_thumbnail"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.slides.presentation.create",
               modules: [Slides],
               packs: Slides.catalog_packs(),
               pack: :google_slides_readonly
             )
  end

  test "editor pack allows all tools" do
    results =
      Catalog.search_tools("slides",
        modules: [Slides],
        packs: Slides.catalog_packs(),
        pack: :google_slides_editor
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.slides.presentation.get" in ids
    assert "google.slides.presentation.create" in ids
    assert "google.slides.presentation.batch_update" in ids
    assert "google.slides.presentation.page.get_thumbnail" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.slides.presentation.create",
               modules: [Slides],
               packs: Slides.catalog_packs(),
               pack: :google_slides_editor
             )

    assert descriptor.tool.id == "google.slides.presentation.create"
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              presentation: %{
                presentation_id: "pres_abc123",
                title: "Q4 Strategy Review",
                revision_id: "rev001"
              }
            }} =
             Catalog.call_tool(
               "google.slides.presentation.get",
               %{presentation_id: "pres_abc123"},
               modules: [Slides],
               packs: Slides.catalog_packs(),
               pack: :google_slides_readonly,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.slides.presentation.create",
               %{title: "New Deck"},
               modules: [Slides],
               packs: Slides.catalog_packs(),
               pack: :google_slides_readonly,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/presentations.readonly"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google_slides,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google_slides,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_slides_client: FakeSlidesClient},
        scopes: scopes
      })

    {context, lease}
  end
end
