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
		{user, entries} = Enum.reduce(gists, {nil, []}, fn(gist, {user, acc}) ->
			cond do
				!is_markdown(gist) -> {user, acc}
			  	user === nil ->
					{gist["user"], [prep_data(gist) | acc]}
			  	true ->
			  		{user, [prep_data(gist) | acc]}
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

	defp is_markdown(gist) do
		Enum.any? gist["files"], &Utils.is_markdown/1
	end

	defp prep_data(gist) do
		{_name, entry} = Enum.at gist["files"], 0
		description = gist["description"]
		{title, teaser} = if description !== "" do
			[title] = Regex.run %r/.*$/m, description
			size = Kernel.byte_size(title)
			<<title :: [size(size), binary], teaser :: binary>> = description
			{title, teaser}
		else
			{entry["filename"], ""}
		end
		gist = ListDict.put(gist, "title", title)
				|> ListDict.put("teaser", teaser)
		
	end
end