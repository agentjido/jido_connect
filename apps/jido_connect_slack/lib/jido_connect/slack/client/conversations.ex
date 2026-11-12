defmodule Jido.Connect.Slack.Client.Conversations do
  @moduledoc "Slack Conversations API boundary."

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.Client.{Params, Response, Transport}
  alias Jido.Connect.Slack.Message

  def list_channels(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/conversations.list", params: Params.list_channels_params(params))
    |> Response.handle_channel_list_response()
  end

  @doc """
  Reads one page of `conversations.history`, newest message first.

  `params` is an atom-keyed map, as in the other client calls. It needs
  `channel` and `conversation_type`, one of
  `Jido.Connect.Slack.Message.conversation_types/0`; `cursor`, `oldest`,
  `latest`, `inclusive` and `limit` are passed on. A missing channel, an
  unknown type or a string-keyed map fails before any request. The result
  holds the page's `Jido.Connect.Slack.Message` structs, `next_cursor` (`""`
  on the last page), `has_more` and, when Slack sends it, `is_limited`. There
  is no retry and no further page request.
  """
  def get_conversation_history(params, access_token)
      when is_map(params) and is_binary(access_token) do
    with :ok <- validate_history_params(params) do
      access_token
      |> Transport.request()
      |> Req.get(
        url: "/conversations.history",
        params: Params.conversation_history_params(params)
      )
      |> Response.handle_conversation_history_response(params)
    end
  end

  def get_conversation_info(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/conversations.info", params: Params.conversation_info_params(params))
    |> Response.handle_conversation_info_response(params)
  end

  def create_channel(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.create", json: Params.create_channel_params(params))
    |> Response.handle_create_channel_response()
  end

  def archive_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.archive", json: Params.archive_conversation_params(params))
    |> Response.handle_archive_conversation_response(params)
  end

  def unarchive_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/conversations.unarchive",
      json: Params.unarchive_conversation_params(params)
    )
    |> Response.handle_unarchive_conversation_response(params)
  end

  def rename_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.rename", json: Params.rename_conversation_params(params))
    |> Response.handle_rename_conversation_response()
  end

  def invite_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.invite", json: Params.invite_conversation_params(params))
    |> Response.handle_invite_conversation_response(params)
  end

  def kick_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.kick", json: Params.kick_conversation_params(params))
    |> Response.handle_kick_conversation_response(params)
  end

  def open_conversation(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/conversations.open", json: Params.open_conversation_params(params))
    |> Response.handle_open_conversation_response()
  end

  def list_conversation_members(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/conversations.members", params: Params.conversation_members_params(params))
    |> Response.handle_conversation_members_response(params)
  end

  defp validate_history_params(params) do
    channel = Map.get(params, :channel)
    type = Map.get(params, :conversation_type)

    cond do
      not is_binary(channel) or channel == "" ->
        {:error,
         Error.validation("Slack conversation history needs a channel",
           reason: :missing_channel,
           subject: :channel
         )}

      type not in Message.conversation_types() ->
        {:error,
         Error.validation("Slack conversation history needs a known conversation_type",
           reason: :invalid_conversation_type,
           subject: :conversation_type
         )}

      true ->
        :ok
    end
  end
end
