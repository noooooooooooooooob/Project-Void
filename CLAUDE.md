# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

"Project Void" is a Godot 4.7 project (Forward Plus renderer, Jolt Physics for 3D, `d3d12` rendering driver on Windows). It is an early-stage scaffold: there is no gameplay code yet beyond `Scripts/new_script.gd`, which is still Godot's unmodified default template. Treat anything under `Scripts/` as a starting point, not an established pattern to follow.

There is no build system, linter, or test suite configured — this is a GDScript/Godot project, not a compiled one. "Running" the project means opening/running it in the Godot editor (see MCP tools below).

## Godot MCP bridge (the addons/ directory)

The three plugins under `addons/` are not gameplay code — together they form a bridge that lets an AI agent (this session, via the `mcp__godot__*` tools) drive the Godot editor and a running game instance directly. Understanding this wiring matters before editing anything under `addons/`:

- **`godot_mcp_editor`** (`plugin.gd`) — an `EditorPlugin` that opens a WebSocket client (`mcp_client.gd`, default `ws://127.0.0.1:6505/godot`, overridable via `GODOT_BRIDGE_PORT`/`MCP_BRIDGE_PORT`/`GOPEAK_BRIDGE_PORT` env vars) to an external MCP server. Incoming `tool_invoke` messages are dispatched by `tool_executor.gd`, which routes each tool name through a static `_tool_map` to one of three handler scripts in `tools/`: `scene_tools.gd` (nodes, scenes, signals, sprites), `resource_tools.gd` (resources, materials, shaders, tilesets, theme), `animation_tools.gd` (animations, animation trees, navigation). Results go back over the socket as `tool_result` messages.
- **`godot_mcp_runtime`** (`godot_mcp_runtime.gd`, autoloaded as `MCPRuntime` in `project.godot`) — runs *inside the playing game*, not the editor. It opens a raw TCP server on port `7777` and answers JSON commands: `get_tree`/`get_node`/`set_property`/`call_method` for live scene inspection and mutation, `capture_screenshot`/`capture_viewport`, `inject_action`/`inject_key`/`inject_mouse_click`/`inject_mouse_motion` for synthetic input, and `watch_signal`/`unwatch_signal`. All values are (de)serialized through `_serialize_value`/`_deserialize_value` (Vector2/3, Color, NodePath, Resource, etc. become tagged dicts with a `_type` key).
- **`auto_reload`** (`auto_reload.gd`) — polls open `.tscn`/`.scn`/`.gd`/`.tres`/`.res` files' mtimes every 1s and force-reloads them in the editor when changed externally, without the usual confirmation popup. This exists because the MCP tools above write files directly to disk outside the editor's own save flow — without it, edits made through MCP tools (or by Claude editing files directly) won't show up in an already-open editor scene/script.

When making scene/resource/animation changes, prefer the corresponding `mcp__godot__*` tool (which round-trips through this bridge and mutates live editor state) over hand-editing `.tscn`/`.tres` files, unless the editor isn't running or the tool doesn't cover the case.

## Code style

Existing GDScript (in `addons/`) uses typed GDScript throughout: explicit `-> ReturnType` on functions, typed `var` declarations, `class_name` for reusable classes, and `@tool` on editor-side scripts. Follow this style for any new GDScript.
