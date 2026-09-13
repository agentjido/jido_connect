defmodule Jido.Connect.MicrosoftOnedrive.Normalizer do
  @moduledoc """
  Normalizes Microsoft Graph OneDrive API payloads into stable, body-safe
  package structs.

  This module is read/shape only. It accepts decoded JSON maps (typically from
  fixtures or Transport responses) and produces validated Zoi structs for
  drives, drive items, folders, files, thumbnails, sharing links, permissions,
  delta tokens, and download metadata.

  No HTTP actions are performed here — all input is fixture-driven.
  """

  alias Jido.Connect.Data

  alias Jido.Connect.MicrosoftOnedrive.{
    DeltaToken,
    Download,
    Drive,
    DriveItem,
    FileFacet,
    Folder,
    Permission,
    SharingLink,
    Thumbnail
  }

  # ── Drive ─────────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `drive` payload."
  @spec drive(map()) :: {:ok, Drive.t()} | {:error, term()}
  def drive(payload) when is_map(payload) do
    %{
      drive_id: Data.get(payload, "id"),
      drive_type: Data.get(payload, "driveType"),
      name: Data.get(payload, "name"),
      description: Data.get(payload, "description"),
      web_url: Data.get(payload, "webUrl"),
      quota: Data.get(payload, "quota"),
      owner: normalize_owner(Data.get(payload, "owner")),
      created_date_time: Data.get(payload, "createdDateTime"),
      last_modified_date_time: Data.get(payload, "lastModifiedDateTime")
    }
    |> Data.compact()
    |> Drive.new()
  end

  def drive(_payload), do: {:error, :invalid_drive_payload}

  # ── Drive Item ────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `driveItem` payload."
  @spec drive_item(map()) :: {:ok, DriveItem.t()} | {:error, term()}
  def drive_item(payload) when is_map(payload) do
    with {:ok, permissions} <- normalize_embedded_permissions(Data.get(payload, "permissions")),
         {:ok, thumbnails} <- normalize_embedded_thumbnails(Data.get(payload, "thumbnails")) do
      %{
        item_id: Data.get(payload, "id"),
        etag: Data.get(payload, "eTag"),
        ctag: Data.get(payload, "cTag"),
        name: Data.get(payload, "name"),
        size: normalize_integer(Data.get(payload, "size")),
        web_url: Data.get(payload, "webUrl"),
        created_date_time: Data.get(payload, "createdDateTime"),
        last_modified_date_time: Data.get(payload, "lastModifiedDateTime"),
        folder: normalize_folder_facet(Data.get(payload, "folder")),
        file: normalize_file_facet(Data.get(payload, "file")),
        parent_reference: Data.get(payload, "parentReference"),
        created_by: normalize_identity(Data.get(payload, "createdBy")),
        last_modified_by: normalize_identity(Data.get(payload, "lastModifiedBy")),
        thumbnails: thumbnails,
        permissions: permissions
      }
      |> Data.compact()
      |> DriveItem.new()
    end
  end

  def drive_item(_payload), do: {:error, :invalid_drive_item_payload}

  # ── Folder facet ──────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `folder` facet payload."
  @spec folder(map()) :: {:ok, Folder.t()} | {:error, term()}
  def folder(payload) when is_map(payload) do
    %{
      child_count: normalize_integer(Data.get(payload, "childCount")),
      view: Data.get(payload, "view")
    }
    |> Data.compact()
    |> Folder.new()
  end

  def folder(_payload), do: {:error, :invalid_folder_payload}

  # ── File facet ────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `file` facet payload."
  @spec file_facet(map()) :: {:ok, FileFacet.t()} | {:error, term()}
  def file_facet(payload) when is_map(payload) do
    %{
      mime_type: Data.get(payload, "mimeType"),
      hashes: Data.get(payload, "hashes")
    }
    |> Data.compact()
    |> FileFacet.new()
  end

  def file_facet(_payload), do: {:error, :invalid_file_facet_payload}

  # ── Thumbnail ─────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `thumbnail` payload."
  @spec thumbnail(map()) :: {:ok, Thumbnail.t()} | {:error, term()}
  def thumbnail(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      width: normalize_integer(Data.get(payload, "width")),
      height: normalize_integer(Data.get(payload, "height")),
      url: Data.get(payload, "url"),
      source_item_id: Data.get(payload, "sourceItemId"),
      content_type: Data.get(payload, "contentType")
    }
    |> Data.compact()
    |> Thumbnail.new()
  end

  def thumbnail(_payload), do: {:error, :invalid_thumbnail_payload}

  # ── Sharing Link ──────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `sharingLink` facet payload."
  @spec sharing_link(map()) :: {:ok, SharingLink.t()} | {:error, term()}
  def sharing_link(payload) when is_map(payload) do
    %{
      link: Data.get(payload, "webUrl"),
      web_html: Data.get(payload, "webHtml"),
      type: Data.get(payload, "type"),
      application: Data.get(payload, "application"),
      prevents_download: Data.get(payload, "preventsDownload")
    }
    |> Data.compact()
    |> SharingLink.new()
  end

  def sharing_link(_payload), do: {:error, :invalid_sharing_link_payload}

  # ── Permission ────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `permission` payload."
  @spec permission(map()) :: {:ok, Permission.t()} | {:error, term()}
  def permission(payload) when is_map(payload) do
    with {:ok, link} <- normalize_sharing_link(Data.get(payload, "link")) do
      %{
        permission_id: Data.get(payload, "id"),
        roles: Data.get(payload, "roles", []),
        link: link,
        granted_to: normalize_identity_set(Data.get(payload, "grantedTo")),
        granted_to_identities: normalize_identity_sets(Data.get(payload, "grantedToIdentities")),
        inherited_from: Data.get(payload, "inheritedFrom"),
        share_id: Data.get(payload, "shareId"),
        has_password: Data.get(payload, "hasPassword")
      }
      |> Data.compact()
      |> Permission.new()
    end
  end

  def permission(_payload), do: {:error, :invalid_permission_payload}

  # ── Delta Token ───────────────────────────────────────────────────────

  @doc "Normalizes delta token metadata from a Graph delta response envelope."
  @spec delta_token(map()) :: {:ok, DeltaToken.t()} | {:error, term()}
  def delta_token(payload) when is_map(payload) do
    %{
      delta_token: Data.get(payload, "@odata.deltaToken"),
      delta_link: Data.get(payload, "@odata.deltaLink")
    }
    |> Data.compact()
    |> DeltaToken.new()
  end

  def delta_token(_payload), do: {:error, :invalid_delta_token_payload}

  # ── Download ──────────────────────────────────────────────────────────

  @doc "Normalizes download metadata from a Graph `@content.downloadUrl` response."
  @spec download(map()) :: {:ok, Download.t()} | {:error, term()}
  def download(payload) when is_map(payload) do
    %{
      download_url: Data.get(payload, "@content.downloadUrl"),
      content_length: normalize_integer(Data.get(payload, "size")),
      content_type: Data.get(payload, "file", %{}) |> Map.get("mimeType")
    }
    |> Data.compact()
    |> Download.new()
  end

  def download(_payload), do: {:error, :invalid_download_payload}

  # ── Paging envelope ───────────────────────────────────────────────────

  @doc """
  Extracts the normalized page of items and next-link from a Microsoft Graph
  OData list envelope.

  Returns `{:ok, %{items: [...], next_link: nil | binary()}}`.
  """
  @spec page(map(), (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, %{items: [struct()], next_link: String.t() | nil}}
          | {:error, term()}
  def page(envelope, normalizer) when is_map(envelope) and is_function(normalizer, 1) do
    values = Data.get(envelope, "value", [])
    next = Data.get(envelope, "@odata.nextLink")

    case normalize_list(values, normalizer) do
      {:ok, items} -> {:ok, %{items: items, next_link: next}}
      {:error, reason} -> {:error, reason}
    end
  end

  def page(_envelope, _normalizer), do: {:error, :invalid_page_envelope}

  # ── Batch helpers ─────────────────────────────────────────────────────

  @doc "Normalizes a list of payloads using the given normalizer function."
  @spec normalize_list([map()], (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, [struct()]} | {:error, term()}
  def normalize_list(payloads, normalizer)
      when is_list(payloads) and is_function(normalizer, 1) do
    Enum.reduce_while(payloads, {:ok, []}, fn payload, {:ok, acc} ->
      case normalizer.(payload) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_list(_payloads, _normalizer), do: {:error, :invalid_list_payloads}

  # ── Private helpers ───────────────────────────────────────────────────

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp normalize_owner(%{} = owner) do
    user = Data.get(owner, "user", %{})

    %{
      user:
        %{
          display_name: Data.get(user, "displayName"),
          email: Data.get(user, "email"),
          id: Data.get(user, "id")
        }
        |> Data.compact()
    }
    |> Data.compact()
  end

  defp normalize_owner(_owner), do: nil

  defp normalize_identity(%{} = identity) do
    user = Data.get(identity, "user", %{})

    %{
      user:
        %{
          display_name: Data.get(user, "displayName"),
          email: Data.get(user, "email"),
          id: Data.get(user, "id")
        }
        |> Data.compact()
    }
    |> Data.compact()
  end

  defp normalize_identity(_identity), do: nil

  defp normalize_identity_set(%{} = identity_set) do
    normalize_identity(identity_set)
  end

  defp normalize_identity_set(_identity_set), do: nil

  defp normalize_identity_sets(nil), do: []
  defp normalize_identity_sets([]), do: []

  defp normalize_identity_sets(identity_sets) when is_list(identity_sets) do
    identity_sets
    |> Enum.map(&normalize_identity_set/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_identity_sets(_identity_sets), do: []

  defp normalize_folder_facet(%{} = folder) do
    case folder(folder) do
      {:ok, struct} -> Map.from_struct(struct)
      {:error, _reason} -> folder
    end
  end

  defp normalize_folder_facet(_folder), do: nil

  defp normalize_file_facet(%{} = file) do
    case file_facet(file) do
      {:ok, struct} -> Map.from_struct(struct)
      {:error, _reason} -> file
    end
  end

  defp normalize_file_facet(_file), do: nil

  defp normalize_sharing_link(%{} = link) do
    case sharing_link(link) do
      {:ok, struct} -> {:ok, Map.from_struct(struct)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_sharing_link(_link), do: {:ok, nil}

  defp normalize_embedded_permissions(nil), do: {:ok, []}
  defp normalize_embedded_permissions([]), do: {:ok, []}

  defp normalize_embedded_permissions(permissions) when is_list(permissions) do
    permissions
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case normalize_permission(payload) do
        {:ok, permission} -> {:cont, {:ok, [permission | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_embedded_permissions(_permissions), do: {:error, :invalid_permission_payload}

  defp normalize_permission(%Permission{} = permission), do: {:ok, permission}
  defp normalize_permission(payload), do: permission(payload)

  defp normalize_embedded_thumbnails(nil), do: {:ok, []}
  defp normalize_embedded_thumbnails([]), do: {:ok, []}

  defp normalize_embedded_thumbnails(thumbnails) when is_list(thumbnails) do
    thumbnails
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case thumbnail(payload) do
        {:ok, thumb} -> {:cont, {:ok, [thumb | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_embedded_thumbnails(_thumbnails), do: {:error, :invalid_thumbnail_payload}
end
