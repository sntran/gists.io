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
				case Gist.fetch_gists username do
					{:ok, gists} ->
						{:true, req, gists}
					{:error, _} ->
						{:false, req, username}
				end
		end
	end

	def gists_html(req, gists) do
		entries = Enum.filter_map(gists, &is_markdown/1, fn(gist) ->
			{_name, entry} = Enum.at gist["files"], 0
			gist = ListDict.put(gist, "title", entry["filename"])
		end)

		{username, req} = Req.binding :username, req

		gists_html = [:code.priv_dir(:gistsio), "templates", "gists.html.eex"]
				|> Path.join
				|> EEx.eval_file [entries: entries]

		html = [:code.priv_dir(:gistsio), "templates", "base.html.eex"]
				|> Path.join
				|> EEx.eval_file [content: gists_html, title: "#{username}'s gists"]

		{html, req, gists}
	end

	defp is_markdown(gist) do
		Enum.any? gist["files"], &Utils.is_markdown/1
	end
end