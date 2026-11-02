defmodule Jido.Connect.Gmail.MIME.Charset do
  @moduledoc """
  Decodes the text bytes of Gmail MIME parts into UTF-8 strings.

  Supports `utf-8`, `us-ascii`, `iso-8859-1`, `iso-8859-15` and `windows-1252`
  with OTP alone. Names are matched without regard to case. The aliases of
  these charsets in the IANA character set registry, such as `latin1`,
  `ISO_8859-1` or `Latin-9`, decode like the names they stand for, and so do
  the common `utf8` and `cp1252`. Other charsets, and bytes that are invalid
  for their charset, return `:error`, so the caller keeps the bytes.
  """

  # Aliases from the IANA character set registry, plus utf8 and cp1252, in
  # lower case.
  @aliases for {name, aliases} <- [
                 {"utf-8", ~w(utf8 csutf8)},
                 {"us-ascii",
                  ~w(ansi_x3.4-1968 iso-ir-6 ansi_x3.4-1986 iso_646.irv:1991 iso646-us us
                      ibm367 cp367 csascii)},
                 {"iso-8859-1",
                  ~w(iso_8859-1:1987 iso-ir-100 iso_8859-1 latin1 l1 ibm819 cp819 csisolatin1)},
                 {"iso-8859-15", ~w(iso_8859-15 latin-9 csiso885915)},
                 {"windows-1252", ~w(cp1252 cswindows1252)}
               ],
               alias_name <- aliases,
               into: %{},
               do: {alias_name, name}

  # ISO-8859-15 differs from ISO-8859-1 in eight positions.
  @latin9 %{
    0xA4 => 0x20AC,
    0xA6 => 0x0160,
    0xA8 => 0x0161,
    0xB4 => 0x017D,
    0xB8 => 0x017E,
    0xBC => 0x0152,
    0xBD => 0x0153,
    0xBE => 0x0178
  }

  # Windows-1252 assigns 27 of the 32 positions 0x80..0x9F; 0x81, 0x8D, 0x8F,
  # 0x90 and 0x9D are undefined. All other bytes match ISO-8859-1.
  @windows_1252 %{
    0x80 => 0x20AC,
    0x82 => 0x201A,
    0x83 => 0x0192,
    0x84 => 0x201E,
    0x85 => 0x2026,
    0x86 => 0x2020,
    0x87 => 0x2021,
    0x88 => 0x02C6,
    0x89 => 0x2030,
    0x8A => 0x0160,
    0x8B => 0x2039,
    0x8C => 0x0152,
    0x8E => 0x017D,
    0x91 => 0x2018,
    0x92 => 0x2019,
    0x93 => 0x201C,
    0x94 => 0x201D,
    0x95 => 0x2022,
    0x96 => 0x2013,
    0x97 => 0x2014,
    0x98 => 0x02DC,
    0x99 => 0x2122,
    0x9A => 0x0161,
    0x9B => 0x203A,
    0x9C => 0x0153,
    0x9E => 0x017E,
    0x9F => 0x0178
  }

  @windows_1252_undefined [0x81, 0x8D, 0x8F, 0x90, 0x9D]

  @doc "Decodes `bytes` declared as `charset` into a UTF-8 string."
  @spec decode(binary(), String.t()) :: {:ok, String.t()} | :error
  def decode(bytes, charset) when is_binary(bytes) and is_binary(charset) do
    charset = String.downcase(charset)
    decode_known(bytes, Map.get(@aliases, charset, charset))
  end

  defp decode_known(bytes, "utf-8"), do: if(String.valid?(bytes), do: {:ok, bytes}, else: :error)

  defp decode_known(bytes, "us-ascii"),
    do: if(ascii?(bytes), do: {:ok, bytes}, else: :error)

  defp decode_known(bytes, "iso-8859-1"), do: {:ok, map_bytes(bytes, %{})}
  defp decode_known(bytes, "iso-8859-15"), do: {:ok, map_bytes(bytes, @latin9)}

  defp decode_known(bytes, "windows-1252") do
    if :binary.match(bytes, Enum.map(@windows_1252_undefined, &<<&1>>)) == :nomatch do
      {:ok, map_bytes(bytes, @windows_1252)}
    else
      :error
    end
  end

  defp decode_known(_bytes, _charset), do: :error

  defp ascii?(<<>>), do: true
  defp ascii?(<<byte, rest::binary>>) when byte < 0x80, do: ascii?(rest)
  defp ascii?(_bytes), do: false

  defp map_bytes(bytes, overrides) do
    for <<byte <- bytes>>, into: "", do: <<Map.get(overrides, byte, byte)::utf8>>
  end
end
