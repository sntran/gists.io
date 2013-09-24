defmodule GistsIO do
    use Application.Behaviour
    alias :cowboy_req, as: Req

    # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
    # for more information on OTP Applications
    def start(_type, _args) do
        port = :application.get_env(:gistsio, :port, 8080)
        static_dir = Path.join [Path.dirname(:code.which(__MODULE__)), "..", "priv", "static"]
        dispatch = [
            {:_, [
                {"/:gist", [{:gist, :int}], GistsIO.GistHandler, []},
                {"/:username", GistsIO.GistsHandler, []},
                {"/:username/:gist", [{:gist, :int}], GistsIO.GistHandler, []},
                {"/s/[:...]", :cowboy_static, [
                    directory: static_dir, mimetypes: {
                        &:mimetypes.path_to_mimes/2, :default
                    }]
                }
            ]}
        ] |> :cowboy_router.compile

        {:ok, _} = :cowboy.start_http(:http, 100,
            [port: port],
            [   
                env: [dispatch: dispatch],
                onrequest: &GistsIO.session/1
                # onresponse: &GistsIO.page_data/4
            ]
            # [middlewares: [:cowboy_router, :auth_handler, :cowboy_handler]]
        )

        client_id = :application.get_env(:gistsio, :client_id, "")
        client_secret = :application.get_env(:gistsio, :client_secret, "")
        {:ok, _} = GistsIO.GistClient.start_link(client_id, client_secret)

        GistsIO.Supervisor.start_link
    end

    def session(req) do
        {existing, req} = Req.cookie("session_id", req)
        new = case existing do
            :undefined -> generate_hash()
            _ -> existing
        end
        req = Req.set_resp_cookie("session_id", new, [], req)

        # Acquire a gist client if not yet
        {existing, req} = Req.meta("gist_client", req)
        {:ok, client} = case existing do
            :undefined -> 
                client_id = :application.get_env(:gistsio, :client_id, "")
                client_secret = :application.get_env(:gistsio, :client_secret, "")
                GistsIO.GistClient.start_link(client_id, client_secret)
            {_} -> {:ok, existing}
        end
        req = Req.set_meta("gist_client", client, req)

        case Req.qs_val("code", req) do
            {:undefined, req} -> req
            {code, req} ->
                GistsIO.GistClient.authorize(client, code)
                req
        end
    end

    def page_data(200, _headers, body, req) do
        # {session, req} = Req.cookie("session_id", req)
        # {host, req} = Req.host(req)
        # {path, req} = Req.path(req) 

        # {:ok, req} = Req.reply(200, _headers, body, req)
        req
    end
    def page_data(_, _, _, req) do req end

    defp generate_hash() do
        :crypto.hash(:sha, generate_string(16))
        |> bin_to_hexstr
    end

    defp generate_string(size) do
        {a, b, c} = :erlang.now()
        :random.seed(a, b, c)
        Enum.sort(1..size) 
          |> List.foldl([], fn(_x, accin) -> [:random.uniform(90) + 32 | accin] end)
          |> List.flatten
    end

    defp bin_to_hexstr(bin) do
        List.flatten(lc x inlist :erlang.binary_to_list(bin), do: :io_lib.format("~2.16.0B", [x]))
    end
    
end
