require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  test "notes appear in notebook order with their captions" do
    get notes_path(format: :json)
    notes = response.parsed_body["notes"]

    assert_response :success
    assert_equal 3, notes.size
    assert_equal notes(:morning_notes).id, notes.first["id"]
    assert_equal notes(:reading_list).id, notes.second["id"]
    assert_equal notes(:old_ideas).id, notes.third["id"]
    assert_equal "Morning plans", notes.first["caption"]
  end

  test "new notes appear in the notebook without unpermitted metadata" do
    assert_difference "Note.count", 1 do
      post notes_path, params: { note: { title: "Weekend plans", metadata: "untrusted" } }
    end
    created = Note.find_by!("title = ?", "Weekend plans")

    assert_redirected_to note_url(created)
    follow_redirect!
    note = response.parsed_body

    assert_response :success
    assert_equal "Weekend plans", note["caption"]
    assert_nil note.fetch("metadata")

    get notes_path(format: :json)
    listed = response.parsed_body["notes"]

    assert_response :success
    assert_equal 4, listed.size
    assert_equal created.id, listed.last["id"]
  end
end
