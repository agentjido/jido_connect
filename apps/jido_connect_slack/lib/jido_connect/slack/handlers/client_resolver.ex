defmodule Jido.Connect.Slack.Handlers.ClientResolver do
  @moduledoc false

  alias Jido.Connect.Slack.Client

  def fetch(%{provider_client: client}, _credentials)
      when is_atom(client) and not is_nil(client),
      do: {:ok, client}

  def fetch(_context, %{slack_client: client}) when is_atom(client) and not is_nil(client),
    do: {:ok, client}

  def fetch(_context, _credentials), do: {:ok, Client}
end
