defmodule Jido.Connect.Things.Identifier do
  @moduledoc """
  Creates and validates canonical Things object identifiers.

  Things encodes exactly 16 bytes with the Bitcoin Base58 alphabet. The final
  write boundary rejects every non-canonical value.
  """

  import Bitwise

  @alphabet "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  @alphabet_tuple @alphabet |> String.to_charlist() |> List.to_tuple()
  @decode_table @alphabet |> String.to_charlist() |> Enum.with_index() |> Map.new()

  @type reason :: :empty | :invalid_character | :non_canonical | :wrong_length

  def new do
    <<prefix::binary-size(6), version, byte_7, variant, suffix::binary-size(7)>> =
      :crypto.strong_rand_bytes(16)

    bytes =
      <<prefix::binary, bor(band(version, 0x0F), 0x40), byte_7, bor(band(variant, 0x3F), 0x80),
        suffix::binary>>

    {:ok, identifier} = encode(bytes)
    identifier
  end

  def encode(bytes) when is_binary(bytes) and byte_size(bytes) == 16 do
    leading_zeroes = count_leading(bytes, 0)
    encoded = bytes |> :binary.decode_unsigned() |> encode_integer([])
    {:ok, String.duplicate("1", leading_zeroes) <> List.to_string(encoded)}
  end

  def encode(_bytes), do: {:error, :wrong_length}

  def decode(identifier) when is_binary(identifier) do
    characters = String.to_charlist(identifier)

    if characters == [] do
      {:error, :empty}
    else
      with {leading_ones, rest} <- Enum.split_while(characters, &(&1 == ?1)),
           {:ok, integer} <- decode_integer(rest),
           decoded <- :binary.copy(<<0>>, length(leading_ones)) <> unsigned_binary(integer),
           true <- byte_size(decoded) == 16 || {:error, :wrong_length},
           {:ok, ^identifier} <- encode(decoded) do
        {:ok, decoded}
      else
        {:error, reason} -> {:error, reason}
        _other -> {:error, :non_canonical}
      end
    end
  end

  def decode(_identifier), do: {:error, :non_canonical}

  def validate(identifier) do
    case decode(identifier) do
      {:ok, _bytes} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp count_leading(<<0, rest::binary>>, count), do: count_leading(rest, count + 1)
  defp count_leading(_bytes, count), do: count

  defp encode_integer(0, encoded), do: encoded

  defp encode_integer(integer, encoded) do
    encode_integer(div(integer, 58), [elem(@alphabet_tuple, rem(integer, 58)) | encoded])
  end

  defp decode_integer(characters) do
    Enum.reduce_while(characters, {:ok, 0}, fn character, {:ok, integer} ->
      case Map.fetch(@decode_table, character) do
        {:ok, value} -> {:cont, {:ok, integer * 58 + value}}
        :error -> {:halt, {:error, :invalid_character}}
      end
    end)
  end

  defp unsigned_binary(0), do: <<>>
  defp unsigned_binary(integer), do: :binary.encode_unsigned(integer)
end
