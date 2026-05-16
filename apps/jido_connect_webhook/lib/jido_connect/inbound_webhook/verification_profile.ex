defmodule Jido.Connect.InboundWebhook.VerificationProfile do
  @moduledoc """
  Configuration struct for HMAC-based webhook verification.

  Each webhook endpoint may use a different signature scheme. This struct
  normalizes the verification parameters so the generic verification
  primitives can adapt to different providers:

  - `signature_header`: the HTTP header carrying the HMAC signature
  - `timestamp_header`: the HTTP header carrying the request timestamp (if any)
  - `digest_prefix`: a prefix prepended to the hex digest in the signature header
    (e.g. `"sha256="` for GitHub, `"v0="` for Slack)
  - `timestamp_tolerance_seconds`: how many seconds of clock skew to tolerate
    (set to `nil` to skip timestamp validation)

  The struct does **not** store the signing secret itself. Secrets are held
  in the host credential lease and passed to verification functions at runtime.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              signature_header: Zoi.string() |> Zoi.default("x-signature"),
              timestamp_header: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              digest_prefix: Zoi.string() |> Zoi.default(""),
              timestamp_tolerance_seconds: Zoi.integer() |> Zoi.nullish() |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
