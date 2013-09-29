defmodule GistsIO.GistsHandler do
	alias :cowboy_req, as: Req
	alias GistsIO.GistClient, as: Gist
	alias GistsIO.Utils, as: Utils
	require EEx

	def init(_transport, _req, []) do
		{:upgrade, :protocol, :cowboy_rest}
	end

	def allowed_methods(req, state) do
		{["GET"], req, state}
	end

	def content_types_provided(req, state) do
		{[
			{"text/html", :gists_html}
		], req, state}
	end

	def resource_exists(req, state) do
		case Req.binding :username, req do
			{:undefined, req} -> {:false, req, :index}
			{username, req} -> 
				client = Session.get("gist_client", req)
				case Gist.fetch_gists client, username do
					{:error, _} ->
						{:false, req, username}
					gists ->
						{:true, req, gists}
				end
		end
	end

	def gists_html(req, gists) do
		{user, entries} = Enum.reduce(gists, {nil, []}, fn(gist, {user, acc}) ->
			cond do # `cond` allows any expression, not just guards
				!is_public_markdown(gist) -> {user, acc}
			  	user === nil ->
					{gist["user"], [Utils.prep_gist(gist) | acc]}
			  	true ->
			  		{user, [Utils.prep_gist(gist) | acc]}
			end
		end)

		gists_html = [:code.priv_dir(:gistsio), "templates", "gists.html.eex"]
				|> Path.join
				|> EEx.eval_file [entries: entries]

		html = [:code.priv_dir(:gistsio), "templates", "base.html.eex"]
				|> Path.join
				|> EEx.eval_file [content: gists_html, title: "#{user["login"]}'s gists"]

		{html, req, gists}
	end

	defp is_public_markdown(gist) do
		gist["public"] === :true and Enum.any? gist["files"], &Utils.is_markdown/1
	end
end