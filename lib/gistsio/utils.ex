defmodule GistsIO.Utils do
	def is_markdown({_name, attrs}) do
		attrs["language"] === "Markdown"
	end

	def is_image(name) do
		Regex.match?(%r/.\.(?:png|jpg|jpeg|gif)$/, name)
	end

	def prep_gist(gist) do
		{_name, entry} = Enum.at gist["files"], 0
		{title, teaser} = parse_description(gist)
		gist = ListDict.put(gist, "title", title)
				|> ListDict.put("teaser", teaser)
		
	end

	def parse_description(gist) do
		{_name, entry} = Enum.at gist["files"], 0
		description = gist["description"]
		{title, teaser} = if description !== :null do
			[title] = Regex.run %r/.*$/m, description
			size = Kernel.byte_size(title)
			<<title :: [size(size), binary], teaser :: binary>> = description
			{title, teaser}
		else
			{entry["filename"], ""}
		end
	end

	def empty_gist(username) do
		[
			{"description", "New Entry"},
            {"user", [
                {"login", username}
            ]},
            {"files", [
                {"blog.md", [
                    {"filename", "blog.md"},
                    {"language", "Markdown"},
                    {"content", ""}
                ]}
            ]}
        ]
	end

	# Takes form data from gist form and extracts
	# lists for the file names and contents
	def compose_gist(data) do
		files = []
		content = ""
		compose_gist(data,files,content)
	end
	def compose_gist([], files, content, teaser) do
		{teaser, content, files}
	end
	def compose_gist([field|rest], files, content, teaser // "") do
		case field do
			[{"type", "markdown"}, {"data", data}] ->
				compose_gist(rest, files, content <> data["text"], teaser)
			[{"type", "image"}, {"data", data}] ->
				filename = data["name"]
				file = [{filename, [{"content", data["src"]}]}]
				replacement = "\n\n<%= files[\"#{filename}\"] %>\n\n"
				compose_gist(rest, files ++ file, content <> replacement, teaser)
			[{"type", "code"}, {"data", data}] ->
				filename = data["name"]
				oldfilename = data["oldname"]
				if oldfilename == :nil do
					file = [{filename, [{"content",data["source"]}]}]
				else
					file = [{oldfilename, [{"content",data["source"]},{"filename",filename}]}]
				end	
				compose_gist(rest, files ++ file, content <> "\n\n<%= files[\"#{filename}\"] %>\n\n", teaser)
			[{"type", "teaser"}, {"data", data}] ->
				compose_gist(rest, files, content, data["text"])
			{_,_} ->
				compose_gist(rest, files, content, teaser)
		end
	end

	defp parse_images(text) do
		re = %r/<img src=\"(data:image\/.+;base64.+)\" alt=\"(.+)\"\s?\/>/
		matches = Regex.scan(re, text)
		images = Enum.map(matches, fn([_, base64, filename]) ->
			{filename, [{"content",base64}]}
		end)
		{Regex.replace(re, text, "<%= files[\"\\2\"] %>"), images}
	end
end