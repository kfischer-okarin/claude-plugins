# session-cockpit

## Goal

In a long Claude Code session, it is hard to keep track of everything that is
going on. Open questions, proposals waiting for a decision and topics parked
for later are scattered through the transcript. The only ways to recover them
are scrolling back or having Claude repeat "there's still X open from before",
and both are tiring. The user also juggles several threads at once instead of
discussing one thing at a time without worrying that something gets forgotten.

session-cockpit is a Claude Code plugin that gives each session a cockpit the
user reads in Emacs. Its first feature is the session agenda:

- **The agenda.** A flat list of the questions Claude asked, shaped like
  Claude Code's AskUserQuestion, which the user answers at their own pace
  without anything getting lost in the transcript.
- **File anchors.** Questions point at file lines or line ranges, which the
  user sees next to the question and marked in the files.
- **Submit.** The user's answers go to Claude together, in one explicit
  submit.
- **The brief.** A short recap of what the session is doing and where it is
  now, kept current in the background.

The chat is then left for discussion that is hard to express in the agenda,
without narration of how the agenda is moving. The session transcript must
still read as one organic flow: Claude's tool calls, the user's submits and
Claude's narration together.

## Non-goals

- Code shared between `kf-review` and session-cockpit through an extracted
  common library.
- The plugin opening the editor by itself.

## Constraints / Requirements of the Solution

Guardrails for the implementation approach — the conditions any acceptable
solution has to satisfy.

- A proper plugin named `session-cockpit` in this repository's marketplace.
- All state is keyed by Claude Code session. `/clear` starts a new session and
  therefore a fresh agenda.
- Emacs is the user's interface. The Emacs code ships inside the plugin.
- Communication with Claude goes through a local MCP server written in Ruby
  with the official `mcp` gem. The user's submits reach Claude through a
  monitor.
- Ruby runs through mise (started via `mise exec`), pinned to a modern Ruby
  version the gem supports that has long-term support ahead.
- The source of truth is an append-only event log. The current agenda state is
  materialized centrally by the MCP server into a file such as `agenda.json`.
  Claude can read that state through the MCP server, and Emacs uses it as its
  primary display source. Emacs can fall back to the event data for deeper
  features.
- Appends to the event log must be safe against concurrent writers.
- Everything the user does in the dashboard is a draft until an explicit
  submit, which sends all answers at once.
- Unsent drafts live under the Emacs user directory, not with the session
  data.
- The brief is written in the background by a cheap model run that is as bare
  as possible: no CLAUDE.md, plugins, hooks or MCP servers, but it uses the
  user's subscription. The command is a plugin setting with a default that
  avoids `--safe-mode`.
- A file anchor stores the line plus enough of its text to find it again. If
  it can't be found again, that is reported along with the next submit.
- The session transcript stays understandable on its own: Claude's tool
  calls, the user's submits and Claude's narration read as one flow.
- What Claude reads from the tools is clearly parsable and readable for a
  human; the exact format is free.

## Phases

Current understanding of the implementation. Later phases are a rough direction
and may change as things are learned.

