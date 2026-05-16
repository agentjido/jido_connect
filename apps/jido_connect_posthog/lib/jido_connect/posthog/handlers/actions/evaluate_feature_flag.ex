defmodule Jido.Connect.PostHog.Handlers.Actions.EvaluateFeatureFlag do
  @moduledoc false

  alias Jido.Connect.PostHog.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.decide_feature_flag(
             input.flag_key,
             input.distinct_id,
             token,
             groups: Map.get(input, :groups, %{}),
             person_properties: Map.get(input, :person_properties, %{})
           ) do
      {:ok, normalize_evaluation(input.flag_key, body)}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        Jido.Connect.PostHog.Client.Transport.handle_error_response(
          {:ok, %{status: status, body: body}}
        )

      {:error, reason} ->
        Jido.Connect.PostHog.Client.Transport.handle_error_response({:error, reason})
    end
  end

  defp fetch_client(%{posthog_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp normalize_evaluation(flag_key, %{"featureFlags" => flags} = body) do
    flag_result = Map.get(flags, flag_key, false)

    {enabled, variant} =
      case flag_result do
        true -> {true, nil}
        false -> {false, nil}
        variant when is_binary(variant) -> {true, variant}
        _ -> {false, nil}
      end

    %{
      flag_key: flag_key,
      enabled: enabled,
      variant: variant,
      reason: Map.get(body, "reason"),
      payload: get_in(body, ["featureFlagPayloads", flag_key])
    }
  end

  defp normalize_evaluation(flag_key, body) do
    %{
      flag_key: flag_key,
      enabled: Map.get(body, "enabled", false),
      variant: Map.get(body, "variant"),
      reason: Map.get(body, "reason"),
      payload: Map.get(body, "payload")
    }
  end
end
