# Ouroboros Hub

All scripts in one place. One loader for every supported game.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/joustingmatch/Ouroboros/main/loader.lua"))()
```

The loader detects the game (by `game.CreatorId`) and runs the matching script from `games/`.

## Adding a game

1. Drop the script in `games/<game-name>.lua`
2. Add one line to the `games` table in `loader.lua`

## Notes

- `games/utd-x.lua` (Universal Tower Defense X) is not wired into the loader; run it directly.
- UI libraries live in their own repos: [Midwest](https://github.com/joustingmatch/Midwest), [MacSlop](https://github.com/joustingmatch/MacSlop), [ObsidiaN](https://github.com/joustingmatch/ObsidiaN).
