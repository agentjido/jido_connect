defmodule Jido.Connect.Gmail.Handlers.Actions.UpdateDraft do
  @moduledoc false

  alias Jido.Connect.Gmail.{Handlers.Actions.Mutation, MIME}

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_id(input, :draft_id),
         {:ok, raw} <- MIME.build_raw(input) do
      input
      |> Map.put(:raw, raw)
      |> Mutation.run_client(credentials, :update_draft, :draft)
    end
  end
end
