# MCP: edits, not whole documents

**Status: planned.** Follows [programs-as-config](programs-as-config.md).

## The problem

The first real assistant session (Claude on the web, dev.schlift.com,
2026-11-23) took six minutes to switch a fresh account to a four-day
upper/lower split. Not the server: every write tool takes the **whole
program**.

| Tool | Text the assistant reads or writes |
|---|---|
| `get_program` (read) | 47 KB: the document, 76 built-in exercises included |
| `read_guide` (read) | 19 KB |
| `validate_program`, `simulate_program`, `set_program` (write) | the whole document, ~24 KB (~7,000 tokens), **each time** |

An assistant generates text far slower than it reads it. Validate, simulate,
set is the order the tools ask for, so one change was typed out three
times: ~20,000 tokens to change the workouts and three numbers.

## What changes

1. **Write tools take edits.** A list of small, named changes to the
   current program, applied by the core. The whole document stays possible
   for a full rewrite.
2. **The built-in exercises leave the document the assistant sees.** They
   are the same for everyone. `get_program` shows only the exercises the
   program adds or changes; `list_exercises` searches the built-in ones.
   A document sent without them gets them back.
3. **Helper tools** that answer what an assistant otherwise works out from
   the whole document: the exercise catalog, the workout library, the
   shape of one part of the program.
4. **`send_feedback`:** the assistant says, in 144 characters or less, what
   was easy or hard. The server keeps it and the admin page lists it.
