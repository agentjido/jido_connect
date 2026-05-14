defmodule Jido.Connect.Google.Calendar.Handlers.Actions.CalendarResource do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.ResourceHelpers

  @reason :invalid_calendar_request

  def validate_required(input, fields) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      case ResourceHelpers.require_present(input, field, @reason) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  def normalize_input(input, defaults \\ %{}) do
    ResourceHelpers.normalize_input(input, defaults, [
      :calendar_id,
      :summary,
      :summary_override,
      :description,
      :location,
      :time_zone,
      :color_id,
      :background_color,
      :foreground_color
    ])
  end
end
