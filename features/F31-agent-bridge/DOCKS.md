# F31 — Agent Bridge and the tmax Command

One validated, app-owned path that lets an AI agent, a script, or the in-app AI Coach do everything in Tmax that a person can do with the library: upload photos and videos, create exercise and container pages, write notes, build workouts, and import videos from links. The agent never writes files itself. It asks the running Tmax app, and the app performs the change, so the screen updates immediately and nothing can be left half-written.

## Why It Exists

Before this feature an agent had two bad options. It could write files straight into the library folder, which skipped validation, produced pages the app could not see, and lost notes the next time the app rewrote a page. Or it could use the old command-line tool, which spoke an older data format and showed none of the current pages. The in-app Coach had its own third copy of the tool list, built on the same old format, so pages it created did not appear in the Database screen, and its follow-up requests to the AI provider were malformed after the first tool call.

Now there is one tool catalog, defined once, and three thin doors into it.

## What We Build

- **The tool catalog.** A single list of library tools shared by every door. Each tool has a name, a plain description, a risk level, and a typed list of options. The catalog is the only place that says what an agent can do.
- **The Tmax bridge.** A local-only channel inside the Mac app, open to programs running as the same user on the same Mac and nobody else. It exists only while the app is running and agent access is not Off.
- **The tmax command.** A small, fast native program written in Rust and bundled inside the app. It finds the running app, opens it in the background if needed, waits until it is ready, runs one tool, and prints the result as JSON.
- **An MCP mode.** The same command can run as a Model Context Protocol server over standard input and output, so Claude Desktop, Cursor, and similar tools can use the catalog directly without any shell.
- **The in-app Coach door.** The Coach now uses the same catalog and the same execution path. It asks the person only before deleting.
- **Agent Access settings.** A Mac settings page where the person chooses how much agents may do, and installs the tmax command into their shell path.
- **Video import for agents.** One tool that downloads a video link or reads a local video, cuts named clips from it, and saves each clip as its own exercise page.
- **Batch and undo.** A tool that runs a list of steps in order, where later steps can use the results of earlier ones, and everything is rolled back if one step fails; and a tool that reverses the most recent agent batch.

## The Tool Families

| Family | What an agent can do | Risk |
|---|---|---|
| Orientation | Read a one-call overview of the library, workout types, workouts, and the conventions to follow; list the available types; read settings | Read |
| Browsing | List pages, search pages by words, read one page in full, read workouts, read recent history and statistics | Read |
| Creating and changing | Create container pages (categories and progressions), create exercise pages with a title, type, timings, instructions, links, and media; attach more photos and videos to an existing page; append a note to a page; update a page's fields or body; move a page to another container; build a workout from exercise pages; import a video as named clips; change a small set of safe app settings | Write |
| Deleting | Delete a page, delete a workout (both go to the trash) | Delete |
| Control | Run a batch; undo the last agent batch | Write |

Pages are referred to by their title path (for example a category, then a progression, then an exercise) or by their identifier. If a title matches several pages the tool refuses to guess and lists the matches. If nothing matches it says so and suggests the closest titles.

## Rules for Content the Agent Sends

- Media is always sent as a file location on this Mac. The app copies the file into the library; the agent never places files itself. Allowed photo types are JPEG, PNG, HEIC, HEIF, GIF, and WebP. Allowed video types are MP4, MOV, and M4V. A file larger than four gigabytes is refused. A file that is still only a cloud placeholder (not downloaded to this Mac) is refused with an explanation.
- A new page with the same title as an existing page in the same place is refused by default. The agent can choose to reuse the existing page or create a numbered duplicate.
- Workout types are a root-level idea. Only a top-level container carries a type; a nested page that is given a type is created and a warning explains that the type was ignored.
- Every result is compact JSON and every failure has a short code, a plain message, and a hint that says what to try next. See Output Size below.
- Unknown options are rejected with a list of the allowed ones, so a misspelled option can never silently create a page with a default name.
- Any change can be previewed first with a dry-run, which validates everything and reports what would be created without changing anything.

## Trust Levels

The person decides how far agents may go. The choice is saved and applies at once. The rule is simple: agents may add, edit, and move freely, and only deleting ever asks.

| Level | Reading and dry-runs | Adding, editing, moving, importing, settings | Deleting |
|---|---|---|---|
| Off | Refused. The bridge is closed and the tmax command reports that access is off | Refused | Refused |
| Read only | Allowed | Refused | Refused |
| Standard (default) | Allowed | Allowed without asking | The app shows a confirmation and waits |
| Full | Allowed | Allowed | Allowed without asking |

A batch is judged by the riskiest step inside it, so a batch that contains a delete asks once before it starts. Deleted pages go to the trash rather than disappearing, and everything an agent creates is recorded so the last batch can be undone.

## The Delete Confirmation

When a delete needs confirmation, Tmax brings itself forward and shows a native alert titled "An agent wants to delete something". It states in one sentence what will be deleted, lists up to eight key details, and adds that deleted items go to the trash and can be restored. The buttons are Cancel, which is the default and answers to Return, and Delete, drawn as a destructive action. Only one confirmation is shown at a time; a second request waits in line. If nothing is chosen within the wait time the agent gave (two minutes unless it asked for more), the alert closes itself and the agent is told that no answer was given. Cancel tells the agent that the person declined, with no side effects. Dry-run deletes never ask.

