defmodule GistsIO do
    use Application.Behaviour

    # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
    # for more information on OTP Applications
    def start(_type, _args) do
        # env = Application.environment(:gistsio)
        # port = env[:http_port] || 8080
        port = 8080
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
            [env: [dispatch: dispatch]]
            # [middlewares: [:cowboy_router, :markdown_converter, :cowboy_handler]]
        )

        GistsIO.Supervisor.start_link
    end
end
