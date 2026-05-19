defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetProfile do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  def run(_input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    request = Transport.request(access_token)

    case Transport.request(request, :get, url: "/me") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, %{profile: normalize_profile(body)}}

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to fetch Outlook profile"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error, message: "Failed to fetch Outlook profile")
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp normalize_profile(body) do
    %{
      user_id: Map.get(body, "id"),
      display_name: Map.get(body, "displayName"),
      email: Map.get(body, "mail"),
      user_principal_name: Map.get(body, "userPrincipalName")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