- [x] **P1: Walking skeleton: topic to Emacs, submit back to Claude**
      Quick-and-dirty end-to-end slice:
      - A plugin skeleton (`plugin.json`, marketplace entry, README section),
        written against the current official plugin docs, and installed
        locally.
      - A Ruby MCP server with a single `add_topic` tool. It appends to
        `events.jsonl` in `~/.local/state/session-cockpit/<session-id>/` and
        rewrites `agenda.json`.
      - A bare Emacs buffer that lists the topics from `agenda.json` and sends
        a free-text submit through a `session-cockpit append` CLI.
      - A plugin monitor that tails the log and prints each submit to Claude as
        Markdown.

      This slice also settles three open facts:
      - how the MCP server and the monitor learn the session ID (probably
        through a SessionStart hook), including switching over after `/clear`
      - whether plugin monitors hit a watch deadline the way Monitor-tool
        monitors do (5 minutes by default, 30 at most), or run for the whole
        session
      - how readable the MCP tool calls are in the transcript
  - [x] Spike (throwaway, via `--plugin-dir`): hook, MCP server and monitor
        logged their environment and parent process chain.
        - All three get `CLAUDE_CODE_SESSION_ID` at startup.
        - `/clear` re-runs only the SessionStart hook (`source: "clear"`, new
          ID). The MCP server and the monitor keep running with the old ID in
          their environment.
        - The MCP server is a direct child of `claude`. The monitor sits one
          `zsh` below it. Only the hook and the monitor get `CLAUDE_PID`.
        - Decided: the hook writes the current session ID to
          `~/.local/state/session-cockpit/by-pid/<CLAUDE_PID>`. The server and
          the monitor find their `claude` ancestor process and read that file,
          and the monitor switches logs when the session ID changes.
        - The plugin monitor survived `/clear` and was still running after
          33 minutes: no watch deadline like the Monitor tool's.
  - [x] Set up the plugin skeleton: `plugin.json` without `version`, to keep
        releases rolling like `my-skills`; marketplace entry; README section;
        Ruby 4.0 via `mise.toml`; `mcp`, `minitest` and `rake` via bundler.
  - [x] Drove the Ruby walking skeleton with a system test that runs the
        real executable against a temp state directory: `add_topic` over the
        MCP server lands in `agenda.json`, and a submit through `append` comes
        out of `watch` as Markdown. The executable is a thin edge over pure
        functions on `SessionCockpit` (`agenda_json_from_events`,
        `submission_markdown_from_events`), kept together until the domain
        design shows itself, and it finds
        its Gemfile independently of the working directory. Shortcuts left
        for the backlog below. Ran the tests.
  - [x] Drove the Emacs walking skeleton with a test in which the cockpit
        buffer shows the topic from `agenda.json` and the user submits a
        comment through `c` … `C-c C-c` (magit commit style), which runs the
        real `append` CLI through `mise exec`. The tests run in a throwaway
        `emacs -Q` daemon, so typed keys go through a real command loop. A
        watchdog fails the run after a time limit instead of hanging, and
        `rake` runs the Ruby and Emacs suites together. Ran both suites.
  - [x] Wired the MCP server (`.mcp.json`) and the `submissions` monitor
        into the plugin, both started through `mise exec`. Tried it in a real
        session loaded with `--plugin-dir`: a topic added by Claude showed up
        in Emacs, and a comment submitted there reached Claude as a monitor
        event. The SessionStart hook waits for the `/clear` test in the
        backlog. Learned that plugin monitors keep running without a deadline
        but make Claude Code ask for confirmation on quit, with no option to
        turn that off (hence P7). Monitor output also drops empty lines.
