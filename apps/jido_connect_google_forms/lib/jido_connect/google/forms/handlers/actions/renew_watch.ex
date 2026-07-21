defmodule Jido.Connect.Google.Forms.Handlers.Actions.RenewWatch do
  @moduledoc false

  alias Jido.Connect.{Error, Google.Forms.Client}

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, watch} <-
           client.renew_watch(input, Map.get(credentials, :access_token)) do
      {:ok, %{watch: public_map(watch)}}
    end
  end

  defp validate_input(input) do
    with :ok <- require_present(input, :form_id),
         :ok <- require_present(input, :watch_id) do
      :ok
    end
  end

  defp require_present(input, field) do
    case Map.get(input, field) do
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

  defp invalid_field(field) do
    {:error,
     Error.validation("Google Forms watch #{field} must be a non-empty string",
       reason: :invalid_forms_watch,
       details: %{field: field}
     )}
  end

  defp fetch_client(%{google_forms_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
