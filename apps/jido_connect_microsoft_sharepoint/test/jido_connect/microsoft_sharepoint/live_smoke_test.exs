defmodule Jido.Connect.MicrosoftSharepoint.LiveSmokeTest do
  @moduledoc "Read-only, environment-gated SharePoint Online smoke tests."

  use ExUnit.Case, async: true

  @moduletag :live_smoke

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems

  alias Jido.Connect.MicrosoftSharepoint.Handlers.Actions.{
    DeltaListItems,
    GetSite,
    ListLibraries,
    ListListItems,
    ListLists
  }

  setup_all do
    token = System.get_env("MICROSOFT_ACCESS_TOKEN")
    site_id = System.get_env("MICROSOFT_SHAREPOINT_SITE_ID")

    if present?(token) and present?(site_id) do
      {:ok,
       token: token,
       site_id: site_id,
       list_id: System.get_env("MICROSOFT_SHAREPOINT_LIST_ID"),
       drive_id: System.get_env("MICROSOFT_SHAREPOINT_DRIVE_ID")}
    else
      {:skip, "Microsoft access token or SharePoint site id is not set"}
    end
  end

  test "gets a site and lists its lists and libraries", context do
    credentials = credentials(context.token)

    assert {:ok, %{site: site}} = GetSite.run(%{site_id: context.site_id}, credentials)
    assert site.site_id

    assert {:ok, %{lists: lists}} =
             ListLists.run(%{site_id: context.site_id, page_size: 5}, credentials)

    assert is_list(lists)

    assert {:ok, %{libraries: libraries}} =
             ListLibraries.run(%{site_id: context.site_id, page_size: 5}, credentials)

    assert is_list(libraries)
  end

  test "reads list items and list delta when a list id is set", context do
    if present?(context.list_id) do
      input = %{site_id: context.site_id, list_id: context.list_id, page_size: 5}
      credentials = credentials(context.token)

      assert {:ok, %{items: items}} = ListListItems.run(input, credentials)
      assert is_list(items)

      assert {:ok, %{items: changes}} = DeltaListItems.run(input, credentials)
      assert is_list(changes)
    end
  end

  test "lists library root items when a drive id is set", context do
    if present?(context.drive_id) do
      assert {:ok, %{items: items}} =
               ListItems.run(
                 %{drive_id: context.drive_id, page_size: 5},
                 credentials(context.token)
               )

      assert is_list(items)
    end
  end

  defp credentials(token), do: %{credentials: %{access_token: token}}
  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