- [x] **P2: Agenda model and tool set**
      First, harden what P1 took shortcuts on:
      - After `/clear`, the MCP server and `watch` follow the new session ID
        through the SessionStart hook and the `by-pid` file.
      - A restarted `watch` does not re-deliver earlier submissions, and it
        no longer re-reads the whole log on every poll.
      - No concurrent writers: the MCP server is the only writer of the
        event log and materializes `agenda.json`.

      Then the full event model and its materialization:
      - Ordered topics containing items with reply threads. An item is
        something that needs an explicit action from the user: a *question*
        or a *proposal*, with a title (used when referring to it, such as in
        submissions) and a body. Mere FYIs belong in the chat, not the
        agenda.
      - Item statuses: open, accepted, dismissed, answered.
      - Moving topics: defer, or promote to the top.
      - Submissions: one `submitted` event per submit, with the user's
        comment and a list of actions (accept, dismiss, reply, defer,
        promote). References to unknown items or topics are left out of the
        agenda, since the inbox cannot refuse back to Emacs.
      - Tools for Claude: `get_agenda`, `add_topic`, `add_item`, `reply`,
        `update_item`, `close_topic`, `move_topic`.
  - [x] Followed `/clear`: a `session-start` hook writes the current session
        ID to `by-pid/<claude pid>`, and the MCP server and `watch` look it
        up on every call or poll, falling back to the ID they started with.
        The `claude` PID comes from `CLAUDE_PID` (hooks, monitors) or a walk
        up the process tree (MCP server). Tests set it through
        `SESSION_COCKPIT_CLAUDE_PID`. Ran the tests, and checked the process
        walk by hand in a real session.
  - [x] No replay: `watch` keeps the byte offset it has delivered up to in
        a `delivered` file per session, and reads only the complete lines
        beyond it. A resumed session gets only what Claude missed. Delivery is
        at least once: a crash between printing and saving the offset
        re-delivers. Ran the tests.
  - [x] Made the MCP server the only writer of the event log, so races
        between writers cannot occur rather than being locked against. A
        `flock` test could not go red, and a lock would only have guarded
        what a single writer rules out.
        - Emacs puts each submission into the session's `inbox/` as a file of
          its own, named `<timestamp>-<random>.json` so the inbox sorts by
          time. The `append` CLI and Emacs's call into Ruby are gone.
        - A thread in the MCP server takes the inbox over into the log in
          name order. A file that does not parse yet is still being written
          and waits for the next round. Submissions sent while Claude Code is
          closed wait there until it resumes.
        - Tool calls and the inbox take turns on an in-process mutex, under
          which topic IDs (`t1`, …) are assigned and stored in the event.
        - `agenda.json`, the `by-pid` files and the `delivered` offset are
          written to a temp file and renamed into place, so no reader sees
          them half-written (untested hardening).

        Ran both suites.
  - [x] Drove the agenda model test by test, one fact per test:
        - Topics carry IDs (`t1`, …) and `add_topic` answers with the ID
          (`tool_feedback_test.rb` collects what Claude reads back).
          `move_topic` defers a topic to the bottom or promotes it to the
          top; `close_topic` takes it off the agenda, while the log keeps it.
        - `add_item` adds a question or proposal to a topic, with a title and
          an optional body, numbered across the session (`i1`, …).
          `update_item` changes title and body separately. FYIs were dropped:
          they belong in the chat.
        - `reply` adds to an item's thread as `claude`.
        - A tool call that would make the agenda inconsistent raises
          `Refusal` before anything is logged and answers Claude with an MCP
          error: unknown or closed topics, unknown items and items of closed
          topics. A broken event in the log would otherwise stop every later
          materialization.
        - `get_agenda` shows the agenda as an outline: topics as `[t1]
          title` with the active top one in bold, items as `[i1] kind:
          title` with the body lined up behind the ID, replies as `↳ author:
          text` at the item's level. Settled items are struck through
          (accepted ✅, dismissed ❌, answered without emoji) and listed
          after the open ones; that order is display only. An empty agenda
          says so.
        - A submission is one `submitted` event with the user's `comment`
          and a list of `actions`. Claude reads it as one line per action,
          naming items as `[i2] title` and topics as `[t2] title`, then the
          comment. Items start `open`; accept and dismiss settle them, a
          reply joins the thread as `user` and answers a question (a proposal
          stays open), defer and promote move a topic. The walking skeleton
          test was removed as redundant.
        - The SessionStart hook forgets `by-pid` files of `claude` processes
          that have ended, and keeps those of processes still running.
        - Code layout after two refactorings:
          - `Agenda` (with `Topic`, `Item`, `Reply`) is an immutable value
            built by replaying the log. It knows the next IDs (counting
            everything ever added, closed topics included) and raises
            `Refusal` for operations on topics or items not on the agenda,
            which now includes items of closed topics.
          - `Formatter` turns an agenda into the outline and a submission
            into what Claude reads.
          - `SessionStateRepository` and `SessionState` own the files on
            disk; `append` hands its block the current `Agenda`, and
            `agenda.json` is output for Emacs only.
          - `MCPServer` holds the tools on an `AgendaTool` base (`log_event`,
            `respond`), and `Watch` the monitor loop. The executable only
            reads the environment.

        Ran both suites throughout.