5. **Client ID metadata documents (CIMD)** besides dynamic registration, so
   clients that prefer published identities (Claude's "Use Claude's
   published identity", ChatGPT) connect without registering.

The log does not change: `ProgramSet` still holds the whole document as it
was decided. Edits and the compact view exist only between the assistant
and the server; the core turns them into the full document before anything
is checked or recorded. Nothing an older app reads is new.

## Why edits, and why this shape

Assistants are poor at line-based text diffs (they miscount lines and
mangle context) and good at targeted, named changes: "set this field to
this", "replace this list". It is the shape of the edit tools coding
assistants use. Three rules make it reliable:

- **Address by name, not position.** An exercise is addressed by its `key`
  and a workout by its `id`, never `exercises[17]`: positions shift when
  something is added, and an assistant guessing an index is the commonest
  way such edits go wrong.
- **One path syntax, the validator's.** The validator already names
  problems as paths (`progressions.squat_lp.reps`). Edits use the same
  paths, and the validator's paths for exercises and workouts become
  name-based too (`exercises[zercher_squat].class`,
  `workouts[upper_a].exercises`), so an error points straight at the edit
  that fixes it.
- **All or nothing, and say which one failed.** The edits apply in order to
  a copy; if one cannot apply, none do and the error names its index and
  path.

## Edits

`validate_program`, `simulate_program` and `set_program` take either
`edits` (applied to the current program) or `program` (a whole document,
as now). Not both.

```json
{
  "edits": [
    { "set": "name", "value": "Hypertrophy Upper/Lower" },
    { "set": "classes.heavy.rep_low", "value": 6 },
    { "set": "classes.heavy.rest_seconds", "value": 150 },
    { "set": "workouts[upper_a]", "value": {
        "name": "Upper A", "rotation": true,
        "exercises": ["bench_press", "barbell_row", "lat_pulldown"] } },
    { "set": "workouts[a].rotation", "value": false },
    { "remove": "workouts[b]" },
    { "set": "progressions.squat_lp", "value": {
        "kind": "linear", "reps": 5, "increment_lb": 5,
        "deload_after_fails": 3, "deload_factor": 0.9 } },
    { "set": "exercises[squat].progression", "value": "squat_lp" }
  ],
  "note": "Upper/lower for size; squat on linear +5 lb."
}
```

### Paths

A path is dot-separated names, from the top of the document:

| Segment | Means | Example |
|---|---|---|
| `name` | an object's field | `sets.max`, `classes.heavy` |
| `list[key]` | the item of `exercises` with that `key`, or of `workouts` with that `id` | `exercises[zercher_squat]`, `workouts[upper_a].exercises` |
| `list[3]` | the item at that position, for the lists with no names (`time_off`, `warmups.ladder`, the plate lists) | `time_off[0].days` |

Map entries (`classes`, `progressions`, `recovery.hours`, `equipment`) are
fields: `progressions.squat_lp`.

### Operations

| Edit | Does |
|---|---|
| `{ "set": path, "value": v }` | Puts `v` at the path, replacing what is there. To change one field, point at the field (`workouts[a].rotation`), not the item. On a named item that doesn't exist, adds it at the end of its list; its key or id comes from the path, so `value` needn't repeat it. A new item's optional fields take their defaults (a workout's `notes` and `from_library` "", `rotation` true; an exercise's `short_name` its name, `progression` none, `description` ""). |
| `{ "remove": path }` | Takes it out: a named or numbered list item, or a map entry. Removing a required field applies, and the check that follows names it as missing; set it instead. |
| `{ "move": "workouts[upper_b]", "before": "workouts[lower_a]" }` | Reorders a named item; `"before": null` moves it to the end. Workouts' order is the person's, and the picker shows exercises in order. |

Every edit is checked as it applies (the path must exist, apart from the
last segment of a `set`; a value must have the field's type) and the result
is then validated as a whole document, as now. The response always says
what was applied: `"applied": 8`, and the result's `problems`.

`set_program` with edits records the full resulting document, author
`mcp:<client>`, exactly as if it had been sent whole.

## The compact view

- `get_program` returns the program with **only the exercises it adds or
  changes** (an exercise equal to the built-in one with its key is left
  out), and a line saying so:
  `"exercises_note": "76 built-in exercises not shown; list_exercises finds them. Use any key in workouts."`
  Expected on the default program: 47 KB down to a few KB (to be measured).
- A **whole document sent without some built-in exercises** gets them back
  by key before it is checked: built-ins in their built-in order, then the
  program's own. An exercise the document does list wins over the built-in
  one with that key. So an assistant may round-trip the compact view.
- Built-in exercises can't be removed (the app's picker and pictures assume
  them, and history names them); an edit that tries is refused.
- `get_earlier_program` returns the compact view too.

## Helper tools

| Tool | Gives |
|---|---|
| `list_exercises` | Exercises by `muscle`, `equipment`, `query` (name contains) or `keys`: key, name, equipment, muscles, class, the progression it follows, and whether it is built in. The program's own exercises included. Default 30, at most 100. |
| `list_library` | The workout library (`templates/library.yaml`): its workouts (id, name, exercises) and plans (a named set of workouts with a rotation), to copy with edits. |
| `get_program_part` | One path of the current program (`classes`, `progressions.squat_lp`, `workouts`), when the assistant only needs that. |

`read_guide` gains a short **Editing** section at the top (paths,
operations, one worked example) before the reference, and the connect
instructions change to: read the guide, look with `get_profile` and
`get_program`, change it with **edits**, `simulate_program` with the same
edits, `set_program` with the same edits and a note, then `send_feedback`.

## Feedback

```json
{ "name": "send_feedback",
  "arguments": { "text": "Edits worked first time; I couldn't tell which exercises need a barbell.", "tool": "list_exercises" } }
```

- `text`: 1 to 144 characters, required. `tool`: optional, the tool it is
  about. Anything longer is refused with the limit, so the assistant
  shortens it rather than having it cut.
- The connect instructions ask for one at the end of a task: what was easy,
  what was hard, what was missing. Never about the person.
- **Storage follows authority**: it is server-owned telemetry, so plain
  columns in a new table, not account events:

  ```sql
  CREATE TABLE assistant_feedback (
      id INTEGER PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      client_name TEXT NOT NULL,   -- as the client registered ("Claude")
      tool TEXT NOT NULL DEFAULT '',
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL
  );
  ```

  A new step in `src/db/migrate.rs`. At most 20 a day per user; past that
  the tool says thanks and keeps nothing.
- **Admin:** `AdminService.ListAssistantFeedback` (newest first, by client
  and tool) and an *Assistant feedback* section on the admin page: when,
  client, tool, text. No username: what's asked is how the tools work, not
  who said it.

## CIMD

The MCP authorization spec lets a client's `client_id` be an `https://` URL
serving its metadata (name, redirect URIs) instead of registering first.

- Authorization-server metadata advertises
  `"client_id_metadata_document_supported": true`.
- At `/connect` and the token endpoint, a `client_id` that is an `https://`
  URL is fetched (5 s timeout, 64 KB cap, cached an hour; only public
  hosts, no redirects to private addresses), must be JSON whose
  `client_id` is that same URL, and its `redirect_uris` must include the
  one asked for. Its `client_name` is what the consent page shows, with
  the URL's host beside it.
- Grants and tokens are keyed by the URL as by a registered id, so a
  person sees one "Claude" whichever way it connected.
- Registration (DCR) stays: Codex and many others use it.

## Not in this change

- Edits from the app: the app's template editor already records
  `ProgramEdited` operations of its own.
- Streaming tool results, and server-sent events on `/api/mcp`.
- Any change to what is stored in the log.
