defmodule Jido.Connect.Slack.Interactivity.BlockActions do
  @moduledoc false

  # Turns a `block_actions` payload into a block action signal: the fields
  # of `Jido.Connect.Slack.BlockAction` that are not nil.
  #
  # Only a click on one button in a message is taken. Every value is read at
  # a fixed payload path. A click on several actions, on another element,
  # outside a message or in an ephemeral message fails with
  # `:unsupported_block_action`. A missing or empty required value, a value
  # that is no string, or a step on a path that is no object fails with
  # `:invalid_block_action`; a payload without a workspace fails with
  # `:no_workspace`, a click that names two messages with
  # `:conflicting_block_action`. The details name payload paths and never a
  # value, so no button value leaves through an error.

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Slack.BlockAction

  @fields [
    api_app_id: ["api_app_id"],
    team_id: ["team", "id"],
    enterprise_id: ["enterprise", "id"],
    user_id: ["user", "id"],
    user_team_id: ["user", "team_id"],
    action_id: ["actions", "0", "action_id"],
    block_id: ["actions", "0", "block_id"],
    value: ["actions", "0", "value"],
    action_ts: ["actions", "0", "action_ts"]
  ]

  # The container and the message both name the message. Where both carry a
  # value, they must agree.
  @message_fields [
    channel_id: {["container", "channel_id"], ["channel", "id"], :required},
    message_ts: {["container", "message_ts"], ["message", "ts"], :required},
    thread_ts: {["container", "thread_ts"], ["message", "thread_ts"], :optional}
  ]

  @paths Map.new(
           @fields ++
             for({key, {container, _message, _required}} <- @message_fields, do: {key, container})
         )

  @doc false
  def normalize_signal(payload, opts) when is_map(payload) do
    with :ok <- require_type(payload, ["container", "type"], "message"),
         :ok <- reject_ephemeral(payload),
         :ok <- require_single_action(payload),
         :ok <- require_type(payload, ["actions", "0", "type"], "button"),
         :ok <- require_workspace(payload),
         {:ok, attrs} <- attrs(payload),
         {:ok, message_attrs} <- message_attrs(payload),
         {:ok, block_action} <- build(Map.merge(attrs, message_attrs)),
         :ok <- require_app(block_action, Keyword.get(opts, :api_app_id)) do
      {:ok, to_signal(block_action)}
    end
  end

  # The type at `path` must be `expected`. Another type is unsupported; a
  # missing type or one that is no string is malformed.
  defp require_type(payload, path, expected) do
    case value_at(payload, path) do
      {:ok, ^expected} -> :ok
      {:ok, type} when is_binary(type) and type != "" -> {:error, unsupported(path)}
      {:ok, _missing} -> {:error, invalid(path)}
      {:error, _reason} = error -> error
    end
  end

  # A button in an ephemeral message arrives without a `message` object, so
  # the click names no message the package could check. No such click was
  # captured.
  defp reject_ephemeral(%{"container" => %{"is_ephemeral" => true}}),
    do: {:error, unsupported(["container", "is_ephemeral"])}

  defp reject_ephemeral(_payload), do: :ok

  defp require_single_action(%{"actions" => [%{}]}), do: :ok
  defp require_single_action(%{"actions" => [_action]}), do: {:error, invalid(["actions", "0"])}

  defp require_single_action(%{"actions" => actions}) when is_list(actions),
    do: {:error, unsupported(["actions"])}

  defp require_single_action(_payload), do: {:error, invalid(["actions"])}

  # Only an app installed in a workspace is taken. An org-wide install sends
  # `is_enterprise_install: true` and, per Slack, `team: null`.
  defp require_workspace(%{"is_enterprise_install" => true}),
    do: {:error, no_workspace(["is_enterprise_install"])}

  defp require_workspace(payload) do
    case value_at(payload, ["team", "id"]) do
      {:ok, team_id} when team_id in [nil, ""] -> {:error, no_workspace(["team", "id"])}
      {:ok, _team_id} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp attrs(payload) do
    Enum.reduce_while(@fields, {:ok, %{}}, fn {key, path}, {:ok, attrs} ->
      case value_at(payload, path) do
        {:ok, value} -> {:cont, {:ok, Map.put(attrs, key, blank_to_nil(value))}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp message_attrs(payload) do
    Enum.reduce_while(@message_fields, {:ok, %{}}, fn {key, paths}, {:ok, attrs} ->
      case message_value(payload, paths) do
        {:ok, value} -> {:cont, {:ok, Map.put(attrs, key, value)}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp message_value(payload, {container_path, message_path, _kind} = paths) do
    with {:ok, container} <- string_at(payload, container_path),
         {:ok, message} <- string_at(payload, message_path) do
      same_message({container, message}, paths)
    end
  end

  defp same_message({nil, _message}, {path, _other, :required}), do: {:error, invalid(path)}
  defp same_message({_container, nil}, {_other, path, :required}), do: {:error, invalid(path)}
  defp same_message({value, value}, _paths), do: {:ok, value}
  defp same_message({nil, message}, _paths), do: {:ok, message}
  defp same_message({container, nil}, _paths), do: {:ok, container}

  defp same_message(_values, {container_path, message_path, _kind}),
    do: {:error, conflicting(container_path, message_path)}

  defp string_at(payload, path) do
    case value_at(payload, path) do
      {:ok, value} when is_binary(value) or is_nil(value) -> {:ok, blank_to_nil(value)}
      {:ok, _other} -> {:error, invalid(path)}
      {:error, _reason} = error -> error
    end
  end

  defp build(attrs) do
    case BlockAction.new(attrs) do
      {:ok, block_action} ->
        {:ok, block_action}

      {:error, [%Zoi.Error{path: [key | _rest]} | _errors]} ->
        {:error, invalid(Map.fetch!(@paths, key))}
    end
  end

  # With `:api_app_id`, the click must be for that app.
  defp require_app(_block_action, nil), do: :ok
  defp require_app(%BlockAction{api_app_id: app}, app), do: :ok

  defp require_app(_block_action, _expected) do
    {:error,
     Error.provider("Slack block action is for another app",
       provider: :slack,
       reason: :unexpected_app,
       details: %{field: "api_app_id"}
     )}
  end

  # The value at `path`, nil when an object on the way lacks the next key,
  # or an error that names the first step that is no object. "0" steps into
  # the first element of a list.
  defp value_at(value, path, walked \\ [])
  defp value_at(value, [], _walked), do: {:ok, value}
  defp value_at(nil, _path, _walked), do: {:ok, nil}

  defp value_at([first | _rest], ["0" | path], walked),
    do: value_at(first, path, ["0" | walked])

  defp value_at(map, [key | path], walked) when is_map(map),
    do: value_at(Map.get(map, key), path, [key | walked])

  defp value_at(_other, _path, walked), do: {:error, invalid(Enum.reverse(walked))}

  # Like `Data.compact/1`, an empty ID or timestamp counts as absent.
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp to_signal(%BlockAction{} = block_action) do
    block_action |> Map.from_struct() |> Data.compact()
  end

  defp path_name(path), do: Enum.join(path, ".")

  defp unsupported(path) do
    Error.provider("Slack block action is no single button in a message",
      provider: :slack,
      reason: :unsupported_block_action,
      details: %{field: path_name(path)}
    )
  end

  defp no_workspace(path) do
    Error.provider("Slack block action names no workspace",
      provider: :slack,
      reason: :no_workspace,
      details: %{field: path_name(path)}
    )
  end

  defp conflicting(path, other_path) do
    Error.provider("Slack block action names two messages",
      provider: :slack,
      reason: :conflicting_block_action,
      details: %{field: path_name(path), conflicts_with: path_name(other_path)}
    )
  end

  defp invalid(path) do
    Error.provider("Slack block action is malformed",
      provider: :slack,
      reason: :invalid_block_action,
      details: %{field: path_name(path)}
    )
  end
end
