 Editor / interaction expansions

  - Align & distribute for multi-selection (left/right/top/bottom/center, equal H/V spacing). Pure Math on
  _drag_batch_starts-style snapshots — fits naturally next to _group_selection.
  - Per-item lock (no move / no edit / no delete) on BoardItem, with an inspector toggle. Avoids the classic "I
  dragged the background frame" mistake.
  - Z-order controls — bring forward / send back / to front / to back. Currently _apply_group_render_order only
  enforces groups-behind; users have no manual control.
  - Connection waypoints + obstacle-aware orthogonal routing. The orthogonal style exists but probably draws
  straight elbows; routing around node rects would make diagrams legible.
  - Multi-select connections + bulk style edit (color/thickness/style). Right now _selected_connection_id is single.
  - Snap toggles & customization UI — SnapService exists as autoload but I didn't see exposed grid-size /
  snap-to-item toggles in the toolbar.

  Node-type expansions

  - TodoList: due dates, priority, completed-strikethrough; plus a project-wide "all open todos" aggregator board.
  - Timer: global timer tray (running timers across boards), sound on expiry (you already have SoundNode infra), and
   pause/resume on history undo (or explicitly excluded — pick one).
  - RichText: inline links to other items/boards (re-use LinkPicker) so prose can cross-reference the canvas.
  - Image: crop + simple filters; paste-from-clipboard insert (very common in mind-mappers).
  - New types worth considering: web-bookmark/URL card with favicon, code block (syntax-highlighted), table,
  equation/LaTeX, sticky-note variant of Text with preset colors.

  Project / persistence

  - Autosave indicator + dirty state in toolbar. The 0.5s debounce save is invisible to the user.
  - Project-level snapshots / version history beyond per-board undo. A "checkpoints" folder of board JSON,
  timestamped — undo dies on board switch (History.clear() in navigate_to_board), so right now there's no way to
  recover past state.
  - Import (Markdown outline → text nodes; JSON; FreeMind/XMind if you're feeling ambitious) and export beyond PNG
  (SVG vector, PDF, Markdown outline of board, static interactive HTML using the unfolded data).
  - Templates / stencils palette — save a selection as a reusable group template, drag from a side panel.

  Smaller but high-quality-of-life

  - Presentation mode — follow links/connections one item at a time, fullscreen, with arrow keys.
  - Tags + tag filter — color-coded tags on items; dim non-matching items.
  - Customizable keybindings (the hardcoded _unhandled_input block is the obvious target for a remap layer).
  - Theming — light/dark/custom accent, and per-board background color/image.

  Multiplayer (Steam-backed collaboration with co-author replicas)

  Goal: let a project owner invite friends through Steam to collaborate on a project. Two roles:

  - Guest — session-scoped. Can only act while the inviter (or any co-author) is hosting a live session. Sees the
  board, may be granted view-only or edit rights for that session. Holds no local copy of the project.
  - Co-author — persistent peer. Has their own complete on-disk replica of the project, can open and edit it any
  time independently of who else is online, can host sessions of their own, and can be joined by the owner or
  other co-authors as guests/co-authors of that session. All co-authors (including the owner) are equal editors;
  the owner's only privilege is admin (managing the participant list).

  No hard cap on participants — Steam lobbies allow up to 250 members; the practical soft-cap is on simultaneous
  active editors per session (target ~16) since every editor multiplies presence + op traffic.

  Transport & lobby layer

  - Add the GodotSteam addon (or godotsteam_multiplayer_peer for the MultiplayerAPI integration). Wrap it behind a
  NetworkAdapter interface so the rest of the codebase never imports Steam types directly — leaves room for a
  future ENet/local-LAN adapter and keeps tests possible without Steam running.
  - SteamLobbyService autoload: create/join/leave lobby, set lobby metadata (project_id, project_name,
  format_version, session_host_steam_id), enumerate members, fire invite dialog (Steamworks overlay invite),
  accept the +connect_lobby launch arg.
  - Lobby visibility: friends-only (default), invite-only, private. Co-authors join via persistent membership in
  the project manifest (no per-session invite needed); guests are session-scoped invites only.
  - Co-author discovery: each co-author's client publishes a Steam Rich Presence string when hosting a project
  ("Hosting <project>"), and the project's local manifest tracks each co-author's last-known steam_id so the
  client can list "who's currently hosting this project among my co-authors" without a central server.

  Session architecture (peer replicas, eventually consistent)

  - Every co-author (including the owner) has a full local copy of the project on disk: project.json, boards/,
  assets/, plus a new oplog/ folder. Editing offline is just normal local editing — no networking required, no
  degraded mode. The replica is the project; "hosting" is just opening it for others to join in real time.
  - When co-author A invites co-author B (or B joins A's hosted session via Steam), A is the session host for
  that session — meaning A coordinates op ordering and broadcasts to all connected peers. The session host role
  is per-session and per-lobby; it has no special authority over the project itself, only over the live ordering
  loop.
  - A new MultiplayerService autoload coordinates: session lifecycle, role gating, op routing, presence
  broadcast, asset transfer, sync/merge on connect. Sits next to the existing autoloads (selection_bus,
  project_index, snap_service, user_prefs, alignment_guide_service).
  - Operation-based sync, not snapshot diffing. Every mutation that today goes through History/PropertyBinder is
  refactored to flow through an OpBus that produces ops of the form: { op_id, author_steam_id, board_id, kind,
  payload, lamport_ts, vector_clock }. Ops are appended to a per-board oplog/<board_id>.log on disk so that
  offline edits survive restarts and can be replayed/exchanged on next connect.
  - During a live session: peers stream new ops to the session host, who applies a Lamport-timestamp total order
  and rebroadcasts. Local clients apply optimistically and reorder if the host's accepted order differs.
  - On connect (sync handshake): peers exchange vector clocks per board. Whoever is ahead streams the missing op
  range from their oplog; the receiving peer applies + merges using the conflict rules below. Boards never seen
  by a peer are streamed in full (Board.to_dict() + relevant oplog tail) lazily on first navigation.
  - Op kinds map 1:1 to existing commands: create_item, delete_item, move_items, set_property,
  create_connection, delete_connection, create_board, rename_board, reparent_board, delete_board.

  Permissions model

  - Extend project.json with a participants block: { steam_id: { role: "owner" | "co_author", display_name,
  added_unix, public_key } }. Owner role is implicit for the local user when they create the project. The owner
  signs the manifest with their key; co-author additions/removals are owner-signed entries that propagate
  through the same op-sync mechanism (see Trust below).
  - Per-session role for non-co-authors: anyone in the lobby not in the manifest is a guest. The session host
  may run guests as read-only, comment-only, or edit (per-session policy). Guests' edits are normal ops authored
  under their steam_id but tagged ephemeral_guest so other co-authors can choose to drop them on merge if a
  co-author later objects (rare; useful escape hatch).
  - Owner-only admin operations: add/remove co-authors, rename project, change default guest policy, transfer
  ownership. These are special manifest ops that only verify if signed by the current owner's key.
  - Once added, a co-author has full editing parity — including the right to host sessions, invite guests, and
  make any structural change. Removing a co-author revokes their right to be admitted to future sessions but
  does not (and cannot) revoke the local replica they already hold; their fork simply diverges.

  Presence & UX

  - Per-peer cursor (world-space mouse position) and selection rectangle, color-coded by a deterministic hash of
  steam_id. Drawn as a thin overlay layer above BoardItem nodes; throttled to ~20 Hz with delta encoding.
  - Per-peer viewport ghost (faint rectangle of what they're looking at) toggleable via toolbar. Useful for
  presentation/teaching modes.
  - Avatar strip in the toolbar showing Steam avatars + role badges (crown for owner, pencil for co-author, eye
  for guest, plus a "hosting" dot on whichever peer is currently the session host). Click to follow-camera.
  - Project list (start screen) shows each project with: local-only / shared / currently-hosted-by-X status, and
  a "join" button when a co-author is hosting it.
  - Editing locks (advisory, not enforced): when peer A starts text-editing a Text/RichText node, broadcast an
  editing_lock op; other peers see a soft lock badge and a "joining will overwrite their draft" warning if they
  try to edit. Locks expire on heartbeat timeout (5s) and are session-scoped only.
  - In-canvas comments / pings: shift-click to drop an ephemeral ping marker that fades over 3s.

  History, undo, and snapshots under collaboration

  - Per-user undo stacks: each peer's History only tracks ops authored by them. Undo emits an inverse op through
  the same OpBus rather than mutating local state directly. Solves the classic "I undid your work" problem and
  works identically online and offline.
  - Per-board, per-user history ring buffer (bounded, e.g. 200 ops). Replaces the current History.clear() on
  board switch — also fixes the standalone undo-dies-on-board-switch bug noted in Project / persistence.
  - Snapshots: each replica writes its own checkpoint into history/ every N ops / M minutes, independent of
  network state. On merge, snapshots are not synced — they're each peer's local rollback safety net.

  Asset sync

  - assets/ stays content-addressed by the existing UUID-derived asset_name. Each replica caches assets locally;
  the on-disk file is its own canonical copy.
  - When peer A references an asset_name peer B doesn't have, B requests it from any connected peer that does
  (preference: session host first, then any peer advertising it in their bloom-filter-style asset manifest).
  Streamed via chunked reliable P2P packets (Steam Networking Sockets, ~1 MB chunks).
  - Asset op flow: when a peer imports an image/sound, the import is a local copy_asset_into_project + a
  set_property op carrying the new asset_name. Other peers receive the op, see the unknown asset_name, and pull
  bytes on demand. No central upload step — fits the symmetric peer model.
  - Asset GC: assets unreferenced by any reachable item or oplog entry can be purged on a manual "clean unused
  assets" action. Avoid auto-GC during sessions to prevent races with newly-arriving ops that reference them.

  Conflict resolution (the core of offline editing)

  - Structural ops (create/delete item, create/delete connection, create/delete/reparent board): commute or
  resolve trivially under Lamport ordering. Two creates with different ids both succeed. Delete-vs-edit: delete
  wins, the loser's edits are dropped with a per-peer toast on next sync ("3 edits to deleted items by X were
  discarded").
  - Property edits (position, color, size, etc.): last-writer-wins per (item_id, property) keyed by Lamport
  timestamp + steam_id tiebreaker. Matches the granularity PropertyBinder already operates at.
  - Text/RichText body edits — the only place LWW is genuinely lossy in offline collaboration. Phase the work:
    - v1: LWW on whole-buffer commits at edit-end + a "diverged-text" marker. If two co-authors edited the same
    text node offline, the losing version is preserved as a ghost revision visible from a "history" popover on
    that node so nothing is silently lost. Crude but safe.
    - v2: per-text-node CRDT (Yjs-like or a compact home-grown sequence CRDT) for character-level merges, while
    structural ops keep their Lamport order. Stored as the node's payload format; backwards-compatible upgrade
    on first edit.
  - Reparent loops (e.g. A reparents B under C while C is concurrently reparented under B): detect the cycle on
  apply, reject the later op (Lamport order), surface a toast.
  - Manifest divergence (e.g. two co-authors concurrently rename the project): owner-signed manifest ops always
  win; co-author-authored manifest ops are advisory only and dropped if they conflict with an owner op.

  Trust & integrity

  - Each co-author has a long-lived keypair generated on first run and stored in user_prefs. The public key is
  included in the manifest participants entry the first time the owner adds them.
  - All ops are signed by the author's private key; receivers verify against the manifest before applying. Stops
  a removed co-author from injecting ops via a session host who hasn't yet seen the removal.
  - Manifest mutations (add/remove co-author, rename project) require the owner's signature, propagated through
  the same oplog mechanism so every replica converges on the same participant list.
  - Steam IDs alone are not used for authorization — the keypair is — because someone could spoof a steam_id
  claim through a malicious build. Steam handles transport and identity at the lobby level only.

  Failure modes

  - Session host disconnect: ops in flight may have been received by some peers and not others. On reconnect, the
  peer-pair sync handshake reconciles via vector clocks. If no peers reconnect, every editor still has the
  divergent state in their oplog and merges later when any two of them next meet.
  - Peer disconnect: drop their presence, release any editing locks they held (heartbeat-driven, 10s timeout).
  Their offline edits will sync on their next connection.
  - Concurrent hosting: if A and B are both hosting the same project to overlapping peers, the lobby metadata
  shows both; clients pick one to join (typically whichever was started first / has more peers). Ops still
  converge across both sub-sessions when peers cross-pollinate.
  - Desync detection within a live session: every K ops the session host broadcasts a board content hash; peers
  whose hash diverges trigger a board resync (re-stream the board JSON + recent oplog tail).

  Implementation phases

  1. Foundation: NetworkAdapter + SteamLobbyService + MultiplayerService scaffolding; invite/join/list members
  and a presence cursor as a smoke test, no state sync yet.
  2. Op pipeline: refactor every mutating call site to flow through OpBus, with each op appended to an on-disk
  oplog. All single-player. Verifies the refactor without networking.
  3. Live session sync: serialize ops over Steam, session host applies Lamport ordering + rebroadcasts. Initial
  board sync on join. Read-only guests work end-to-end.
  4. Co-author replicas + sync handshake: vector-clock-based catch-up on connect. Two co-authors can edit
  offline and merge on next session.
  5. Permissions, signed manifest, keypair-based op authentication.
  6. Asset streaming + editing locks + per-user undo + ghost-revision UI for text LWW losses.
  7. Polish: presence avatars, viewport ghosts, follow-camera, kick/promote flows, desync recovery, project
  list "who's hosting" indicator.
  8. v2 text CRDT for character-level merging of concurrent text edits.

  Out of scope for v1 (worth naming so they aren't accidentally promised)

  - Character-level concurrent text editing (covered by phase 8, not v1).
  - Non-Steam transports (Discord, direct IP). The NetworkAdapter abstraction keeps the door open.
  - Voice/text chat — Steam overlay covers it for free; revisit only if in-canvas chat becomes a real ask.
  - Granular per-board / per-item ACLs. v1 is project-level only: if you're a co-author you can edit anything.