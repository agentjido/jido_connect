defmodule Jido.Connect.Microsoft.Account do
  @moduledoc "Normalized Microsoft account/profile metadata."

  alias Jido.Connect.Data

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              tenant_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              avatar_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              locale: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)

  @doc "Normalizes Microsoft Graph user payloads."
  @spec from_graph_user(map(), map()) :: {:ok, t()}
  def from_graph_user(attrs, metadata \\ %{}) when is_map(attrs) and is_map(metadata) do
    %{
      id: Data.get(attrs, "id"),
      email:
        Data.get(attrs, "mail") ||
          Data.get(attrs, "userPrincipalName"),
      display_name: Data.get(attrs, "displayName"),
      tenant_id: Data.get(attrs, "tenantId"),
      avatar_url: Data.get(attrs, "avatar_url"),
      locale: Data.get(attrs, "preferredLanguage"),
      metadata: metadata
    }
    |> Data.compact()
    |> new()
  end

  @doc "Bang variant of `from_graph_user/2`."
  @spec from_graph_user!(map(), map()) :: t()
  def from_graph_user!(attrs, metadata \\ %{}) when is_map(attrs) and is_map(metadata) do
    attrs
    |> from_graph_user(metadata)
    |> case do
      {:ok, account} -> account
      {:error, error} -> raise error
    end
  end

  @doc "Returns non-secret connection subject metadata for a Microsoft account."
  @spec to_subject(t()) :: map()
  def to_subject(%__MODULE__{} = account) do
    %{
      microsoft_account_id: account.id,
      email: account.email,
      display_name: account.display_name,
      tenant_id: account.tenant_id
    }
    |> Data.compact()
  end
end