- [x] **P3: Emacs dashboard**
      - Interaction is magit-like: `c` opens a message buffer, `C-c C-c`
        submits the message with all pending drafts, `C-c C-k` cancels and
        discards the comment. P1 has only `c` and `C-c C-c`, with no
        drafts, and the buffer shows plain topic lines without a refresh.
      - A `magit-section` buffer: the active topic expanded, then the
        backlog collapsed (the brief goes on top once it is built). Items are
        sections too, and settled items start collapsed. The user's own
        expanding and collapsing holds across redraws until the agenda
        changes the section's state: an item settling, a topic becoming
        active or moving into the backlog. That is where the
        dashboard deliberately differs from `get_agenda`, which always gives
        Claude everything.
      - Everything the user does stays in Emacs until a submit, and each
        kind of unsent change has its own representation:
        - Decisions: an open proposal has a `[✓ Accept] [✗ Dismiss]` toggle
          right-aligned on its line, an open question just `[✗ Dismiss]`
          (it is answered by a reply). Clicking or `a`/`x` selects, switches
          or, on the selected button, deselects. Settled items have none.
        - Replies: at most one unsent reply per item, shown in the thread
          where it will land as `↳ you: …` with a background, an
          `unsubmitted` badge and a 🗑 button. `r` or `RET` on the item opens
          it in the child-frame editor, and `k` or 🗑 deletes it.
        - The header line counts what is unsent, next to the Submit button.
      - Every open item ends in a `Comment` button below its body or last
        reply, reading `Answer` on an open question; it opens the reply
        editor like `r`. While the item has an unsent reply, that reply
        takes the button's place. Items are separated by an empty line, collapsed or not.
      - Topics, items and replies Claude added since the user's last submit
        carry a `new` badge and a slightly different background (a topic
        only on its heading). Ruby marks them `"new": true` in
        `agenda.json` from the event log; Emacs only shows the mark. Items
        Claude rewords get a `changed` badge the same way, after the `new`
        badges.
      - Unsent changes persist to
        `~/.emacs.d/session-cockpit/drafts/<session-id>.json`.
      - If Claude changes an item while the user is drafting on it, the item
        is flagged as changed. If Claude settles it, an unsent decision on it
        is dropped, while an unsent reply stays.
      - Emacs and Ruby meet at two files: the submission in the inbox
        (Emacs writes, Ruby reads) and `agenda.json` (Ruby writes, Emacs
        reads). Each gets contract tests: a committed example file that one
        side's test must produce and the other side's test consumes.
      - Live refresh when `agenda.json` changes.
      - `init.el` loads the elisp from the installed plugin's path, with an
        override for the checkout.
      - `session-cockpit-show`: an interactive picker that lists sessions
        newest-updated first, with project, time, the active topic and the
        open-item count. It also accepts a session ID argument.
      - Keys: `a` accept, `x` dismiss, `r`/`RET` reply, `k` deletes the
        unsent reply at point, `c` message and submit, `g` refresh. A Submit button in the header line opens the
        message buffer too, like kf-review's header buttons.
      - The reply editor follows kf-review's child frame (`kf-review-edit-comment`).
        Tests replace it with a stand-in, since the test daemon has no
        graphical frame.
  - [x] Drove the outline display test by test. Topics and items are
        `magit-section`s (`TAB` toggles them): the active topic expanded, the
        backlog collapsed, settled items collapsed and struck through after
        the open ones, with ✅/❌ like `get_agenda`. Bodies and replies line
        up behind the item's ID, a reply's further lines behind its arrow,
        on both sides (the Ruby outline changed with it). Long lines wrap at
        words, continuing behind the ID or arrow (`adaptive-fill-regexp`,
        since `visual-wrap-prefix-mode` overwrites a hand-set `wrap-prefix`).
        Faces inherit from built-in ones. Learned:
        - Collapsed sections hide only once the root section is shown.
        - The test runner loads `magit-section` from the elpaca builds, and
          stops its daemon with `SIGKILL`: `SIGTERM` during GC ran
          `kill-emacs-hook` halfway and made Emacs abort with a crash report.

        Ran both suites, and tried it in a live session.
  - [x] Drove the decision toggles test by test. Open proposals show
        `✓ Accept`/`✗ Dismiss`, open questions just `✗ Dismiss`, right-aligned
        on the item line. `a`/`x` or a click select, switch, or on the
        selected button deselect; `a` on a question and either key on a
        settled item are refused with a message. A submit sends the decisions
        as actions in the order made, then clears them. Decisions live in the
        cockpit buffer, which redraws through `g` (`revert-buffer`) and keeps
        sections as the user left them (magit-section's visibility cache).
        Learned:
        - A section with a body puts magit-section's heading keymap over its
          whole heading line, so a click on a button there pasted into the
          read-only buffer. Buttons get their own keymap back after each
          redraw, and the click helper now fails unless a click runs
          `push-button`.
        - The section highlight at point paints over any background, so
          the toggle state shows in foreground, box and weight.

        Pinned in Ruby that dismissing a question makes it dismissed. Ran
        both suites, and tried keys and faces in a live session.
  - [x] Added contract tests as scenarios: `contract_fixtures/<scenario>/`
        holds, numbered by step, each `agenda.json` and submission the two
        sides exchange, plus what each reader sees of it (`dashboard.txt`,
        `get_agenda.md`, `monitor.md`). Ruby drives a scenario through the
        MCP tools and the inbox and compares the agendas and Claude's views;
        Emacs loads the agendas, drives the dashboard and compares the
        submissions and the dashboard. Assertions are plain comparisons
        against fixtures. One scenario, `round_trip`, covers every agenda
        field and both decisions so far. In Emacs, fixtures read with sorted
        keys and arrays as vectors, so `equal` compares JSON. Ran both suites.
  - [x] Drove unsent replies test by test. `r`/`RET` or the `Answer`
        (question) / `Comment` (proposal) button below an open item open
        kf-review's child-frame editor (a stand-in in tests), which starts
        with the unsent text if there is one. The reply shows where it will
        land as `↳ you: …` with an `unsubmitted` badge and a 🗑️ button, in
        place of the Answer/Comment button; `k` on it or 🗑️ deletes it, and
        an emptied editor drops it. A submit sends replies after the
        decisions and clears them. `round_trip` gained a reply, pinning the
        mixed order and `answered`. Learned:
        - 🗑 (U+1F5D1) is script `symbol` in Emacs and found no font; with
          the emoji selector U+FE0F it composes as emoji (Apple Color Emoji).
        - magit-section's visibility cache remembered every section's first
          state, so an item settled while expanded stayed expanded. The
          cockpit now remembers visibility itself and lets the agenda's
          default win once it changes.
        - mise moved `ruby 4.0` to 4.0.9; the locked gems needed a
          `bundle install` again (the MCP server would not start otherwise).

        Ran both suites.
  - [x] Started moving topics from the dashboard (`>`, an "Order changed"
        banner), then dropped it: telling Claude "let's do X next" is easier
        than reordering by hand. Removed the Emacs side and the `defer` and
        `promote` submission actions in Ruby; Claude's `move_topic` stays.
        Kept from it: a redraw keeps point on the same section, not the same
        line. Ran both suites.
  - [x] Drove `new` and `changed` test by test. Ruby's `Agenda` marks
        topics, items and Claude's replies `new` when added and items
        `changed` when reworded (unless still new); a submit clears both, and
        the user's own replies are never new. `agenda.json` carries
        `"new"`/`"changed": true` only where set. Emacs shows a `new` or
        `changed` badge after the title (before the toggle) with a light
        background tint, on a topic only its heading. `round_trip` gained
        the marks in 01 and a rewording as step 04. Ran both suites.
  - [x] Saved unsent decisions and replies to
        `~/.emacs.d/session-cockpit/drafts/<session-id>.json`, as the actions
        they will be submitted as, on every change; the file goes once
        nothing is unsent. `C-c C-k` discards the comment, asking first if
        there is one. The header line counts the unsent changes before a
        clickable Submit, which opens the message buffer. Ran both suites.
  - [x] Live refresh: the cockpit watches its session's directory with
        `file-notify` and redraws when `agenda.json` is replaced. Drafted
        items Claude changes: the `changed` badge already flags a reworded
        one, and a redraw drops unsent decisions on items Claude settled,
        keeping unsent replies. Test helpers now write `agenda.json` through
        a rename like the MCP server, and wait with `sit-for`, since file
        notifications arrive as input events. Ran both suites.
  - [x] Session picker: the SessionStart hook records the input's `cwd` as
        `session.json` (`{"project": …}`), also after `/clear`.
        `M-x session-cockpit-show` lists the sessions with an agenda, the
        most recently updated first, as `project  MM-DD HH:MM  active topic
        (N open)`, and opens the picked one. `round_trip` gained
        `01_session.json` and `01_picker.txt`, and Emacs's half now opens its
        cockpit through the picker. Ran both suites.
  - [x] `init.el` in dev-settings autoloads `session-cockpit-show` from the
        checkout when present, else from the newest installed version of
        the plugin. No global key yet. Checked in an isolated Emacs with the
        full config.
  - [x] Tried in a real session started with `--plugin-dir`: the picker
        named its project, a submit with a comment and a reply reached
        Claude through the monitor and got answered on the item, and unsent
        decisions were saved to the drafts file.
- [x] **P4: Flat list of questions**
      Reworked the agenda in place after trying P3 in a real session: a flat
      list of questions shaped like AskUserQuestion replaces topics,
      proposals and reply threads.
  - [x] Ruby: `ask` takes any number of questions, each with the question,
        2 to 4 options (label, description and an optional preview) or none
        for a free-text answer, and `multiSelect`. AskUserQuestion's headers
        and its limit of 4 questions per call were dropped, since the cockpit
        is neither a blocking prompt nor short of space. The input schema
        holds the upper limit, which the `mcp` gem enforces; Ruby refuses a
        single option and repeated labels. `update_questions` changes only
        what each change names, `withdraw_questions` takes back moot
        questions, both all or nothing, as every tool call is one append to
        the log. `get_questions` lists the open ones. A submit carries
        `answers` (the picked labels and optional text) and marks each
        question answered, keeping its answer; answered and withdrawn
        questions stay in `agenda.json` for a later "show settled" view. The
        monitor prints each answer under its question, text as the answer to
        a question without options, as "Other" without a pick and as a note
        with one.
  - [x] Emacs: each open question is a section with numbered options,
        `( )`/`(•)` or `[ ]`/`[x]` for several picks, previews below their
        option. `1`–`4`, `RET` or a click picks, picking again takes back;
        `r`, `RET` on the heading or the `Answer…`/`Other…`/`Note…` button
        writes text, shown as `↳ you: …` until submitted. Unsent answers are saved
        to disk as the answers they will be submitted as, and a redraw drops
        answers to questions no longer open and picks of options Claude took
        off. The header line counts unsent answers. magit's own visibility cache
        remembers collapsed questions again, since nothing changes their
        default anymore.
  - [x] `round_trip` redone for questions on both sides; ran both suites.
- [ ] **P5: Cockpit started per session, and how Claude uses it**
      A `start-cockpit` skill turns the cockpit on for a session and carries
      the guidance for using it; the MCP `instructions` and tool descriptions
      stay short.
  - [x] Ruby: `session-cockpit start SESSION_ID` turns the session's
        cockpit on (a `cockpit` file in its state directory) and prints that
        it is on and the open questions. `watch` records its PID as
        `by-pid/<claude pid>.monitor`. The tools refuse unless the cockpit
        is on and that monitor runs, the refusal saying to run the skill, or
        to start `watch` with the Monitor tool when the skill already ran in
        this process. `/clear` leaves the new session's cockpit off. On
        resume, the SessionStart hook tells Claude to run the skill again,
        since the monitor starts only on the skill's first run per process.
        Test sessions now stand a real process in for `claude`, so the hook
        does not forget their monitors. Ran both suites.
  - [x] Plugin: the `submissions` monitor starts on
        `on-skill-invoke:start-cockpit`. The skill's description lets the
        user start it, and Claude once it has more than about half a dozen
        things to ask at once; its body has Claude move open questions from
        the chat into `ask`, prefer `ask` over AskUserQuestion, and leave
        the agenda's changes out of the chat. `ask` describes itself
        through AskUserQuestion. Checked headless (`claude -p`) that the
        skill's `!` line runs with `${CLAUDE_SESSION_ID}` substituted;
        plugin monitors don't start under `-p`.
  - [ ] Tried in a real session: the monitor starting on the skill (also
        under its plain name), resume, `/clear`, and how the transcript
        reads (long `ask` arrays, the submit Markdown).
- [x] **P6: File anchors**
      - A question can point at any number of places in files, inside the
        session's project or not: anchors of file and line range. The MCP
        server reads their text from the file when Claude asks, so Claude
        only names lines.
      - The cockpit shows each anchor below its question: a reference
        button and at most 3 lines of its text. `RET` on it shows the file
        at those lines in a window next to the cockpit, point staying in the
        cockpit.
      - File buffers mark the lines anchored by the open questions of every
        open cockpit, in a look of their own (tint and fringe bitmap), with
        the question on hover.
      - When a file is visited or the cockpit redraws, an anchor's text is
        searched for again, the match nearest the old line winning. The
        reference and mark follow it; an anchor whose text is gone shows as
        not found, and the next submit tells Claude.
  - [x] Ruby: `ask` and `update_questions` take `anchors` (file, start,
        optional end); the server reads their text itself and stores the
        file's absolute path, a relative one taken as relative to the
        project `session.json` names. Files anywhere may be pointed at;
        missing files and lines beyond the end are refused. `get_questions`
        lists `⌖ file:lines` below each question, the file relative to the
        project when within it and with ~ for the home directory otherwise.
        A submit's `lost_anchors` print as warnings before the comment.
        Contract scenario `anchors`, with a fixture project each side copies
        before changing it; `<project>` in its fixtures stands for the
        copy's path.
  - [x] Emacs: each anchor below its question, before the options: a
        `⌖ file:lines` button, its file shown as in `get_questions`, and at
        most 3 dedented lines of its text, then
        "… N more lines". `RET` or a click shows the lines in another
        window, point staying in the cockpit.
  - [x] Marks in file buffers: a tint of its own, a "?" bitmap in the left
        fringe (kf-review uses the right one), the question on hover; for
        the open questions of all open cockpits, redone when a cockpit
        redraws or closes and when a file is visited.
  - [x] Moved anchors followed: the text is looked for in the file, or in
        the buffer visiting it, nearest the stored lines; references and
        marks show where it is now. Anchors whose text is gone show "not
        found" and go to Claude as `lost_anchors` with every submit while
        gone. Checked that the anchor tests fail when locating is broken;
        ran both suites.
  - [x] Tried in a real session.

  Test backlog (O = asked for by Okarin, S = suggested):
  - (None)
- [ ] **P8: Brief**
      - An async Stop hook runs the `brief_command` setting with the previous
        brief, the agenda and the transcript tail on stdin, and writes the
        result to `brief.md`. The hook keeps the old brief if the run fails.
      - The default is a minimal Haiku `claude -p` run with
        `--setting-sources ""`, `--strict-mcp-config` and `disableAllHooks`,
        using text output.
      - To verify: that the empty `--setting-sources ""` (undocumented, but
        worked in a manual test) still works, and that `async` works for Stop
        hooks. The transcript file can lag the current turn, so the hook adds
        the Stop input's `last_assistant_message` to the transcript tail.
      - The brief goes on top of the cockpit buffer, and its first line into
        the session picker. The hook skips sessions whose cockpit is off.

## Current position / notes

- P4 done: the agenda is a flat list of questions. Okarin keeps trying the
  cockpit in real sessions, and what comes up feeds into the coming phases.
  P6, file anchors, is done and tried. P5 (with what was P7) is built; next
  is trying the skill in a real session.

## Deferred work

- A session-cockpit view inside Claude Code itself (status line, band or pane
  through the plugin).
- An overview buffer across all running sessions.
- Structure beyond a flat list of questions: topics grouping them, proposals
  to accept or dismiss, and reply threads, as P3 had them.
- A "show settled" view of answered and withdrawn questions, which
  `agenda.json` already keeps.
- Anchors on diff hunks or removed lines, as kf-review has them.
- Jumping from a marked line in a file back to its question.
- Moving `kf-review` into session-cockpit, with deeper MCP integration.

## Appendix

### Working Principles

How to execute and update this plan across sessions.

- **Drive both the Ruby and the Emacs side test-first**, with BDD-style tests
  for the behaviours the user relies on, one behaviour at a time.
- **Before each phase, describe the rough design approach and get a quick OK** —
  where things get added/changed at a high level. Stay high-level on purpose:
  don't lock down low-level choices in advance. Implementing the phase settles
  them naturally, and pinning them early just creates spec churn.
- **Write a sub-step todo-list only for the phase you're currently in**, and
  only after you've described and confirmed its rough approach. Never pre-write
  sub-steps for future phases — what you learn will likely invalidate them.
- **When you complete a sub-step, rewrite it in place in past tense**, folding
  in what you did, what you learned, and how you verified it in abstract terms
  (e.g. "ran acceptance tests", "ran unit tests", "tested manually via the
  CLI"). No need to cite concrete test counts. Don't append a separate "Done"
  summary. Check off the phase once all its sub-steps are.
- **When you discover a "do this later, within this work" item:** add it as a
  sub-step if it belongs to the current phase, otherwise note it in the relevant
  future phase's description.
- **When a piece of work is identified as necessary but not part of this round,
  move it to Deferred work** — wanted, just not now. If instead it will not be
  done at all, it belongs under Non-goals.
- **Keep "Current position / notes" pointing at where you are and what's next**,
  updating it as the work moves — one or two lines only.
- **Never delete a section that goes empty.** If a section has no items, or its
  items all get resolved, leave the heading and write `- (None)` under it.

### Example phases in progress

``` markdown
- [x] **P1: Webhooks persisted end-to-end**
  Quick-and-dirty thin slice: receive a webhook, store it, show it in the admin list.
  - [x] Added deliveries table + model
  - [x] Controller now writes the payload on receipt — stored raw for now, redaction deferred to P3
  - [x] Added a bare admin list view; confirmed the receipt-to-list path — ran acceptance tests
- [ ] **P2: Retry failed deliveries**
  Background job re-sends deliveries that errored, with capped backoff.
  - [x] Marked deliveries failed / succeeded on the delivery record
  - [ ] Enqueue the retry job with capped backoff
- [ ] **P3: Redact secrets in stored payloads**
  Direction only — exact redaction rules still open.
```

P1 is done: its sub-steps are rewritten in past tense and carry what/learned/how
inline. P2 is current, so it has a sub-step todo-list. P3 is still future — just a
title and a one-line direction, no sub-steps until it becomes current.