## Output Size

Whatever an agent prints or reads counts against its own conversation, so every tool answers as briefly as it can while staying clear.

- Pages are named by title path, which is also how they are referenced, so lists show paths and leave out ids unless two pages share a path.
- Empty and default values are left out: no empty lists, no zero counts, no repeated parent, kind, or type on every row.
- Folders are marked as folders; exercises carry only their duration, sets, and attachment count when they have any. Only root pages show the workout type.
- Lists stop at a limit (sixty pages for a listing, twenty search results, thirty history entries, thirty root folders in the overview) and say how many more exist and how to narrow the request.
- Results of changes name only what changed: the page path, its id, and the changed fields. Batch results are one short entry per step.
- Paths are written plainly, without escaped slashes.
- Printed to a terminal the result is indented for reading; piped to an agent it is one compact line.

## States

| State | What the agent or user experiences |
|---|---|
| App not running | The tmax command opens Tmax in the background without stealing focus, then waits up to forty-five seconds for it to be ready |
| App starting | The bridge answers but reports not ready; the command waits, and direct callers receive a "still opening" error with a hint to retry |
| Ready | Tools run; results arrive as JSON |
| Access Off | No channel exists; the command reports it cannot reach Tmax and suggests checking Agent Access |
| Access too low for the tool | The tool is refused with a message naming the current level and where to change it |
| Awaiting delete confirmation | The command holds the connection open until the person answers or the wait ends |
| Different version | If the command and the app speak different protocol versions, the command stops and asks for both to be updated together |
| Unknown tool or option | Refused with the closest matching names |
| Library account changed mid-call | The change is refused rather than written into the wrong library |
| Command not installed | Agent Access settings shows that the tmax command is not on the path and offers to add a link; an existing different tmax is never overwritten |

## The Agent Access Settings Page (Mac)

Reached from Settings, in the AI and Import group, as "Agent Access" with a terminal icon. A segmented control chooses Off, Read only, Standard, or Full, with a sentence below it that explains the selected level. A second section titled "Command line" shows whether the tmax command is installed, where the link lives, and an Install button when it is missing. On iPhone and iPad the page explains that agent access runs in the Mac app and that the library reaches the phone through backups or database sync.

## The Coach, Fixed

- Every request to the AI provider now repeats the assistant's tool request before the tool results, as both the OpenAI and Anthropic formats require. Previously the second request of any tool conversation could be rejected.
- A tool request whose options cannot be read is reported back to the model as an error instead of being run with empty options, which used to create pages with default names.
- The Coach reads and writes the current page format, so pages it creates show up in the Database screen, and notes it adds are kept.
- The Coach can create container pages and exercise pages; these were missing from its tool list.
- Workouts the Coach builds appear in the Workouts screen immediately instead of after a relaunch.
- Replies can be longer (the limit rose from 1,024 to 4,096 tokens), and the Coach is told the conventions through the same guidance text external agents receive from the overview tool.
- After the allowed number of tool rounds the Coach is asked for a closing message with tools disabled, so it always ends with text.
- The Coach asks for the person's approval only before deleting a page or a workout. Creating, editing, and moving run immediately, and the Coach is told so in its guidance.

## Data Files

- The data root's agent folder holds the connection file and socket while the app runs, plus a journal of agent batches used for undo. The folder and socket are private to the user.
- The library's AGENTS.md and agent skill text now describe the tmax command. Older generated copies that still describe the retired tool are upgraded automatically; a copy the person edited is left alone.
- The generated schema file lists the tools from the shared catalog and carries a new schema version.

## Retired

The old Swift command-line tool and its tests are removed. The Coach's former private tool router is removed. F09-C and F09-D describe the earlier design and are superseded by this feature for everything about tools; their history is kept.

## Dependencies

- F09-A, F09-B — the data root, page library, and knowledge folder the tools operate on
- F14 — the container/leaf page model the tools create and read
- F09-D — superseded for tool behavior; the Coach loop it introduced is retained and corrected here
- F06 — the in-app Coach whose tool calls now use this catalog

## Reference

- `genesis/REFERENCE/` — no external reference; the Model Context Protocol and the OpenAI and Anthropic tool-calling formats were followed as published, as patterns to learn from

## Files

- `TimeMasterCore/Sources/Agent/` — the shared catalog, argument checking, page lookup, the tool implementations, batch and rollback, and the provider wire formats
- `TimeMaster/Agent/` — the app-owned execution path, the Mac bridge and approval prompt, access levels, the undo journal, settings tools, the video importer, and the command installer
- `TimeMaster/Views/Settings/ImportedSettings/AgentAccessSettingsView.swift` — the settings page
- `tmax-cli/` — the Rust command and MCP server
- `TimeMaster/ViewModels/AIStore.swift`, `AIProvider.swift` — the Coach loop and provider tool lists
