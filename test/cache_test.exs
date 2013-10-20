defmodule GistTest do
    use ExUnit.Case, async: true
    alias GistsIO.Cache, as: Cache

    @gist_id "5180107"
    @username "sntran"
    @unchanged_file [
        {"filename", "filename with space and different attrs order"},
        {"content", "Some content"},
        {"language", "Erlang"}
    ]
    @key {:gist, @gist_id, @username}

    setup do
        old_description = "Old Description"
        gist = get_gist(old_description)
        Cacherl.insert(@key, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        assert cache === gist
        {:ok, gist: gist}
    end

    test "update a description in existing gist", meta do
        gist = meta[:gist]
        old_description = gist["description"]
        new_description = "New Description"
        Cache.update_gist(new_description, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        refute cache["description"] === old_description
        assert cache["description"] === new_description
    end

    test "update a file content in existing gist", meta do
        gist = meta[:gist]
        description = gist["description"]
        old_file = gist["files"]["file1"]
        old_file_content = old_file["content"]
        new_file_content = "New File Content"
        new_files = [
            {"file1", [{"filename", "file1"}, {"content", new_file_content}]}
        ]
        Cache.update_gist(description, new_files, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        updated_file = cache["files"]["file1"]
        refute updated_file["content"] === old_file_content
        assert updated_file["content"] === new_file_content

    end

    test "rename a file with new content in existing gist", meta do
        gist = meta[:gist]
        new_description = "New Description"
        new_file_content = "New File Content"
        new_file_name = "new name"
        new_files = [
            {"file1", [{"filename", new_file_name}, {"content", new_file_content}]}
        ]

        Cache.update_gist(new_description, new_files, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        refute cache === gist
        assert cache["id"] === @gist_id
        assert cache["user"]["login"] === @username
        assert cache["description"] === new_description
        files = cache["files"]
        assert files["filename with space and different attrs order"] === @unchanged_file
        assert files["file1"] === nil
        new_file = files[new_file_name]
        refute new_file === nil
        assert new_file["filename"] === new_file_name
        assert new_file["language"] === "Markdown"
        assert new_file["content"] === new_file_content
    end

    test "update a cached gist should have start time reset", meta do
        gist = meta[:gist]
        start_time = Cacherl.last_updated(@key)
        new_description = "New Description"
        :timer.sleep(1000)
        Cache.update_gist(new_description, gist)
        refute Cacherl.last_updated(@key) === start_time
    end

    defp get_gist(description) do
        [
            {"id", @gist_id},
            {"description", description},
            {"user", [
                {"login", @username}
            ]},
            {"files", [
                {"file1", [
                    {"filename", "file1"},
                    {"language", "Markdown"},
                    {"content", "Conway's Game of Life in Erlang, in 2 hours, with 0 Erlang experience."}
                ]},
                {"filename with space and different attrs order", @unchanged_file}
            ]}
        ]
    end
end

defmodule CommentsTest do
    use ExUnit.Case, async: true
    alias GistsIO.Cache, as: Cache

    @gist_id "5180107"
    @username "sntran"

    @key {:comments, @gist_id}

    test "posting new comment" do
        comments = lc id inlist [1,2,3], do: get_comment(id)
        Cacherl.insert(@key, comments)
        new_comment = get_comment(4)
        Cache.add_comment(new_comment, @gist_id)
        {:ok, cache} = Cacherl.lookup(@key)
        assert cache === comments ++ [new_comment]
    end

    defp get_comment(id, username // @username) do
        [
            {"id", id},
            {"user", [
                {"login", username}
            ]},
            {"body", "Comment #{id}"}
        ]
    end
end
