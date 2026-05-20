defmodule Jido.Connect.Asana.Client.Stories do
  @moduledoc "Asana story (comment/activity) API boundary."

  alias Jido.Connect.Asana.Client.{Response, Transport}

  @opt_fields ~w(resource_type resource_subtype text html_text is_pinned sticker_name num_likes liked created_by target task project created_at)

  @spec list(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(task_gid, access_token, opts \\ [])
      when is_binary(task_gid) and is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:offset, Keyword.get(opts, :offset))
      |> Map.put(:opt_fields, Keyword.get(opts, :opt_fields, Enum.join(@opt_fields, ",")))

    encoded_task = URI.encode(task_gid, &URI.char_unreserved?/1)

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/tasks/#{encoded_task}/stories", params: params)
    |> Response.handle_story_list_response()
  end

  @spec create(String.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create(task_gid, access_token, story_params, opts \\ [])
      when is_binary(task_gid) and is_binary(access_token) and is_map(story_params) and
             is_list(opts) do
    body = %{"data" => story_params}
    encoded_task = URI.encode(task_gid, &URI.char_unreserved?/1)

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.post(url: "/tasks/#{encoded_task}/stories", json: body)
    |> Response.handle_story_response()
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)
end
