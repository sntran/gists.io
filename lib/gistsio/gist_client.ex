defmodule GistsIO.GistClient do
  alias HTTPotion.Response
  use GenServer.Behaviour

  def start_link(client_id, client_secret) do
    :gen_server.start_link(GistsIO.GistClient, [client_id, client_secret], [])
  end

  # APIs
  def fetch_gists(client, user, params // []) when is_binary(user) do
    :gen_server.call(client, ["gists", user | params])
  end
  
  def fetch_gist(client, id) when is_integer(id) do
    :gen_server.call(client, ["gist", id])
  end

  def fetch_comments(client, id) do
    :gen_server.call(client, ["comments", id])
  end

  def fetch_user(client, id) do
    :gen_server.call(client, ["user", id])
  end
  
  def render(client, markdown) do
    :gen_server.call(client, ["render", markdown])
  end

  def authorize(client, code) do
    :gen_server.cast(client, ["authorize", code])
  end

  # Callbacks
  def init([client_id, client_secret]) do
    HTTPotion.start
    {:ok, [{"client_id", client_id}, {"client_secret", client_secret}]}
  end

  def handle_call(["gists", user | params], _from, state) do
    url = url("users/#{user}/gists", params ++ state)
    {stat, data} = fetch(url)
    {:reply, {stat, Jsonex.decode(data)}, state}
  end

  def handle_call(["gist", id], _from, state) do
    url = url("gists/#{id}", state)
    {stat, data} = fetch(url)
    {:reply, {stat, Jsonex.decode(data)}, state}
  end

  def handle_call(["comments", id], _from, state) do
    url = url("gists/#{id}/comments", state)
    {stat, data} = fetch(url)
    {:reply, {stat, Jsonex.decode(data)}, state}
  end

  def handle_call(["user", id], _from, state) do
    url = url("users/#{id}", state)
    {stat, data} = fetch(url)
    {:reply, {stat, Jsonex.decode(data)}, state}
  end
  
  def handle_call(["render", markdown], _from, state) do
    body = Jsonex.encode([{"text", markdown}, {"mode", "gfm"}])
    url = url("markdown", state)
    {:reply, post(url, body), state}
  end
  
  def handle_cast(["authorize", code | params], state) do
    body = [{"code", code} | state]
    url = "https://github.com/login/oauth/access_token?" <> append_query(body)
    state = case fetch(url, [{:Accept, "application/json"}]) do
      {:error, _error} -> state
      body -> ListDict.merge(state, Jsonex.decode(body))
    end
    {:noreply, state}
  end

  defp fetch(url, headers // []) do
    case HTTPotion.get(url, headers) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        {:ok, body}
      Response[body: body, status_code: status, headers: _headers] ->
        {:error, body}
    end
  end

  defp post(url, body) do
    case HTTPotion.post(url, body, [is_ssl: true]) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        {:ok, body}
      Response[body: body, status_code: status, headers: _headers] ->
        {:error, body}
    end
  end

  defp url(endpoint, params) do
    "https://api.github.com/#{endpoint}?" <> append_query(params)
  end

  defp append_query(params) do
    Enum.map_join(params, "&", fn({k,v}) -> "#{k}=#{v}" end)
  end

end