defmodule Jido.Connect.TestSupport.LiveSmoke.LeakError do
  @moduledoc """
  Raised when sanitized live smoke output still holds a credential value or an
  identifying value: a site or tunnel host, a configured email address, an
  account ID, a Google user ID or the Google project number.
  """

  defexception [:variable]

  @impl true
  def message(%__MODULE__{variable: variable}) do
    what = if variable =~ ~r/^[A-Z][A-Z0-9_]*$/, do: "the value of #{variable}", else: variable
    "live smoke output contains #{what}; nothing was written"
  end
end

defmodule Jido.Connect.TestSupport.LiveSmoke.Sanitize do
  @moduledoc false

  # Sanitizes recorded responses and captured deliveries. One state keeps the
  # placeholders for email addresses, display names, tenant hosts, account and
  # Google user IDs and configured fields stable across all values of one
  # recording or capture.

  alias Jido.Connect.Sanitizer
  alias Jido.Connect.TestSupport.LiveSmoke.LeakError

  @email_pattern "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)*\\.[A-Za-z]{2,}"
  @email Regex.compile!(@email_pattern)
  # A value made only of `Name <address>` and bare address entries, as in mail headers.
  @address_list ~r/^\s*(?:(?:(?:"[^"]*"|[^"<>,;:]*?)\s*<\s*#{@email_pattern}\s*>|#{@email_pattern})\s*(?:,\s*|$))+$/
  @named_address ~r/(?:"([^"]+)"|([^"<>,;:\s][^"<>,;:]*?))\s*<\s*#{@email_pattern}\s*>/
  @name_keys ~w(displayName display_name display_name_normalized real_name
                real_name_normalized publicName fullName full_name first_name last_name
                givenName familyName username user_name)
  # Keys whose values are Atlassian account IDs in Jira, Confluence and Tempo payloads.
  @account_keys ~w(accountId authorAccountId leadAccountId authorId ownerId lastOwnerId)
  @dropped_header ~r/auth|cookie|token|secret|signature|^x-forwarded-|^forwarded$|^x-real-ip$/i
  # Hosts whose first label names a customer site or a developer's tunnel.
  @tenant_domains ~w(atlassian.net ngrok-free.dev ngrok-free.app ngrok.app ngrok.dev ngrok.io)
  @tenant_host Regex.compile!(
                 "(?<![A-Za-z0-9.-])[A-Za-z0-9][A-Za-z0-9-]*\\.(?:" <>
                   Enum.map_join(@tenant_domains, "|", &Regex.escape/1) <> ")(?![A-Za-z0-9-])",
                 "i"
               )
  # Placeholders this module writes; learning them again would flag clean output.
  @host_placeholder ~r/^(?:example(?:-\d+)?\.[a-z0-9.-]+|host-\d+\.example\.com)$/
  @account_placeholder ~r/^account-\d+$/
  @project_number_placeholder "000000000000"
  @min_credential_bytes 8
  # Google user IDs, as in a Meet participant's `signedinUser.user` and in the
  # participant segment of its resource name. Only whole numeric segments of
  # guarded length count, so the `user-<n>` placeholder is never learned again.
  @google_user Regex.compile!(
                 "(?<![A-Za-z0-9_.~-])(?:users|conferenceRecords/[^/\\s\"?#]+/participants)/" <>
                   "(\\d{#{@min_credential_bytes},})(?![A-Za-z0-9_.~-])"
               )

  # `credentials` is a function returning `{variable, value}` pairs, so that
  # inspecting the state, as ExUnit does for failing calls, shows no values.
  defstruct accounts: %{},
            fields: [],
            name_keys: @name_keys,
            keep_keys: ["fields"],
            credentials: nil,
            emails: %{},
            hosts: %{},
            identifying: [],
            names: %{},
            project_numbers: [],
            users: %{},
            values: %{}

  @doc """
  Builds a state from the `:fields`, `:name_keys`, `:keep_keys`, `:credentials`,
  `:hosts`, `:identifying` and `:project_numbers` options. `:hosts` holds
  `{source, host}` pairs that get placeholders before any value is read;
  `:identifying` holds `{source, value}` pairs that must not remain, such as
  configured emails; `:project_numbers` holds `{source, number}` pairs whose
  number becomes `000000000000` and must not remain either.
  """
  def new(opts) do
    hosts = Keyword.get(opts, :hosts, [])
    numbers = Keyword.get(opts, :project_numbers, [])

    state = %__MODULE__{
      fields: strings(Keyword.get(opts, :fields, [])),
      name_keys: @name_keys ++ strings(Keyword.get(opts, :name_keys, [])),
      keep_keys: strings(Keyword.get(opts, :keep_keys, ["fields"])),
      credentials: credentials(Keyword.get(opts, :credentials, [])),
      identifying: Keyword.get(opts, :identifying, []) ++ hosts ++ numbers,
      project_numbers: Enum.map(numbers, fn {_source, number} -> number end)
    }

    Enum.reduce(hosts, state, fn {_source, host}, state -> add_host(state, host) end)
  end

  @doc "Sanitizes a decoded JSON value."
  def value(value, state) do
    value
    |> collect(state)
    |> then(&replace(value, &1))
  end

  @doc "Sanitizes free text such as a URL path or a header value."
  def text(text, state) when is_binary(text) do
    state = collect(text, state)
    {replace_text(text, state), state}
  end

  @doc "Drops auth, cookie, signature and forwarding headers and sanitizes the rest."
  def headers(headers, state) do
    headers
    |> Enum.reject(fn {name, _value} -> drop_header?(name) end)
    |> Enum.map_reduce(state, fn {name, value}, state ->
      {value, state} = header_value(value, state)
      {{String.downcase(to_string(name)), value}, state}
    end)
    |> then(fn {pairs, state} -> {Map.new(pairs), state} end)
  end

  @doc "Sanitizes a raw request body according to its content type."
  def body(nil, content_type, state), do: body("", content_type, state)

  def body(body, content_type, state) when is_binary(body) do
    cond do
      content_type =~ "json" -> json_text(body, state)
      content_type =~ "x-www-form-urlencoded" -> form(body, state)
      true -> text(body, state)
    end
  end

  @doc "Returns a header value by name, ignoring case, or an empty string."
  def header_value_of(headers, name) do
    Enum.find_value(headers || %{}, "", fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: value |> List.wrap() |> Enum.join(", ")
    end)
  end

  @doc """
  Raises `LeakError` when the encoded value holds a credential value, a
  configured identifying value, or a tenant host, account ID or Google user ID
  that sanitizing replaced elsewhere.
  """
  def check_leaks!(value, %__MODULE__{} = state) do
    encoded = Jason.encode!(value)

    learned =
      Enum.map(state.hosts, fn {host, _placeholder} -> {"a tenant host", host} end) ++
        Enum.map(state.accounts, fn {id, _placeholder} -> {"an account ID", id} end) ++
        Enum.map(state.users, fn {id, _placeholder} -> {"a Google user ID", id} end)

    guarded =
      Enum.filter(state.identifying ++ learned, fn {_source, value} ->
        is_binary(value) and byte_size(value) >= @min_credential_bytes
      end)

    case Enum.find(state.credentials.() ++ guarded, fn {_name, secret} ->
           leaked?(encoded, secret)
         end) do
      nil -> :ok
      {name, _secret} -> raise LeakError, variable: name
    end
  end

  defp credentials(pairs) do
    pairs =
      Enum.filter(pairs, fn {_name, value} ->
        is_binary(value) and byte_size(value) >= @min_credential_bytes
      end)

    fn -> pairs end
  end

  defp collect(map, state) when is_map(map) do
    Enum.reduce(map, state, fn {key, item}, state ->
      state = if is_binary(key), do: collect(key, state), else: state

      state =
        cond do
          is_binary(item) and to_string(key) in state.name_keys -> add_name(state, item)
          is_binary(item) and to_string(key) in @account_keys -> add_account(state, item)
          true -> state
        end

      collect(item, state)
    end)
  end

  defp collect(list, state) when is_list(list), do: Enum.reduce(list, state, &collect/2)

  defp collect(text, state) when is_binary(text) do
    state =
      if Regex.match?(@address_list, text) do
        @named_address
        |> Regex.scan(text, capture: :all_but_first)
        |> Enum.reduce(state, fn [quoted | rest], state ->
          add_name(state, if(quoted == "", do: List.first(rest, ""), else: quoted))
        end)
      else
        state
      end

    state =
      @email
      |> Regex.scan(text)
      |> List.flatten()
      |> Enum.reduce(state, &add_email(&2, &1))

    state =
      @google_user
      |> Regex.scan(text, capture: :all_but_first)
      |> List.flatten()
      |> Enum.reduce(state, &add_user(&2, &1))

    @tenant_host
    |> Regex.scan(text)
    |> List.flatten()
    |> Enum.reduce(state, &add_host(&2, &1))
  end

  defp collect(_other, state), do: state

  defp add_email(state, email) do
    key = String.downcase(email)

    if Map.has_key?(state.emails, key) do
      state
    else
      put_in(state.emails[key], "person-#{map_size(state.emails) + 1}@example.com")
    end
  end

  defp add_host(state, host) do
    host = String.downcase(host)

    if host == "" or Map.has_key?(state.hosts, host) or Regex.match?(@host_placeholder, host) do
      state
    else
      put_in(state.hosts[host], host_placeholder(state, host))
    end
  end

  # A tenant host keeps its provider domain; any other host becomes host-<n>.example.com.
  defp host_placeholder(state, host) do
    case Enum.find(@tenant_domains, &String.ends_with?(host, "." <> &1)) do
      nil ->
        "host-#{count_placeholders(state, ".example.com") + 1}.example.com"

      domain ->
        case count_placeholders(state, "." <> domain) do
          0 -> "example.#{domain}"
          count -> "example-#{count + 1}.#{domain}"
        end
    end
  end

  defp count_placeholders(state, suffix),
    do:
      Enum.count(state.hosts, fn {_host, placeholder} ->
        String.ends_with?(placeholder, suffix)
      end)

  defp add_account(state, id) do
    if id == "" or Map.has_key?(state.accounts, id) or Regex.match?(@account_placeholder, id) do
      state
    else
      put_in(state.accounts[id], "account-#{map_size(state.accounts) + 1}")
    end
  end

  defp add_user(state, id) do
    if Map.has_key?(state.users, id) do
      state
    else
      put_in(state.users[id], "user-#{map_size(state.users) + 1}")
    end
  end

  defp add_name(state, name) do
    name = String.trim(name)

    if byte_size(name) < 3 or String.contains?(name, "@") or Map.has_key?(state.names, name) do
      state
    else
      put_in(state.names[name], "Person #{map_size(state.names) + 1}")
    end
  end

  defp replace(map, state) when is_map(map) do
    map
    |> Enum.map_reduce(state, fn {key, item}, state ->
      field = to_string(key)

      cond do
        redact?(key, state) ->
          {{key, "[redacted]"}, state}

        field in state.fields ->
          {item, state} = placeholder(item, field, state)
          {{key, item}, state}

        true ->
          {item, state} = replace(item, state)
          {{replace_key(key, state), item}, state}
      end
    end)
    |> then(fn {pairs, state} -> {Map.new(pairs), state} end)
  end

  defp replace(list, state) when is_list(list), do: Enum.map_reduce(list, state, &replace/2)
  defp replace(text, state) when is_binary(text), do: {replace_text(text, state), state}
  defp replace(other, state), do: {other, state}

  defp redact?(key, state),
    do: Sanitizer.sensitive_key?(key) and to_string(key) not in state.keep_keys

  defp replace_text(text, state) do
    text = Regex.replace(@email, text, &Map.get(state.emails, String.downcase(&1), &1))

    # Hosts before names, so a name that equals a host label leaves the host whole.
    text =
      Enum.reduce(state.hosts, text, fn {host, placeholder}, text ->
        Regex.replace(
          ~r/(?<![A-Za-z0-9.-])#{Regex.escape(host)}(?![A-Za-z0-9-])/i,
          text,
          placeholder
        )
      end)

    # Account IDs appear raw and percent-encoded, as in `?accountId=` of user links.
    text =
      Enum.reduce(state.accounts, text, fn {id, placeholder}, text ->
        text
        |> String.replace(id, placeholder)
        |> String.replace(URI.encode_www_form(id), placeholder)
      end)

    # Whole numbers only, so a longer number that contains one stays intact and
    # the leak guard reports it instead.
    text =
      Enum.reduce(state.users, text, fn {id, placeholder}, text ->
        Regex.replace(~r/(?<![0-9])#{id}(?![0-9])/, text, placeholder)
      end)

    text =
      Enum.reduce(state.project_numbers, text, fn number, text ->
        Regex.replace(
          ~r/(?<![0-9])#{Regex.escape(number)}(?![0-9])/,
          text,
          @project_number_placeholder
        )
      end)

    state.names
    |> Enum.sort_by(fn {name, _placeholder} -> -byte_size(name) end)
    |> Enum.reduce(text, fn {name, placeholder}, text ->
      # Whole words only, so a name such as "Admin" leaves "Administrator" alone.
      Regex.replace(
        ~r/(?<![\p{L}\p{N}])#{Regex.escape(name)}(?![\p{L}\p{N}])/iu,
        text,
        placeholder
      )
    end)
  end

  defp replace_key(key, state) when is_binary(key), do: replace_text(key, state)
  defp replace_key(key, _state), do: key

  defp placeholder(text, field, state) when is_binary(text) do
    case Map.fetch(state.values, {field, text}) do
      {:ok, placeholder} ->
        {placeholder, state}

      :error ->
        count = Enum.count(state.values, fn {{key, _text}, _placeholder} -> key == field end)
        placeholder = "#{field}-#{count + 1}"
        {placeholder, put_in(state.values[{field, text}], placeholder)}
    end
  end

  defp placeholder(list, field, state) when is_list(list),
    do: Enum.map_reduce(list, state, &placeholder(&1, field, &2))

  defp placeholder(map, field, state) when is_map(map) do
    map
    |> Enum.map_reduce(state, fn {key, item}, state ->
      {item, state} = placeholder(item, field, state)
      {{key, item}, state}
    end)
    |> then(fn {pairs, state} -> {Map.new(pairs), state} end)
  end

  defp placeholder(other, _field, state), do: {other, state}

  defp header_value(values, state) when is_list(values),
    do: Enum.map_reduce(values, state, &text/2)

  defp header_value(value, state) when is_binary(value), do: text(value, state)
  defp header_value(value, state), do: {value, state}

  defp drop_header?(name) do
    Sanitizer.sensitive_key?(name) or Regex.match?(@dropped_header, to_string(name))
  end

  defp json_text(body, state) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {decoded, state} = value(decoded, state)
        {Jason.encode!(decoded), state}

      {:error, _reason} ->
        text(body, state)
    end
  end

  defp form(body, state) do
    body
    |> URI.query_decoder()
    |> Enum.map_reduce(state, fn {key, item}, state ->
      cond do
        redact?(key, state) -> {{key, "[redacted]"}, state}
        json_container?(item) -> json_pair(key, item, state)
        true -> text_pair(key, item, state)
      end
    end)
    |> then(fn {pairs, state} -> {URI.encode_query(pairs), state} end)
  end

  defp json_container?(text), do: String.starts_with?(text, ["{", "["])

  defp json_pair(key, item, state) do
    {item, state} = json_text(item, state)
    {{key, item}, state}
  end

  defp text_pair(key, item, state) do
    {item, state} = text(item, state)
    {{key, item}, state}
  end

  # Besides the raw value, look for the JSON, percent and Base64 encodings a
  # value takes in URLs, form bodies and encoded payloads.
  defp leaked?(encoded, secret) do
    [
      secret,
      secret |> Jason.encode!() |> String.slice(1..-2//1),
      URI.encode_www_form(secret),
      URI.encode(secret, &URI.char_unreserved?/1),
      Base.encode64(secret, padding: false),
      Base.url_encode64(secret, padding: false)
    ]
    |> Enum.uniq()
    |> Enum.any?(&String.contains?(encoded, &1))
  end

  defp strings(values), do: Enum.map(values, &to_string/1)
end
