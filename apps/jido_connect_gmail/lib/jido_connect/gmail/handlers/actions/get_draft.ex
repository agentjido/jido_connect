defmodule Jido.Connect.Gmail.Handlers.Actions.GetDraft do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_id(input, :draft_id) do
      Mutation.run_client(input, credentials, :get_draft, :draft)
    end
  end
end
