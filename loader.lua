if not game:IsLoaded() then
    game.Loaded:Wait()
end

local BASE = 'https://raw.githubusercontent.com/joustingmatch/Ouroboros/main/games/'

local games = {
    [9190691]    = 'anime-squadron.lua',
    [896806231]  = 'axe-rng.lua',
    [759293173]  = 'reign-piece.lua',
    [973045631]  = 'anime-card-farm.lua',
    [104489519]  = 'defend-ur-base-with-anime.lua',
    [446405201]  = 'merge-a-nuke.lua',
    [5028964]    = 'saber-simulator.lua',
    [561990553]  = 'survive-zombie-arena.lua',
    [35906875]   = 'anime-story-2.lua',
    [33910482]   = 'anime-world-fighters.lua',
    [895955624]  = 'anime-rng.lua',
    [168519468]  = 'anime-astral-simulator.lua',
    [1006239440] = 'anime-battle-rng.lua',
    [572660282]  = 'anime-ultraon-simulator.lua',
    [2568838]    = 'tree-rng.lua',
    [15504927]   = 'launch-a-wheel.lua',
    [4651630]    = 'lineage-piece.lua',
    [2823500]    = 'untitled-melee-rng.lua',
    [889770537]  = 'farm-rng.lua',
    [432538536]  = 'grow-a-garden-2.lua',
    [10353739]   = 'loot-rng.lua',
    [654102831]  = 'bomb-fishing.lua',
    [32001182]   = 'merge-vs-mobs.lua',
    [719390069]  = 'lucky-block-rush.lua',
    [374857141]  = 'pickaxe-tycoon.lua',
    [15904375]   = 'rng-heroes.lua',
    [1105128955] = 'click-simulator.lua',
    [51129361]   = 'scale-slimy-fish.lua',
    [711432426]  = 'world-cup-manager.lua',
    [665060893]  = 'evomon.lua',
    [861213399]  = 'roll-to-defend.lua',
    [33724194] = 'anime-rng-defense.lua',
    [831907229] = 'spin-a-car.lua',
    [36093006] = 'animesouls.lua',
    [742438713] = 'rollanime.lua',
    [168012640] = 'becomeabillionaire.lua',
    [34492682] = 'chickenfarm.lua',
    [444132252] = 'hotsauce.lua',
    [431165110] = 'snowconestand.lua',
    [250961762] = 'beehive.lua',
    [287664347] = 'hackabussiness.lua',
    [744386991] = 'buildaslime.lua',
    [11603322] = 'buildapetfarm.lua',
    [1000628384] = 'makeadrillfarm.lua',
    [330064258] = 'growitrng.lua',
    [625498370] = 'animeshitseer.lua',
    [33896179] = 'missilesvscities.lua',
    [380415714] = 'throwacoin.lua',
    [177870152] = 'buildakeyboard.lua',
    [35666413] = 'beeremasters.lua',
    [532484073] = 'mydinofarm.lua',
    [9640154] = 'storagehunters.lua',
    [650517328] = 'rollananime.lua',
    [8309807] = 'scratchyloot.lua',
    [33290695] = 'bethefinalboss.lu',
    [540612760] = 'buildabaseandsteal',
    [657759819] = 'rollanimetofight.lua',
}

local file = games[game.CreatorId]
if file then
    task.wait(math.random())
    loadstring(game:HttpGet(BASE .. file))()
end
