# frozen_string_literal: true

require "test_helper"

# Places in files a question points at.
class AnchorsTest < SessionCockpit::SystemTestCase
  WATCH_RB = "module Watch\n  def self.run\n    loop do\n    end\n  end\nend\n"

  def test_an_anchor_keeps_the_lines_it_points_at_with_their_text
    project = create_project("lib/watch.rb" => WATCH_RB)
    session = start_session(project: project)

    session.call_mcp_tool("ask", questions: [
                            question("Should this also handle /clear?",
                                     anchors: [{ file: "lib/watch.rb", start: 2, end: 3 }])
                          ])

    assert_equal [{ "file" => "#{project}/lib/watch.rb", "start" => 2, "end" => 3,
                    "text" => "  def self.run\n    loop do" }],
                 session.agenda["questions"].first["anchors"]
  end

  def test_an_anchor_without_an_end_is_a_single_line
    project = create_project("lib/watch.rb" => WATCH_RB)
    session = start_session(project: project)

    session.call_mcp_tool("ask", questions: [
                            question("Why a module?", anchors: [{ file: "lib/watch.rb", start: 1 }])
                          ])

    assert_equal [{ "file" => "#{project}/lib/watch.rb", "start" => 1, "end" => 1, "text" => "module Watch" }],
                 session.agenda["questions"].first["anchors"]
  end

  def test_a_question_can_point_at_several_places
    project = create_project("lib/watch.rb" => WATCH_RB, "README.md" => "# Watch\n")
    session = start_session(project: project)

    session.call_mcp_tool("ask", questions: [
                            question("Document the loop?", anchors: [{ file: "lib/watch.rb", start: 3, end: 4 },
                                                                     { file: "README.md", start: 1 }])
                          ])

    assert_equal ["#{project}/lib/watch.rb:3-4", "#{project}/README.md:1-1"],
                 session.agenda["questions"].first["anchors"].map { "#{it["file"]}:#{it["start"]}-#{it["end"]}" }
  end

  def test_an_anchor_can_point_outside_the_project
    elsewhere = create_project("zshrc" => "export EDITOR=emacsclient\n")
    session = start_session(project: create_project("lib/watch.rb" => WATCH_RB))

    session.call_mcp_tool("ask", questions: [
                            question("Keep emacsclient?", anchors: [{ file: "#{elsewhere}/zshrc", start: 1 }])
                          ])

    assert_equal [{ "file" => "#{elsewhere}/zshrc", "start" => 1, "end" => 1, "text" => "export EDITOR=emacsclient" }],
                 session.agenda["questions"].first["anchors"]
  end

  def test_a_missing_file_is_refused_and_nothing_is_asked
    session = start_session(project: create_project("lib/watch.rb" => WATCH_RB))

    reply = session.call_mcp_tool("ask", questions: [
                                    question("Why a module?", anchors: [{ file: "lib/watch.rb", start: 1 }]),
                                    question("Why?", anchors: [{ file: "lib/gone.rb", start: 1 }])
                                  ])
    session.call_mcp_tool("ask", questions: [question("Rename it?", options: ["Yes", "No"])])

    assert_equal "There is no file lib/gone.rb", reply
    assert_equal [["q1", "Rename it?"]], session.agenda["questions"].map { it.values_at("id", "question") }
  end

  def test_lines_beyond_the_end_of_the_file_are_refused
    session = start_session(project: create_project("lib/watch.rb" => WATCH_RB))

    reply = session.call_mcp_tool("ask", questions: [
                                    question("Why?", anchors: [{ file: "lib/watch.rb", start: 5, end: 9 }])
                                  ])

    assert_equal "lib/watch.rb has 6 lines, so no lines 5-9", reply
  end

  def test_an_update_points_a_question_elsewhere_with_the_text_read_anew
    project = create_project("lib/watch.rb" => WATCH_RB)
    session = start_session(project: project)
    session.call_mcp_tool("ask", questions: [
                            question("Why a module?", anchors: [{ file: "lib/watch.rb", start: 1 }])
                          ])
    File.write(File.join(project, "lib/watch.rb"), "class Watch\n#{WATCH_RB.lines.drop(1).join}")

    session.call_mcp_tool("update_questions", questions: [{ id: "q1", anchors: [{ file: "lib/watch.rb", start: 1 }] }])

    assert_equal "class Watch", session.agenda["questions"].first["anchors"].first["text"]
  end
end
