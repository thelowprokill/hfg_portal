defmodule HommSaves.SaveFilesTest do
  use HommSaves.DataCase

  alias HommSaves.SaveFiles

  test "abs_path keeps paths inside the section" do
    root = SaveFiles.root()
    assert {:ok, "AUTOSAVE.GM1", abs} = SaveFiles.abs_path("saves", "/AUTOSAVE.GM1")
    assert abs == Path.join([root, "saves", "AUTOSAVE.GM1"])
    assert {:ok, "Hota Random/a b/111.GM1", _} = SaveFiles.abs_path("templates", "Hota Random\\a b\\111.GM1")

    for bad <- ["../x", "a/../../x", "..", "", "/", nil] do
      assert SaveFiles.abs_path("saves", bad) == :error, "expected #{inspect(bad)} to be rejected"
    end

    assert SaveFiles.abs_path("other", "x.GM1") == :error
  end

  test "upsert overwrites per section and changed_since hides the uploader's own files" do
    {:ok, first} = SaveFiles.upsert("saves", "t/111.GM1", "pc1")
    {:ok, again} = SaveFiles.upsert("saves", "t/111.GM1", "pc2")
    {:ok, tmpl}  = SaveFiles.upsert("templates", "t/111.GM1", "pc2")

    assert again.id == first.id
    assert tmpl.id != first.id
    assert DateTime.compare(again.updated_at, first.updated_at) == :gt

    assert [%{machine: "pc2", section: "saves"}] = SaveFiles.changed_since("saves", nil, "pc1")
    assert []                                    = SaveFiles.changed_since("saves", nil, "pc2")
    assert []                                    = SaveFiles.changed_since("saves", again.updated_at, "pc1")
  end

  test "list pages by the last file seen, so an upload between pages doesn't repeat or skip rows" do
    for n <- 1..5, do: {:ok, _} = SaveFiles.upsert("saves", "#{n}.GM1", "pc1")

    page1 = SaveFiles.list("saves", 2)
    assert Enum.map(page1, & &1.path) == ["5.GM1", "4.GM1"]

    # a new upload goes to the top; with an offset it would push 4.GM1 onto page 2 again
    {:ok, _} = SaveFiles.upsert("saves", "6.GM1", "pc1")

    page2 = SaveFiles.list("saves", 2, List.last(page1))
    assert Enum.map(page2, & &1.path) == ["3.GM1", "2.GM1"]
    assert Enum.map(SaveFiles.list("saves", 2, List.last(page2)), & &1.path) == ["1.GM1"]
  end
end
