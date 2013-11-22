defmodule DiffFilesTest do
    use ExUnit.Case, async: true
    alias GistsIO.Utils, as: Utils

    setup do
    	existings = [
    		{"existing_file_1", [{"content", "existing_content_1"}]},
    		{"existing_file_2", [{"content", "existing_content_2"}]}
    	]
    	{:ok, existings: existings}
    end

    test "against no existing files" do
    	new_files = [{"file1", []}, {"file2", []}]
    	assert Utils.diff_files([], new_files) === new_files
    end

    test "against one file change should contain changed content", meta do
    	existings = meta[:existings]
    	changed_files = [{"existing_file_1", [{"content", "new_content_1"}]}]
    	diff = Utils.diff_files(existings, changed_files)
    	attrs = diff["existing_file_1"]
    	refute attrs["content"] === "existing_content_1"
    	assert attrs["content"] === "new_content_1"
    end

    test "against one file change should set the other to null", meta do
    	existings = meta[:existings]
    	changed_files = [{"existing_file_1", [{"content", "new_content_1"}]}]
    	diff = Utils.diff_files(existings, changed_files)
    	assert diff["existing_file_2"] === "null"
    end 

    test "against a file not change should not include it", meta do
    	existings = meta[:existings]
    	changed_files = [{"existing_file_1", [{"content", "existing_content_1"}]}]
    	diff = Utils.diff_files(existings, changed_files)
    	assert diff["existing_file_1"] === nil
    end

    test "against no file change at all should return empty", meta do
    	existings = meta[:existings]
    	changed_files = [
    		{"existing_file_1", [{"content", "existing_content_1"}]},
    		{"existing_file_2", [{"content", "existing_content_2"}]},
    	]
    	diff = Utils.diff_files(existings, changed_files)
    	assert diff === []
    end

    test "against a renamed file", meta do
    	existings = meta[:existings]
    	changed_files = [
    		{"existing_file_1", [{"content", "existing_content_1"}]},
    		{"existing_file_2", [
    			{"content", "existing_content_2"},
    			{"filename", "new_file_2"}
    		]},
    	]
    	diff = Utils.diff_files(existings, changed_files)
    	assert length(diff) === 1
    	assert diff["existing_file_1"] === nil
    	file = diff["existing_file_2"]
    	refute file === nil
    	assert file === changed_files["existing_file_2"]
    end
end