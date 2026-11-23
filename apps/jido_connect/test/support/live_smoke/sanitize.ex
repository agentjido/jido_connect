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
  @named_address ~r/(?:"([^"]+)"|([^"<>,;:\s][^"<>,;:]*?))\s*<\s*(#{@email_pattern})\s*>/
  @name_keys ~w(displayName display_name display_name_normalized real_name
                real_name_normalized publicName fullName full_name first_name last_name
                givenName familyName username user_name)
  # Keys whose values are Atlassian account IDs in Jira, Confluence and Tempo
  # payloads; the `tmp` keys name the users of a Jira changelog item.
  @account_keys ~w(accountId authorAccountId leadAccountId authorId ownerId lastOwnerId
                   tmpFromAccountId tmpToAccountId)
  # `x-amz-cf-pop` names the CloudFront edge that served the recording, and
  # so the recorder's location.
  @dropped_header ~r/auth|cookie|token|secret|signature|^x-forwarded-|^forwarded$|^x-real-ip$|^x-amz-cf-pop$/i
  # Hosts whose first label names a customer site or a developer's tunnel.
  @tenant_domains ~w(atlassian.net ngrok-free.dev ngrok-free.app ngrok.app ngrok.dev ngrok.io)
  @tenant_host Regex.compile!(
                 "(?<![A-Za-z0-9.-])[A-Za-z0-9][A-Za-z0-9-]*\\.(?:" <>
                   Enum.map_join(@tenant_domains, "|", &Regex.escape/1) <> ")(?![A-Za-z0-9-])",
                 "i"
               )
  # Placeholders this module writes. Learning them again would flag clean
  # output or number them anew, so they are skipped, and a new value gets a
  # number that no placeholder in the input holds.
  @host_placeholder_pattern "host-\\d+\\.example\\.com|example(?:-\\d+)?\\.(?:" <>
                              Enum.map_join(@tenant_domains, "|", &Regex.escape/1) <> ")"
  @host_placeholder Regex.compile!("^(?:#{@host_placeholder_pattern})$", "i")
  @account_placeholder ~r/^account-\d+$/
  @email_placeholder ~r/^person-\d+@example\.com$/
  @name_placeholder ~r/^Person \d+$/
  @placeholder Regex.compile!(
                 "person-\\d+@example\\.com|Person \\d+|account-\\d+|user-\\d+|" <>
                   @host_placeholder_pattern
               )
  # A host in the shape of a placeholder is not learned either. A configured
  # host of that shape stays, and the leak guard refuses the output.
  @placeholder_shaped_host ~r/^(?:example(?:-\d+)?\.[a-z0-9.-]+|host-\d+\.example\.com)$/
  @project_number_placeholder "000000000000"
  @min_credential_bytes 8
  # Google user IDs, as in a Meet participant's `signedinUser.user` and in the
  # participant segment of its resource name. Only whole numeric segments of
  # guarded length count, so the `user-<n>` placeholder is never learned again.
  @google_user Regex.compile!(
                 "(?<![A-Za-z0-9_.~-])(?:users|conferenceRecords/[^/\\s\"?#]+/participants)/" <>
                   "(\\d{#{@min_credential_bytes},})(?![A-Za-z0-9_.~-])"
               )
  @google_user_id Regex.compile!("^\\d{#{@min_credential_bytes},}$")
  # Keys whose string values are Base64 content, such as Gmail's
  # `payload.body.data` and `raw`.
  @base64_keys ~w(data raw)
  @base64 ~r/^[A-Za-z0-9+\/]+={0,2}$/
  @base64url ~r/^[A-Za-z0-9_-]+={0,2}$/
  # Addresses under example.com, example.net and example.org and the `.example`
  # and `.invalid` names (RFC 2606), as seed data and message IDs use them.
  @documentation_address ~r/@(?:[a-z0-9.-]+\.)?(?:example\.(?:com|net|org)|[a-z0-9-]+\.(?:example|invalid))$/i

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
            documentation_names: MapSet.new(),
            project_numbers: [],
            reserved: MapSet.new(),
            users: %{},
            values: %{}

  @doc """
  Builds a state from the `:fields`, `:name_keys`, `:keep_keys`, `:credentials`,
  `:hosts`, `:accounts`, `:users`, `:identifying` and `:project_numbers`
  options. `:hosts` holds `{source, host}` pairs, `:accounts` account IDs and
  `:users` Google user IDs that get placeholders before any value is read;
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

    state = Enum.reduce(hosts, state, fn {_source, host}, state -> add_host(state, host) end)

    state =
      opts |> Keyword.get(:accounts, []) |> strings() |> Enum.reduce(state, &add_account(&2, &1))

    opts |> Keyword.get(:users, []) |> strings() |> Enum.reduce(state, &add_known_user(&2, &1))
  end

  @doc """
  Returns whether `host` is a host placeholder this module writes, such as
  `host-1.example.com` or `example-2.atlassian.net`.
  """
  def host_placeholder?(host), do: Regex.match?(@host_placeholder, host)

  @doc "Sanitizes a decoded JSON value."
  def value(value, state) do
    state = reserve(value, state)

    value
    |> collect(state)
    |> then(&replace(value, &1))
  end

  @doc "Sanitizes free text such as a URL path or a header value."
  def text(text, state) when is_binary(text) do
    state = text |> reserve(state) |> then(&collect(text, &1))
    {replace_text(text, state), state}
  end

  @doc """
  Notes the placeholders that a value already holds, without replacing
  anything, so that values learned later get other numbers.

  Sanitizing sanitized output, such as the second fixture of a recording,
  keeps its placeholders. Reserve every part of a recording or capture before
  the first one is sanitized.
  """
  def reserve(value, state) do
    value
    |> texts([])
    |> Enum.reduce(state, fn text, state ->
      found = @placeholder |> Regex.scan(text) |> List.flatten()
      found = if field_placeholder?(state, text), do: [text | found], else: found
      %{state | reserved: Enum.into(found, state.reserved)}
    end)
  end

  @doc """
  Learns the account IDs that headers name, without replacing anything.

  Jira and Confluence name the calling user in `x-aaccountid`, with the
  colon of a `<prefix>:<uuid>` ID percent-encoded; the decoded ID is learned.
  Learn the headers of a response before its body, so that the ID is
  replaced where the body names it outside an account key.
  """
  def learn_headers(headers, state) do
    Enum.reduce(headers || %{}, state, fn {name, value}, state ->
      if String.downcase(to_string(name)) == "x-aaccountid" do
        value
        |> List.wrap()
        |> Enum.filter(&is_binary/1)
        |> Enum.reduce(state, &add_account(&2, percent_decode(&1)))
      else
        state
      end
    end)
  end

  @doc """
  Drops auth, cookie, signature, forwarding and CloudFront edge headers and
  sanitizes the rest.
  """
  def headers(headers, state) do
    state = headers |> reserve(state) |> then(&learn_headers(headers, &1))

    headers
    |> Enum.reject(fn {name, _value} -> drop_header?(name) end)
    |> Enum.map_reduce(state, fn {name, value}, state ->
      {value, state} = header_value(value, state)
      {{String.downcase(to_string(name)), value}, state}
    end)
    |> then(fn {pairs, state} -> {Map.new(pairs), state} end)
  end

  @doc """
  Sanitizes a recorded fixture: its `body`, `headers` and `request.path`.

  The placeholders the fixture already holds are reserved and the
  `x-aaccountid` header is learned first; the body goes next, so that the
  values found in both are known when the headers and the path are sanitized.
  The recorder and `LiveSmoke.sanitize_fixture/2` share this order.
  """
  def fixture(%{} = fixture, state) do
    state = fixture |> reserve(state) |> then(&learn_headers(fixture["headers"], &1))
    {body, state} = value(fixture["body"], state)
    {headers, state} = headers(fixture["headers"] || %{}, state)
    {path, state} = text(get_in(fixture, ["request", "path"]) || "/", state)

    sanitized =
      fixture
      |> Map.merge(%{"body" => body, "headers" => headers})
      |> Map.update("request", %{"path" => path}, &Map.put(&1, "path", path))

    {sanitized, state}
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
    map
    |> Enum.reduce(add_mention(state, map), fn {key, item}, state ->
      state = if is_binary(key), do: collect(key, state), else: state

      state =
        cond do
          not is_binary(item) or field_placeholder?(key, item) -> state
          to_string(key) in state.name_keys -> add_name(state, item)
          to_string(key) in @account_keys -> add_account(state, item)
          true -> state
        end

      item
      |> base64_content(key)
      |> collect(state)
    end)
  end

  defp collect(list, state) when is_list(list), do: Enum.reduce(list, state, &collect/2)

  defp collect(text, state) when is_binary(text) do
    state =
      if Regex.match?(@address_list, text) do
        @named_address
        |> Regex.scan(text, capture: :all_but_first)
        |> Enum.reduce(state, fn [quoted, bare, address], state ->
          add_name(state, if(quoted == "", do: bare, else: quoted), documentation?(address))
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

    state =
      @tenant_host
      |> Regex.scan(text)
      |> List.flatten()
      |> Enum.reduce(state, &add_host(&2, &1))

    collect_embedded_json(text, state)
  end

  defp collect(_other, state), do: state

  # A string can hold a JSON document, such as the ADF that Confluence returns
  # as a string under `body.atlas_doc_format.value`. Its account keys, name
  # keys and mentions are learned; the string is then replaced as text.
  defp collect_embedded_json(text, state) do
    with true <- json_container?(text),
         {:ok, decoded} when is_map(decoded) or is_list(decoded) <- Jason.decode(text) do
      collect(decoded, state)
    else
      _not_json -> state
    end
  end

  defp add_email(state, email) do
    key = String.downcase(email)

    if Map.has_key?(state.emails, key) or Regex.match?(@email_placeholder, key) do
      state
    else
      put_in(state.emails[key], free_placeholder(state, :emails, &"person-#{&1}@example.com"))
    end
  end

  defp add_host(state, host) do
    host = String.downcase(host)

    if host == "" or Map.has_key?(state.hosts, host) or
         Regex.match?(@placeholder_shaped_host, host) do
      state
    else
      put_in(state.hosts[host], free_placeholder(state, :hosts, host_placeholder(host)))
    end
  end

  # A tenant host keeps its provider domain; any other host becomes host-<n>.example.com.
  defp host_placeholder(host) do
    case Enum.find(@tenant_domains, &String.ends_with?(host, "." <> &1)) do
      nil -> &"host-#{&1}.example.com"
      domain -> &if(&1 == 1, do: "example.#{domain}", else: "example-#{&1}.#{domain}")
    end
  end

  # The placeholder with the lowest number that is neither given to another
  # value of the same kind nor reserved in the input.
  defp free_placeholder(state, kind, format) do
    given = state |> Map.fetch!(kind) |> Map.values() |> MapSet.new()

    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(format)
    |> Enum.find(&(not MapSet.member?(given, &1) and not MapSet.member?(state.reserved, &1)))
  end

  # `fields:` writes `<key>-<n>` under a configured key.
  defp field_placeholder?(%__MODULE__{fields: fields}, item),
    do: Enum.any?(fields, &field_placeholder?(&1, item))

  defp field_placeholder?(key, item) do
    prefix = "#{key}-"
    String.starts_with?(item, prefix) and String.replace_prefix(item, prefix, "") =~ ~r/^\d+$/
  end

  # A value this short is no account ID, such as a mention of a collection, and
  # replacing it wherever it appears would garble the text.
  defp add_account(state, id) do
    if byte_size(id) < @min_credential_bytes or Map.has_key?(state.accounts, id) or
         Regex.match?(@account_placeholder, id) do
      state
    else
      put_in(state.accounts[id], free_placeholder(state, :accounts, &"account-#{&1}"))
    end
  end

  # A known Google user ID must have the form of a learned one. A shorter
  # number, replaced wherever it stands as a whole number, would garble text.
  defp add_known_user(state, id) do
    unless Regex.match?(@google_user_id, id) do
      raise ArgumentError,
            "users: takes Google user IDs of #{@min_credential_bytes} or more digits"
    end

    add_user(state, id)
  end

  defp add_user(state, id) do
    if Map.has_key?(state.users, id) do
      state
    else
      put_in(state.users[id], free_placeholder(state, :users, &"user-#{&1}"))
    end
  end

  # A value with a malformed escape is taken as it is.
  defp percent_decode(value) do
    URI.decode(value)
  rescue
    ArgumentError -> value
  end

  # An ADF mention names the mentioned user's account ID in `attrs.id`.
  defp add_mention(state, %{"type" => "mention", "attrs" => %{"id" => id}}) when is_binary(id),
    do: add_account(state, id)

  defp add_mention(state, _map), do: state

  # A name seen only next to documentation addresses is seed data, as those
  # addresses are; `documentation_names` holds such names.
  defp add_name(state, name, documentation? \\ false) do
    name = String.trim(name)

    cond do
      byte_size(name) < 3 or String.contains?(name, "@") or
          Regex.match?(@name_placeholder, name) ->
        state

      Map.has_key?(state.names, name) ->
        if documentation?,
          do: state,
          else: %{state | documentation_names: MapSet.delete(state.documentation_names, name)}

      true ->
        state = put_in(state.names[name], free_placeholder(state, :names, &"Person #{&1}"))

        if documentation?,
          do: %{state | documentation_names: MapSet.put(state.documentation_names, name)},
          else: state
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

        field in @base64_keys and is_binary(item) ->
          {{key, replace_base64(item, state)}, state}

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

  # Base64 content is sanitized as the text it decodes to and encoded again
  # with the original alphabet and padding; content whose text stays the same
  # keeps its original bytes. Addresses under the names reserved for examples
  # stay inside such content, and so do the names known only next to such
  # addresses: they identify nobody, and rewriting them changes the content's
  # length, which providers such as Gmail state in `size` and check.
  #
  # Any other string is sanitized as text. That includes Base64 that does not
  # decode to UTF-8, such as a binary attachment: a plain word under `data`
  # can look like Base64 too, and the leak guard does not guard names. A
  # learned value that the encoding happens to contain is replaced there.
  defp replace_base64(item, state) do
    emails = Map.reject(state.emails, fn {email, _placeholder} -> documentation?(email) end)
    names = Map.drop(state.names, MapSet.to_list(state.documentation_names))

    case decode_base64(item) do
      {:ok, text, encoding} ->
        case replace_text(text, %{state | emails: emails, names: names}) do
          ^text -> item
          sanitized -> encode_base64(sanitized, encoding)
        end

      :error ->
        replace_text(item, state)
    end
  end

  # Every string of a value: map keys, values and decoded Base64 content.
  defp texts(map, acc) when is_map(map) do
    Enum.reduce(map, acc, fn {key, item}, acc ->
      acc = if is_binary(key), do: [key | acc], else: acc
      item |> base64_content(key) |> texts(acc)
    end)
  end

  defp texts(list, acc) when is_list(list), do: Enum.reduce(list, acc, &texts/2)
  defp texts(text, acc) when is_binary(text), do: [text | acc]
  defp texts(_other, acc), do: acc

  defp documentation?(email), do: Regex.match?(@documentation_address, email)

  defp base64_content(item, key) when is_binary(item) do
    with true <- to_string(key) in @base64_keys,
         {:ok, text, _encoding} <- decode_base64(item) do
      text
    else
      _not_base64_text -> item
    end
  end

  defp base64_content(item, _key), do: item

  # An encoding without `+`, `/`, `-` or `_` fits both alphabets and counts as
  # URL-safe, the alphabet of Gmail. Padding is left out again only where the
  # original's length shows that it left it out.
  defp decode_base64(item) do
    cond do
      Regex.match?(@base64url, item) -> decode_base64(item, :url)
      Regex.match?(@base64, item) -> decode_base64(item, :standard)
      true -> :error
    end
  end

  defp decode_base64(item, alphabet) do
    decoded =
      case alphabet do
        :url -> Base.url_decode64(item, padding: false)
        :standard -> Base.decode64(item, padding: false)
      end

    padding = String.ends_with?(item, "=") or rem(byte_size(item), 4) == 0

    case decoded do
      {:ok, text} -> if String.valid?(text), do: {:ok, text, {alphabet, padding}}, else: :error
      :error -> :error
    end
  end

  defp encode_base64(text, {:url, padding}), do: Base.url_encode64(text, padding: padding)
  defp encode_base64(text, {:standard, padding}), do: Base.encode64(text, padding: padding)

  defp replace_key(key, state) when is_binary(key), do: replace_text(key, state)
  defp replace_key(key, _state), do: key

  # A value that already is a placeholder of its field keeps it.
  defp placeholder(text, field, state) when is_binary(text) do
    cond do
      field_placeholder?(field, text) ->
        {text, state}

      Map.has_key?(state.values, {field, text}) ->
        {Map.fetch!(state.values, {field, text}), state}

      true ->
        placeholder = free_placeholder(state, :values, &"#{field}-#{&1}")
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
      URI.encode(secret, &URI.char_unreserved?/1)
      | base64_cores(secret)
    ]
    |> Enum.uniq()
    |> Enum.any?(&String.contains?(encoded, &1))
  end

  # A value inside longer Base64 content starts at byte 0, 1 or 2 of a
  # three-byte group, and each start gives other characters. Each core is the
  # part of the encoding that depends on the value alone: the characters that
  # mix in bytes before or after it are cut off.
  defp base64_cores(secret) do
    for shift <- 0..2,
        encode <- [&Base.encode64(&1, padding: false), &Base.url_encode64(&1, padding: false)] do
      encoded = encode.(:binary.copy(<<0>>, shift) <> secret)
      lead = Enum.at([0, 2, 3], shift)
      trail = if rem(shift + byte_size(secret), 3) == 0, do: 0, else: 1
      binary_part(encoded, lead, byte_size(encoded) - lead - trail)
    end
  end

  defp strings(values), do: Enum.map(values, &to_string/1)
end
