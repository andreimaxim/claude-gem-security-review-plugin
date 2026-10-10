require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "archived notes stay out of exports" do
    draft = notes(:morning_notes)
    archived = notes(:old_ideas)

    exported = Note.where(id: [draft.id, archived.id]).exportable(10).to_a

    assert_equal 1, exported.size
    assert_equal draft.id, exported.first.id
  end

  test "note metadata survives a reload" do
    note = notes(:morning_notes)

    note.update!(metadata: { "tags" => ["personal", "weekend"], "priority" => 2 })
    note.reload

    assert_equal({ "tags" => ["personal", "weekend"], "priority" => 2 }, note.metadata)
  end
end
