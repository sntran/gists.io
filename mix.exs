defmodule GistsIO.Mixfile do
    use Mix.Project

    def project do
        [ 
            app: :gistsio,
            version: "0.3.0",
            elixir: "~> 0.11.0",
            deps: deps,
            elixirc_options: options(Mix.env)
        ]
    end

    # Configuration for the OTP application
    def application do
        [ 
            mod: { GistsIO, [] },
            applications: [:crypto, :mimetypes, :cowboy, :exlager],
            env: [
                port: 8080,
                sessions: [store: {Session.ETS, []}],
                lease_time: 60*60*24,
                gists_per_page: 5
            ]
        ]
    end

    # Returns the list of dependencies in the format:
    # { :foobar, "~> 0.1", git: "https://github.com/elixir-lang/foobar.git" }
    defp deps() do
        [ 
            {:cowboy, github: "extend/cowboy"},
            {:httpotion, github: "myfreeweb/httpotion", ref: "ee3cd8ad5630b20b236c0076c59e04fef973adbb"},
            {:jsonex,"2.0",[github: "marcelog/jsonex", tag: "2.0"]},
            {:mimetypes, github: "spawngrid/mimetypes", override: true },
            {:exlager, github: "khia/exlager"}
        ]
    end
    
    defp options(:dev) do
        [ exlager_level: :debug, exlager_truncation_size: 8096 ]
    end
    defp options(_) do
        
    end
end
