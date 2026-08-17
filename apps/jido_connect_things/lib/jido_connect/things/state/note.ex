defmodule Jido.Connect.Things.State.Note do
  @moduledoc false

  @maximum_patch_count 1_000
  @maximum_crc32 4_294_967_295

  def apply(current, current_state, note)

  def apply(_current, _current_state, nil), do: {"", :complete, []}
  def apply(_current, _current_state, note) when is_binary(note), do: {note, :complete, []}

  def apply(_current, _current_state, %{"v" => value}) when is_binary(value),
    do: {value, :complete, []}

  def apply(_current, _current_state, %{"t" => 1, "v" => value} = note)
      when is_binary(value) do
    if valid_checksum?(note, value) do
      {value, :complete, []}
    else
      {value, :incomplete, [issue(:full_note_checksum_mismatch)]}
    end
  end

  def apply(current, :complete, %{"t" => 2, "ps" => patches} = note)
      when is_binary(current) and is_list(patches) and length(patches) <= @maximum_patch_count do
    with :ok <- validate_base_checksum(note, current),
         {:ok, result} <- apply_patches(current, patches) do
      {result, :complete, []}
    else
      {:error, reason} -> {current, :incomplete, [issue(reason)]}
    end
  end

  def apply(current, _current_state, _note) do
    {current || "", :incomplete, [issue(:unsupported_note_shape)]}
  end

  defp apply_patches(current, patches) do
    patches
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, current}, fn {patch, index}, {:ok, text} ->
      case apply_patch(text, patch) do
        {:ok, text} -> {:cont, {:ok, text}}
        {:error, reason} -> {:halt, {:error, {:invalid_note_patch, index, reason}}}
      end
    end)
  end

  defp apply_patch(text, %{"r" => replacement, "p" => position, "l" => length} = patch)
       when is_binary(replacement) and is_integer(position) and is_integer(length) and
              position >= 0 and
              length >= 0 do
    codepoints = String.codepoints(text)
    count = length(codepoints)

    cond do
      position > count ->
        {:error, :position_out_of_bounds}

      position + length > count ->
        {:error, :length_out_of_bounds}

      not valid_patch_checksum?(patch) ->
        {:error, :checksum_out_of_bounds}

      true ->
        {prefix, rest} = Enum.split(codepoints, position)
        {_removed, suffix} = Enum.split(rest, length)
        {:ok, IO.iodata_to_binary([prefix, replacement, suffix])}
    end
  end

  defp apply_patch(_text, _patch), do: {:error, :invalid_shape}

  defp validate_base_checksum(%{"ch" => checksum}, current)
       when is_integer(checksum) and checksum in 0..@maximum_crc32 do
    if checksum == :erlang.crc32(current), do: :ok, else: {:error, :base_checksum_mismatch}
  end

  defp validate_base_checksum(%{"ch" => _checksum}, _current),
    do: {:error, :base_checksum_out_of_bounds}

  defp validate_base_checksum(_note, _current), do: :ok

  defp valid_checksum?(%{"ch" => checksum}, value)
       when is_integer(checksum) and checksum in 0..@maximum_crc32,
       do: checksum == :erlang.crc32(value)

  defp valid_checksum?(%{"ch" => _checksum}, _value), do: false
  defp valid_checksum?(_note, _value), do: true

  defp valid_patch_checksum?(%{"ch" => checksum})
       when is_integer(checksum) and checksum in 0..@maximum_crc32,
       do: true

  defp valid_patch_checksum?(%{"ch" => _checksum}), do: false
  defp valid_patch_checksum?(_patch), do: true

  defp issue(reason), do: %{field: "nt", reason: reason}
end
