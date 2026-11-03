defmodule Jido.Connect.Tempo.WorkAttribute do
  @moduledoc """
  Normalized Tempo work attribute: a field of the time-entry form that a
  worklog may or must carry a value for.

  `normalize/1` reads one attribute of `GET /4/work-attributes` through an
  allowlist:

  | Field | Tempo field | When Tempo leaves it out |
  | --- | --- | --- |
  | `key` | `key`, a non-empty string | error |
  | `name` | `name`, a string | error |
  | `type` | `type`, a non-empty string, kept raw | error |
  | `required` | `required`, a boolean | error |
  | `self` | `self`, Tempo's link to the attribute | `nil` |
  | `values` | for `STATIC_LIST` only: `values`, each with its label from `names` | `nil` |

  Keys and types stay strings; no atom is created for them. A key is opaque:
  the package never derives meaning from it, and it does not assume that
  an attribute of type `ACCOUNT` is called `_Account_`.

  ## Types and Values

  Tempo stores every work attribute value of a worklog as a string. The
  supported types and the value each stores, as recorded on the test site
  on 2026-11-03:

  | Type | Value |
  | --- | --- |
  | `ACCOUNT` | the account `key`, such as `JCL-PROJECT`, not its name or numeric ID; see `tempo.account.list_for_project` |
  | `CHECKBOX` | `"true"` for a checked box |
  | `INPUT_FIELD` | the free text as entered, such as `"JCL live note"` |
  | `INPUT_NUMERIC` | the number as a decimal string, such as `"1.5"` |
  | `STATIC_LIST` | one of the stored `values`, a Tempo-assigned ID such as a UUID, not its label |

  `values` is a list of `%{value: value, label: label}` maps in Tempo's
  order. The stored value is immutable; the label from `names` can be
  renamed and two labels can be equal, so the stored value identifies a
  choice. A label Tempo does not send is `nil`. A `STATIC_LIST` without a
  `values` list has `values: nil`: its choices are unknown, which is not an
  empty choice list (`[]`). For every other type `values` is `nil`.

  Any other type, such as `DYNAMIC_DROPDOWN`, is kept as the raw string.
  `incomplete/1` reports a required attribute whose value the package
  cannot describe.
  """

  @supported_types ["ACCOUNT", "CHECKBOX", "INPUT_FIELD", "INPUT_NUMERIC", "STATIC_LIST"]

  @schema Zoi.struct(
            __MODULE__,
            %{
              key: Zoi.string() |> Zoi.min(1),
              name: Zoi.string(),
              type: Zoi.string() |> Zoi.min(1),
              required: Zoi.boolean(),
              self: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              values:
                Zoi.list(
                  Zoi.map(%{
                    value: Zoi.string() |> Zoi.min(1),
                    label: Zoi.string() |> Zoi.nullable()
                  })
                )
                |> Zoi.nullish()
                |> Zoi.optional()
            },
            coerce: true
          )

  @type choice :: %{value: String.t(), label: String.t() | nil}
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @fields [:key, :name, :type, :required, :self]

  @doc "Returns the types whose values the package describes."
  @spec supported_types() :: [String.t()]
  def supported_types, do: @supported_types

  @doc """
  Normalizes one Tempo work attribute.

  Returns `{:error, field}` with the Tempo field of a missing or malformed
  value, or `{:error, "attribute"}` when the value is not a map.
  """
  @spec normalize(term()) :: {:ok, t()} | {:error, String.t()}
  def normalize(payload) when is_map(payload) do
    attrs = Map.new(@fields, &{&1, Map.get(payload, Atom.to_string(&1))})

    with {:ok, values} <- values(payload) do
      case Zoi.parse(@schema, Map.put(attrs, :values, values)) do
        {:ok, attribute} -> {:ok, attribute}
        {:error, [%Zoi.Error{path: [field | _rest]} | _errors]} -> {:error, to_string(field)}
      end
    end
  end

  def normalize(_payload), do: {:error, "attribute"}

  @doc "Returns whether the package describes the values of the attribute's type."
  @spec supported?(t()) :: boolean()
  def supported?(%__MODULE__{type: type}), do: type in @supported_types

  @doc """
  Returns why a required attribute's value cannot be described, or `nil`.

  `:unsupported_type` for a required attribute of a type outside
  `supported_types/0`, `:missing_choices` for a required `STATIC_LIST`
  without a choice list. An optional attribute is never incomplete.
  """
  @spec incomplete(t()) :: :unsupported_type | :missing_choices | nil
  def incomplete(%__MODULE__{required: false}), do: nil

  def incomplete(%__MODULE__{} = attribute) do
    cond do
      not supported?(attribute) -> :unsupported_type
      attribute.type == "STATIC_LIST" and is_nil(attribute.values) -> :missing_choices
      true -> nil
    end
  end

  @doc "Returns the attribute as a plain map for action output."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = attribute), do: Map.from_struct(attribute)

  # Only a static list has choices; its stored values come from `values`,
  # their labels from `names`.
  defp values(%{"type" => "STATIC_LIST"} = payload) do
    with {:ok, names} <- names(Map.get(payload, "names")) do
      case Map.get(payload, "values") do
        nil ->
          {:ok, nil}

        values when is_list(values) ->
          if Enum.all?(values, &is_binary/1),
            do: {:ok, Enum.map(values, &%{value: &1, label: Map.get(names, &1)})},
            else: {:error, "values"}

        _other ->
          {:error, "values"}
      end
    end
  end

  defp values(_payload), do: {:ok, nil}

  defp names(nil), do: {:ok, %{}}

  defp names(names) when is_map(names) do
    if Enum.all?(names, fn {_value, label} -> is_binary(label) end),
      do: {:ok, names},
      else: {:error, "names"}
  end

  defp names(_names), do: {:error, "names"}
end
