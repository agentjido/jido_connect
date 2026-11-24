defmodule Jido.Connect.Slack.Client.Params do
  @moduledoc "Slack Web API request parameter and payload helpers."

  alias Jido.Connect.Data

  def list_channels_params(params) do
    params
    |> Map.take([:types, :exclude_archived, :limit, :cursor, :team_id])
    |> Data.compact()
  end

  def thread_replies_params(params) do
    params
    |> Map.take([:channel, :ts, :limit, :cursor, :oldest, :latest, :inclusive])
    |> Data.compact()
  end

  # `conversation_type` selects the scope and the output; Slack never sees it.
  def conversation_history_params(params) do
    params
    |> Map.take([:channel, :cursor, :oldest, :latest, :inclusive, :limit])
    |> Data.compact()
  end

  def search_messages_params(params) do
    search_params(params)
  end

  def search_params(params) do
    params
    |> Map.take([:query, :sort, :sort_dir, :count, :page, :cursor, :highlight, :team_id])
    |> Data.compact()
  end

  def conversation_info_params(params) do
    params
    |> Map.take([:channel, :include_locale])
    |> Data.compact()
  end

  def create_channel_params(params) do
    params
    |> Map.take([:name, :is_private, :team_id])
    |> Data.compact()
  end

  def archive_conversation_params(params) do
    params
    |> Map.take([:channel])
    |> Data.compact()
  end

  def unarchive_conversation_params(params) do
    params
    |> Map.take([:channel])
    |> Data.compact()
  end

  def rename_conversation_params(params) do
    params
    |> Map.take([:channel, :name])
    |> Data.compact()
  end

  def invite_conversation_params(params) do
    params
    |> Map.take([:channel, :users, :force])
    |> maybe_join_users()
    |> Data.compact()
  end

  def kick_conversation_params(params) do
    params
    |> Map.take([:channel, :user])
    |> Data.compact()
  end

  def open_conversation_params(params) do
    params
    |> Map.take([:users, :channel, :return_im, :prevent_creation])
    |> maybe_join_users()
    |> Data.compact()
  end

  def conversation_members_params(params) do
    params
    |> Map.take([:channel, :limit, :cursor])
    |> Data.compact()
  end

  def ephemeral_message_params(params) do
    params
    |> Map.take([:channel, :user, :text, :thread_ts, :blocks])
    |> Data.compact()
  end

  def scheduled_message_params(params) do
    params
    |> Map.take([:channel, :text, :post_at, :thread_ts, :reply_broadcast, :blocks])
    |> Data.compact()
  end

  def delete_scheduled_message_params(params) do
    params
    |> Map.take([:channel, :scheduled_message_id])
    |> Data.compact()
  end

  def list_users_params(params) do
    params
    |> Map.take([:limit, :cursor, :team_id, :include_locale])
    |> Data.compact()
  end

  def user_info_params(params) do
    params
    |> Map.take([:user, :include_locale])
    |> Data.compact()
  end

  def lookup_user_by_email_params(params) do
    params
    |> Map.take([:email])
    |> Data.compact()
  end

  def team_info_params(params) do
    case Data.get(params, :team_id) do
      nil -> %{}
      team_id -> %{team: team_id}
    end
  end

  def reaction_params(params) do
    params
    |> Map.take([:channel, :timestamp, :name])
    |> Data.compact()
  end

  def get_reactions_params(params) do
    params
    |> Map.take([:channel, :timestamp, :file, :file_comment, :full])
    |> Data.compact()
  end

  def pin_list_params(params) do
    params
    |> Map.take([:channel])
    |> Data.compact()
  end

  def pin_params(params) do
    params
    |> Map.take([:channel, :timestamp])
    |> Data.compact()
  end

  def upload_url_params(params, content) do
    params
    |> Map.take([:filename, :alt_txt, :snippet_type])
    |> Map.put(:length, byte_size(content))
    |> Data.compact()
  end

  def complete_upload_params(params, upload) do
    file =
      %{id: Data.get(upload, :file_id), title: Data.get(params, :title)}
      |> Data.compact()

    params
    |> Map.take([:channel_id, :initial_comment, :thread_ts])
    |> Map.put(:files, [file])
    |> Data.compact()
  end

  def share_file_params(params) do
    file =
      %{id: Data.get(params, :file_id), title: Data.get(params, :title)}
      |> Data.compact()

    params
    |> Map.take([:channels, :initial_comment, :thread_ts])
    |> Map.put(:files, [file])
    |> Data.compact()
  end

  def maybe_join_users(%{users: users} = params) when is_list(users) do
    Map.put(params, :users, Enum.join(users, ","))
  end

  def maybe_join_users(params), do: params

  def delete_file_params(params) do
    params
    |> Map.take([:file_id])
    |> Map.new(fn {:file_id, file_id} -> {:file, file_id} end)
    |> Data.compact()
  end
end
