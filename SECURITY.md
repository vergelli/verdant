# Security

Verdant is a UI addon. It runs inside the game's sandboxed Lua, reads combat events and writes to its own SavedVariables file. It makes no network calls and has no dependencies.

If you find something that lets the addon read or write beyond that, or a way to make it misbehave through crafted game data, open an issue describing what you saw, or message @vergelli in game if you would rather not post it. Fixes are best-effort, like the rest of the project.
