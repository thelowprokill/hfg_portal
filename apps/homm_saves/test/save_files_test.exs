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
end
