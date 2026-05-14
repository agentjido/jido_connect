defmodule Jido.Connect.Gmail.Client do
  @moduledoc "Gmail API client facade."

  alias Jido.Connect.Gmail.Client.Users

  defdelegate get_profile(params, access_token), to: Users
  defdelegate list_labels(params, access_token), to: Users
  defdelegate list_messages(params, access_token), to: Users
  defdelegate get_message(params, access_token), to: Users
  defdelegate list_threads(params, access_token), to: Users
  defdelegate get_thread(params, access_token), to: Users
  defdelegate list_history(params, access_token), to: Users
  defdelegate get_attachment(params, access_token), to: Users
  defdelegate start_watch(params, access_token), to: Users
  defdelegate stop_watch(params, access_token), to: Users
  defdelegate send_message(params, access_token), to: Users
  defdelegate create_draft(params, access_token), to: Users
  defdelegate send_draft(params, access_token), to: Users
  defdelegate create_label(params, access_token), to: Users
  defdelegate apply_message_labels(params, access_token), to: Users
end
