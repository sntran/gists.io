defmodule GistsIO.AuthHandler do
    alias :cowboy_req, as: Req

    def init(_transport, req, []) do
        {:ok, req, nil}
    end

    def handle(req, state) do
        {session, req} = Req.cookie("session_id", req)
        client = Session.get("gist_client", req)
        client_id = :application.get_env(:gistsio, :client_id, "")
        {host, req} = Req.host(req)
        {port, req} = Req.port(req)

        case Req.qs_val("code", req) do
            {:undefined, req} -> 
                auth_url = "https://github.com/login/oauth/authorize?scope=gist,public_repo"
                url = "#{auth_url}&state=#{session}&client_id=#{client_id}&redirect_uri=http://#{host}:#{port}/login"
                req = Req.set_resp_header("Location", url, req)
                {:ok, req} = Req.reply(302, [], "", req)
                {:ok, req, state}
            {code, req} ->
                GistsIO.GistClient.authorize(client, code)
                previous_path = Session.get("previous_path", req)
                if previous_path == :undefined do
                    url = "http://#{host}:#{port}"
                else
                    url = "http://#{host}:#{port}#{previous_path}"
                end
                req = Req.set_resp_header("Location", url, req)
                {:ok, req} = Req.reply(302, [], "", req)
                {:ok, req, state}
        end 
    end

    def terminate(_reason, _req, _state), do: :ok
end
 
