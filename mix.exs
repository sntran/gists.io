defmodule GistsIO.Mixfile do
    use Mix.Project

    def project do
        [ 
            app: :gistsio,
            version: "0.3.0",
            elixir: "~> 0.12.5",
            deps: deps,
            elixirc_options: options(Mix.env)
        ]
    end

    # Configuration for the OTP application
    def application do
        [ 
            mod: { GistsIO, [] },
            applications: [:crypto, :cowboy, :exlager],
            env: [
                port: 8080,
                client_id: "0ac0ff06ec95f164be73",
                client_secret: "fed5ebbd075523a9756deaa88d8a20b1cb4b655d",
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
            {:cowboy, github: "extend/cowboy", tag: "0.9.0"},
            {:httpotion, github: "myfreeweb/httpotion", ref: "94b0fdb7bb1f5322791e3a309f2e06d0b8ab9ef3"},
            {:discount, [github: "asaaki/discount.ex", tag: "0.3.1"]},
            {:jsonex, github: "marcelog/jsonex", ref: "82e6c416eed5e791073427bf3079d7ab7b85a1e1"},
            {:exlager, github: "khia/exlager", ref: "2a4b002dfe34abf1b03c9d26a3ebe2e101437f51"}
        ]
    end
    
    defp options(:dev) do
        [ exlager_level: :debug, exlager_truncation_size: 8096 ]
    end
    defp options(_) do
        
    end
end
