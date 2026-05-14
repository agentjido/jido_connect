defmodule Jido.Connect.Google.Calendar.Handlers.Actions.AclResource do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Calendar.Handlers.Actions.ResourceHelpers

  @roles ["none", "freeBusyReader", "reader", "writer", "owner"]
  @scope_types ["default", "user", "group", "domain"]
  @reason :invalid_acl_rule

  def validate_read(input, required_fields) do
    validate_required(input, required_fields)
  end

  def validate_mutation(input, required_fields) do
    with :ok <- validate_required(input, required_fields),
         :ok <- ResourceHelpers.validate_enum(input, :role, @roles, @reason),
         :ok <- ResourceHelpers.validate_enum(input, :scope_type, @scope_types, @reason),
         :ok <- validate_scope_value(input) do
      :ok
    end
  end

  def normalize_input(input, defaults \\ %{}) do
    ResourceHelpers.normalize_input(input, defaults, [
      :calendar_id,
      :acl_rule_id,
      :role,
      :scope_type,
      :scope_value,
      :page_token,
      :sync_token
    ])
  end

  defp validate_required(input, fields) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      case ResourceHelpers.require_present(input, field, @reason) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_scope_value(input) do
    case Data.get(input, :scope_type) do
      scope_type when scope_type in [nil, "default"] ->
        :ok

      _scope_type ->
        ResourceHelpers.require_present(input, :scope_value, @reason)
    end
  end
end
