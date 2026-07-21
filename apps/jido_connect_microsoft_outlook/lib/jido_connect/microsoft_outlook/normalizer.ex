defmodule Jido.Connect.MicrosoftOutlook.Normalizer do
  @moduledoc """
  Normalizes Microsoft Graph Mail API payloads into stable, body-safe package
  structs.

  This module is read/shape only. It accepts decoded JSON maps (typically from
  fixtures or Transport responses) and produces validated Zoi structs for
  folders, messages, recipients, and attachment metadata.

  No HTTP actions are performed here — all input is fixture-driven.
  """

  alias Jido.Connect.Data
  alias Jido.Connect.MicrosoftOutlook.{Attachment, Folder, Message, Recipient}

  # ── Folder ────────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `mailFolder` payload."
  @spec folder(map()) :: {:ok, Folder.t()} | {:error, term()}
  def folder(payload) when is_map(payload) do
    %{
      folder_id: Data.get(payload, "id"),
      display_name: Data.get(payload, "displayName"),
      parent_folder_id: Data.get(payload, "parentFolderId"),
      child_folder_count: normalize_integer(Data.get(payload, "childFolderCount")),
      unread_item_count: normalize_integer(Data.get(payload, "unreadItemCount")),
      total_item_count: normalize_integer(Data.get(payload, "totalItemCount")),
      well_known_name: Data.get(payload, "wellKnownName")
    }
    |> Data.compact()
    |> Folder.new()
  end

  def folder(_payload), do: {:error, :invalid_folder_payload}

  # ── Message ───────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `message` payload without body content leakage."
  @spec message(map()) :: {:ok, Message.t()} | {:error, term()}
  def message(payload) when is_map(payload) do
    %{
      message_id: Data.get(payload, "id"),
      conversation_id: Data.get(payload, "conversationId"),
      subject: Data.get(payload, "subject"),
      body_preview: Data.get(payload, "bodyPreview"),
      body_summary: summarize_body(Data.get(payload, "body")),
      sender: normalize_recipient(Data.get(payload, "sender")),
      from: normalize_recipient(Data.get(payload, "from")),
      to_recipients: normalize_recipients(Data.get(payload, "toRecipients")),
      cc_recipients: normalize_recipients(Data.get(payload, "ccRecipients")),
      bcc_recipients: normalize_recipients(Data.get(payload, "bccRecipients")),
      internet_message_id: Data.get(payload, "internetMessageId"),
      received_date_time: Data.get(payload, "receivedDateTime"),
      sent_date_time: Data.get(payload, "sentDateTime"),
      importance: Data.get(payload, "importance"),
      is_read: Data.get(payload, "isRead"),
      is_draft: Data.get(payload, "isDraft"),
      has_attachments: Data.get(payload, "hasAttachments"),
      folders: normalize_folders(Data.get(payload, "parentFolderId")),
      attachments: normalize_attachments(Data.get(payload, "attachments"))
    }
    |> Data.compact()
    |> Message.new()
  end

  def message(_payload), do: {:error, :invalid_message_payload}

  # ── Recipient ─────────────────────────────────────────────────────────

  @doc "Normalizes a single Microsoft Graph recipient object."
  @spec recipient(map()) :: {:ok, Recipient.t()} | {:error, term()}
  def recipient(payload) when is_map(payload) do
    email_address = Data.get(payload, "emailAddress", %{})

    %{
      name: Data.get(email_address, "name"),
      address: Data.get(email_address, "address")
    }
    |> Data.compact()
    |> Recipient.new()
  end

  def recipient(_payload), do: {:error, :invalid_recipient_payload}

  # ── Attachment ────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `fileAttachment` payload (metadata only)."
  @spec attachment(map()) :: {:ok, Attachment.t()} | {:error, term()}
  def attachment(payload) when is_map(payload) do
    %{
      attachment_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      content_type: Data.get(payload, "contentType"),
      size: normalize_integer(Data.get(payload, "size")),
      is_inline: Data.get(payload, "isInline", false)
    }
    |> Data.compact()
    |> Attachment.new()
  end

  def attachment(_payload), do: {:error, :invalid_attachment_payload}

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

  defp summarize_body(%{} = body) do
    %{
      content_type: Data.get(body, "contentType"),
      body_size: body |> Data.get("content", "") |> byte_size()
    }
    |> Data.compact()
  end

  defp summarize_body(_body), do: %{}

  defp normalize_recipient(%{} = recipient) do
    email_address = Data.get(recipient, "emailAddress", %{})

    %{
      name: Data.get(email_address, "name"),
      address: Data.get(email_address, "address")
    }
    |> Data.compact()
  end

  defp normalize_recipient(_recipient), do: nil

  defp normalize_recipients(recipients) when is_list(recipients) do
    recipients
    |> Enum.map(&normalize_recipient/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_recipients(_recipients), do: []

  defp normalize_attachments(attachments) when is_list(attachments) do
    attachments
    |> Enum.map(&normalize_attachment_metadata/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_attachments(_attachments), do: []

  defp normalize_attachment_metadata(%{} = attachment) do
    %{
      attachment_id: Data.get(attachment, "id"),
      name: Data.get(attachment, "name"),
      content_type: Data.get(attachment, "contentType"),
      size: normalize_integer(Data.get(attachment, "size")),
      is_inline: Data.get(attachment, "isInline", false)
    }
    |> Data.compact()
  end

  defp normalize_attachment_metadata(_attachment), do: nil

  defp normalize_folders(folder_id) when is_binary(folder_id) and folder_id != "",
    do: [folder_id]

  defp normalize_folders(_folder_id), do: []

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp normalize_integer(_value), do: nil
end
