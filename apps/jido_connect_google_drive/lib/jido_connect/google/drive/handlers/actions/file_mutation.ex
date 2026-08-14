defmodule Jido.Connect.Google.Drive.Handlers.Actions.FileMutation do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Client

  def run(input, credentials, operation) when is_map(input) and is_map(credentials) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, file} <-
           apply(client, operation, [
             normalize_input(input),
             Map.get(credentials, :access_token)
           ]) do
      {:ok, %{file: public_map(file)}}
    end
  end

  defmacro __using__(operation: operation) do
    quote bind_quoted: [operation: operation] do
      @operation operation

      def run(input, %{credentials: credentials}) do
        Jido.Connect.Google.Drive.Handlers.Actions.FileMutation.run(
          input,
          credentials,
          @operation
        )
      end
    end
  end

  defp normalize_input(input), do: Map.put_new(input, :supports_all_drives, false)

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct),
    do: struct |> Map.from_struct() |> public_map()

  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map) do
    map
    |> Map.update(:owners, [], &public_map/1)
    |> Map.update(:permissions, [], &public_map/1)
  end

  defp public_map(value), do: value
end
