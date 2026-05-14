defmodule Jido.Connect.Google.Drive.Handlers.Actions.ChannelLifecycle do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  @channel_types ["web_hook", "webhook"]

  def validate_watch_input(input, required_fields) do
    with :ok <- validate_channel_id(input),
         :ok <- validate_address(input),
         :ok <- validate_channel_type(Data.get(input, :channel_type, "web_hook")) do
      Enum.reduce_while(required_fields, :ok, fn field, :ok ->
        case require_present(input, field) do
          :ok -> {:cont, :ok}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)
    end
  end

  def validate_stop_input(input) do
    with :ok <- validate_channel_id(input),
         :ok <- require_present(input, :resource_id) do
      :ok
    end
  end

  def normalize_input(input, defaults) do
    defaults
    |> Map.merge(input)
    |> trim_string(:channel_id)
    |> trim_string(:channel_type)
    |> trim_string(:address)
    |> trim_string(:file_id)
    |> trim_string(:page_token)
    |> trim_string(:resource_id)
    |> trim_string(:token)
  end

  def fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  def public_map(map) when is_map(map), do: map
  def public_map(value), do: value

  defp require_present(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          invalid_field(field)
        else
          :ok
        end

      _missing ->
        invalid_field(field)
    end
  end

  defp validate_channel_id(input) do
    with :ok <- require_present(input, :channel_id) do
      channel_id = input |> Data.get(:channel_id) |> String.trim()

      if String.length(channel_id) <= 64 do
        :ok
      else
        {:error,
         Error.validation("Google Drive channel channel_id must be 64 characters or fewer",
           reason: :invalid_drive_channel,
           details: %{field: :channel_id, max_length: 64}
         )}
      end
    end
  end

  defp validate_address(input) do
    with :ok <- require_present(input, :address) do
      address = input |> Data.get(:address) |> String.trim()
      uri = URI.parse(address)

      if uri.scheme == "https" and is_binary(uri.host) and uri.host != "" do
        :ok
      else
        {:error,
         Error.validation("Google Drive channel address must be an HTTPS URL",
           reason: :invalid_drive_channel,
           details: %{field: :address}
         )}
      end
    end
  end

  defp validate_channel_type(type) when is_binary(type) do
    if String.trim(type) in @channel_types do
      :ok
    else
      invalid_channel_type(type)
    end
  end

  defp validate_channel_type(type), do: invalid_channel_type(type)

  defp invalid_channel_type(type) do
    {:error,
     Error.validation("Google Drive watch channel_type is invalid",
       reason: :invalid_drive_channel,
       details: %{field: :channel_type, value: type, allowed: @channel_types}
     )}
  end

  defp invalid_field(field) do
    {:error,
     Error.validation("Google Drive channel #{field} must be a non-empty string",
       reason: :invalid_drive_channel,
       details: %{field: field}
     )}
  end

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end
end
