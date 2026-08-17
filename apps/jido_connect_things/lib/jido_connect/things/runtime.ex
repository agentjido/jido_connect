defmodule Jido.Connect.Things.Runtime do
  @moduledoc false

  alias Jido.Connect.{Context, CredentialLease, Error}
  alias Jido.Connect.Things.{Client, Input, PreparedWrite, Writer}

  @runtime_key :jido_connect_things_runtime
  @write_actions ["things.todo.create", "things.todo.update"]

  def prepare(action_id, input, opts) when action_id in @write_actions do
    with {:ok, input} <- Input.parse(action_id, input),
         {:ok, context} <- context(opts),
         {:ok, lease} <- lease(opts),
         runtime <- runtime_options(opts),
         context <- inject_runtime(context, runtime),
         core_opts <- put_runtime(opts, context, lease),
         {:ok, core_prepared} <-
           Jido.Connect.prepare(Jido.Connect.Things, action_id, input, core_opts),
         {:ok, client} <- Client.from_runtime(context, lease, runtime),
         {:ok, provider_plan} <-
           Writer.prepare(action_id, input, client, context.connection, runtime) do
      core_prepared = %{core_prepared | preview: provider_plan.preview}
      {:ok, PreparedWrite.new(core_prepared, provider_plan)}
    end
  end

  def prepare(action_id, _input, _opts), do: {:error, Error.unknown_action(action_id)}

  def commit(%PreparedWrite{} = prepared, input, opts) do
    with :ok <- validate_prepared(prepared),
         {:ok, input} <- Input.parse(prepared.action.action_id, input),
         {:ok, context} <- context(opts),
         {:ok, lease} <- lease(opts) do
      runtime =
        opts
        |> runtime_options()
        |> Map.merge(%{
          commit?: option(opts, :commit?) == true,
          prepared_action_id: prepared.action.id,
          provider_plan: prepared.provider_plan
        })

      context = inject_runtime(context, runtime)
      core_opts = put_runtime(opts, context, lease)
      Jido.Connect.commit(Jido.Connect.Things, prepared.action, input, core_opts)
    end
  end

  def commit(_prepared, _input, _opts) do
    {:error,
     Error.validation("Invalid Things prepared write",
       reason: :invalid_prepared_write
     )}
  end

  def invoke(action_id, input, opts) do
    with {:ok, context} <- context(opts),
         {:ok, lease} <- lease(opts) do
      context = inject_runtime(context, runtime_options(opts))

      Jido.Connect.invoke(
        Jido.Connect.Things,
        action_id,
        input,
        put_runtime(opts, context, lease)
      )
    end
  end

  def runtime_context(%Context{} = context) do
    Map.get(context.metadata, @runtime_key, %{})
  end

  defp validate_prepared(%PreparedWrite{} = prepared) do
    if PreparedWrite.valid?(prepared) do
      :ok
    else
      {:error,
       Error.auth("Things prepared write changed before commit",
         reason: :prepared_write_changed
       )}
    end
  end

  defp context(opts) do
    case option(opts, :context) do
      %Context{} = context -> {:ok, context}
      attrs when is_map(attrs) -> normalize(Context.new(attrs), :context)
      _other -> {:error, Error.context_required()}
    end
  end

  defp lease(opts) do
    case option(opts, :credential_lease) do
      %CredentialLease{} = lease -> {:ok, lease}
      attrs when is_map(attrs) -> normalize(CredentialLease.new(attrs), :credential_lease)
      _other -> {:error, Error.credential_lease_required()}
    end
  end

  defp normalize({:ok, value}, _field), do: {:ok, value}
  defp normalize({:error, errors}, field), do: {:error, Error.zoi(field, errors)}

  defp inject_runtime(%Context{} = context, runtime) do
    %{context | metadata: Map.put(context.metadata, @runtime_key, runtime)}
  end

  defp runtime_options(opts) do
    [:transport, :read_adapter, :id_generator, :now, :lock]
    |> Enum.reduce(%{}, fn key, runtime ->
      case option(opts, key) do
        nil -> runtime
        value -> Map.put(runtime, key, value)
      end
    end)
  end

  defp put_runtime(opts, context, lease) when is_list(opts) do
    opts
    |> Keyword.put(:context, context)
    |> Keyword.put(:credential_lease, lease)
  end

  defp put_runtime(opts, context, lease) when is_map(opts) do
    opts
    |> Map.put(:context, context)
    |> Map.put(:credential_lease, lease)
  end

  defp option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp option(opts, key) when is_map(opts), do: Map.get(opts, key)
end
