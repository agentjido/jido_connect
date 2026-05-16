defmodule Jido.Connect.InboundWebhook.VerificationProfile do
  @moduledoc """
  Configuration struct for webhook verification.

  Each webhook endpoint may use a different signature scheme. This struct
  normalizes the verification parameters so the generic verification
  primitives can adapt to different providers:

  ## Modes

  - `:hmac` — shared-secret HMAC-SHA256 (default)
  - `:bearer` — static bearer/token compared against a known token
  - `:unsigned` — skips all signature checks (dev/test only)

  ## Fields

  - `mode` — verification mode (`:hmac`, `:bearer`, or `:unsigned`)
  - `signature_header` — the HTTP header carrying the HMAC signature or bearer token
  - `timestamp_header` — the HTTP header carrying the request timestamp (if any)
  - `digest_prefix` — prefix prepended to the hex digest (e.g. `"sha256="`, `"v0="`)
  - `timestamp_tolerance_seconds` — clock-skew tolerance in seconds (`nil` to skip)
  - `replay_id_header` — header carrying the unique delivery/event ID for replay
    protection. When set, `verify_request/5` and `verify_delivery/5` extract the
    replay ID from this header automatically unless one is supplied via opts.

  The struct does **not** store secrets. Secrets are held in the host credential
  lease and passed to verification functions at runtime.
  """

  @modes [:hmac, :bearer, :unsigned]

  @schema Zoi.struct(
            __MODULE__,
            %{
              mode: Zoi.enum(@modes) |> Zoi.default(:hmac),
              signature_header: Zoi.string() |> Zoi.default("x-signature"),
              timestamp_header: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              digest_prefix: Zoi.string() |> Zoi.default(""),
              timestamp_tolerance_seconds: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              replay_id_header: Zoi.string() |> Zoi.nullish() |> Zoi.optional()
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
