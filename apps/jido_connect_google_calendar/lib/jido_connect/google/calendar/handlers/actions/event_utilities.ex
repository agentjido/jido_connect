defmodule Jido.Connect.Google.Calendar.Handlers.Actions.EventUtilities do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.ResourceHelpers

  @send_updates ["all", "externalOnly", "none"]
  @reason :invalid_event_utility

  def validate_instances(input) do
    validate_required(input, [:calendar_id, :event_id])
  end

  def validate_move(input) do
    with :ok <- validate_required(input, [:calendar_id, :event_id, :destination_calendar_id]),
         :ok <- ResourceHelpers.validate_enum(input, :send_updates, @send_updates, @reason) do
      :ok
    end
  end

  def normalize_input(input, defaults \\ %{}) do
    ResourceHelpers.normalize_input(input, defaults, [
      :calendar_id,
      :event_id,
      :destination_calendar_id,
      :page_token
    ])
  end

  defp validate_required(input, fields) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      case ResourceHelpers.require_present(input, field, @reason) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end
end
