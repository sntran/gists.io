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
					{:ok, gists} ->
						{:true, req, gists}
				end
		end
	end

	def gists_html(req, gists) do
		client = Session.get("gist_client", req)
		{username, req} = Req.binding(:username, req)
		{path, req} = Req.path(req)

		pager = gists["pager"]
		gists = gists["gists"]
		pager = map_pager(pager, path)

		{user, entries} = Enum.reduce(gists, {nil, []}, fn(gist, {user, acc}) ->
			cond do # `cond` allows any expression, not just guards
				!is_public_markdown(gist) -> {user, acc}
			  	user === nil ->
					{gist["user"], [Utils.prep_gist(gist) | acc]}
			  	true ->
			  		{user, [Utils.prep_gist(gist) | acc]}
			end
		end)

		# Render author's info on the sidebar
		{:ok, user} = Gist.fetch_user client, username
		sidebar_html = [:code.priv_dir(:gistsio), "templates", "sidebar.html.eex"]
				|> Path.join
				|> EEx.eval_file [user: user]

		gists_html = [:code.priv_dir(:gistsio), "templates", "gists.html.eex"]
				|> Path.join
				|> EEx.eval_file [entries: entries, pager: pager]

		html = [:code.priv_dir(:gistsio), "templates", "base.html.eex"]
				|> Path.join
				|> EEx.eval_file [content: gists_html, 
									title: "#{user["login"]}'s gists",
									sidebar: sidebar_html]

		{html, req, gists}
	end

	defp is_public_markdown(gist) do
		gist["public"] === :true and Enum.any? gist["files"], &Utils.is_markdown/1
	end

	# Convert the pager header from GitHub to a format suitable to display.
	# It takes a binary string of format
	# "<h../gists?page=3>; rel=\"next\", 
    #  <h.../gists?page=6>; rel=\"last\"; 
    #  <h.../?page=1; rel=\"first\";
    #  <h.../?page=2; rel=\"prev\""
    # split it by the comma, and try to get the page query string and the
    # rel to indicate the type.
	defp map_pager(binary_pager, prefix) when is_binary(binary_pager) do
		map_pager(:binary.split(binary_pager, ", "), prefix)
	end
	defp map_pager([], _) do [] end
	defp map_pager([page | rest], prefix) do
		{pos, len} = :binary.match(page, "page=")
		page_number = :binary.part(page, pos + len, 1)
		{pos, len} = :binary.match(page, "rel=\"")
		type = :binary.part(page, pos+len, 4)
		pager = {type, "#{prefix}?page=#{page_number}"}
		[pager | map_pager(rest, prefix)]
	end
end