defmodule Jido.Connect.Google.Meet.Handlers.Actions.SpaceResource do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.ResourceHelpers

  @reason :invalid_space_request

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
      :space_name,
      :fields,
      :access_type,
      :entry_point_access,
      :moderation,
      :attendance_report_generation_type
    ])
  end
end
