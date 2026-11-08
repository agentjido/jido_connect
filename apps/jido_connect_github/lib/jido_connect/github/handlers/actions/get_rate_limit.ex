defmodule Jido.Connect.GitHub.Handlers.Actions.GetRateLimit do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(_input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime) do
      client.get_rate_limit(token)
    end
  end
end
