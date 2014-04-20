defmodule GistsIO.Utils do
	def is_markdown({_name, attrs}) do
		attrs["language"] === "Markdown"
	end

	def is_image(name) do
		Regex.match?(~r/.\.(?:png|jpg|jpeg|gif)$/, name)
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
			[title] = Regex.run ~r/.*$/m, description
			size = Kernel.byte_size(title)
			<<title :: [size(size), binary], teaser :: binary>> = description
			# Trim the new line character at the beginning of teaser
			{title, :binary.replace(teaser, "\n", "")}
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

	def diff_files([], changed_files) do
		changed_files
	end
	def diff_files([{file,attrs}|rest], changed_files) do
		diff_attrs = changed_files[file]
		if diff_attrs === nil do
			# File is not in list of updates, meaning to be deleted
			diff_files(rest, changed_files ++ [{file, "null"}])
		else
			# Either rename, or change content, or both.
			old_content = attrs["content"]
			case {diff_attrs["content"], diff_attrs["filename"]} do
				{^old_content, nil} ->
					diff_files(rest, Dict.delete(changed_files, file))
				{^old_content, ^file} ->
					diff_files(rest, Dict.delete(changed_files, file))
				_ ->
					diff_files(rest, changed_files)
			end
		end
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
	def compose_gist([field|rest], files, content, teaser \\ "") do
		case field do
			# Markdown will only include the content if the data contains
			# specifically text
			[{"type", "markdown"}, {"data", [{"text",""}]}] ->
				compose_gist(rest, files, content, teaser)
			[{"type", "markdown"}, {"data", [{"text",text}]}] ->
				compose_gist(rest, files, content <> text, teaser)
			[{"type", "markdown"}, {"data", data}] ->
				compose_gist(rest, files, content, teaser)
			[{"type", "list"}, {"data", [{"text",text}]}] ->
				compose_gist(rest, files, content <> "\n\n" <> text <> "\n\n", teaser)
			# Image will only be included if the data specifically contains
			# name and source in that order.
			[{"type", "image"}, {"data", [{}]}] ->
				compose_gist(rest, files, content, teaser)
			[{"type", "image"}, {"data", [{"source",source},{"name",filename},{"embedded",true}]}] ->
				file = [{filename, [{"content", source}]}]
				replacement = "\n\n<%= files[\"#{filename}\"] %>\n\n"
				compose_gist(rest, files ++ file, content <> replacement, teaser)
			[{"type", "image"}, {"data", [{"source",source},{"name",filename},{"embedded",false}]}] ->
				file = [{filename, [{"content", source}]}]
				compose_gist(rest, files ++ file, content, teaser)
			[{"type", "image"}, {"data", data}] ->
				compose_gist(rest, files, content, teaser)
			# Code files will only be included if the data specifically contains
			# name, source, embedded and oldname in that order. File will only
			# be included if filename and source content are provided.
			[{"type", "code"}, {"data", [{"source",source},{"name",name},
			{"embedded", _},{"oldname", _}]}] when name == "" or source == ""->
				compose_gist(rest, files, content, teaser)
			[{"type", "code"}, {"data", [{"source",source},{"name",filename},
			{"embedded", embedded},{"oldname", oldfilename}]}] 
			when embedded == true or embedded == false ->
				if oldfilename == "" do
					file = [{filename, [{"content",source}]}]
				else
					file = [{oldfilename, [{"content",source},{"filename",filename}]}]
				end	
				if embedded == true do
					compose_gist(rest, files ++ file, content <> "\n\n<%= files[\"#{filename}\"] %>\n\n", teaser)
				else
					compose_gist(rest, files ++ file, content, teaser)
				end
			[{"type", "code"}, {"data", data}] ->
				compose_gist(rest, files, content, teaser)
			# Teaser will only be included if the data specifically contains text.
			[{"type", "teaser"}, {"data", [{"text",text}]}] ->
				compose_gist(rest, files, content, text)
			[{"type", "teaser"}, {"data", data}] ->	
				compose_gist(rest, files, content, teaser)
			# Anything else will do nothing.
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