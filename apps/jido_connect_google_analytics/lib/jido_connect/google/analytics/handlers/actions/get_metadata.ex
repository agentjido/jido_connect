defmodule Jido.Connect.Google.Analytics.Handlers.Actions.GetMetadata do
  @moduledoc false

  alias Jido.Connect.Google.Analytics.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, params} <- ResourceHelpers.metadata_input(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.get_metadata(params, Map.get(credentials, :access_token)) do
      {:ok,
       %{
         metadata_name: Map.get(result, :metadata_name),
         dimensions:
           result
           |> Map.get(:dimensions, [])
           |> Enum.map(&ResourceHelpers.public_map/1),
         metrics:
           result
           |> Map.get(:metrics, [])
           |> Enum.map(&ResourceHelpers.public_map/1),
         comparisons: Map.get(result, :comparisons, [])
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end
end
