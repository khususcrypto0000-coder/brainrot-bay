# brainrot-bay

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/khususcrypto0000-coder/brainrot-bay/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/khususcrypto0000-coder/brainrot-bay/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

A 3D brainrot-collecting game for make.fun's **"Make the best AI Roblox brainrot game"**
bounty (`roblox-brainrot-01`, $1,000 shared by the top 50).

## Run it

```sh
rojo build default.project.json --output game.rbxl
```

---

<sub>Entered on [make.fun](https://make.fun/?ref=452ydmv8&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>

---

## The game

Absurd meme creatures walk down a conveyor belt through a 3D world. Walk up
to one, press **E** to buy it, and it moves into your own base — where it earns
you money every second at its rate. Rarer brainrots cost more and earn more,
and a mutated one (Golden, Rainbow, Diamond, or the unlucky Cursed) multiplies
both. Climb the ladder from Noodle Cat to the Galactic Giraffe, then rebirth
for a permanent income bonus.

Watch your back: other players can steal brainrots out of your base while it
is unlocked, so lock it (or slap them away with **F**). Every three minutes a
tsunami wave sweeps the map — get to your base or get thrown back to spawn —
and a rare brainrot rides in on the wave.

## The cast

| Rarity | Brainrots | Income |
| --- | --- | --- |
| Common | Noodle Cat, Soggy Croissant | $2–5/s |
| Rare | DJ Pigeon, Turbo Toilet | $12–25/s |
| Epic | Captain Banana Shark, Professor Pickle | $55–120/s |
| Legendary | Sir Barksalot III, Quantum Toaster | $300–650/s |
| Mythic | The Grand Noodler, Galactic Giraffe | $1,800–5,000/s |

## Progression

- **Shop** (in-game button): Speed Boots (+2 walk speed/level), Golden Magnet
  (+10% income/level), Extra Base Slots (+2 slots/level).
- **Rebirth** (in-game button): once you have earned $50,000 in total, trade
  your cash, brainrots and upgrades for +25% income forever, per rebirth.
- **Base lock**: locks your base against stealing for 45 seconds (90s cooldown).
- **Slap** (button or **F**): shoves nearby rivals away from your brainrots.

## How to run the game

Open the place in Roblox Studio (`game.rbxl`, built with Rojo) and press Play,
or publish it as an experience and play it on Roblox.

## How to build the place

```sh
rojo build default.project.json --output game.rbxl
```

## How to hand it in

```sh
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` (Node 22, standard library only) copies `game.rbxl`, `src/`,
`screenshots/` and `PLAY.json` to `/output` and writes `/output/dossier.json`
with `vendor/makefun-roblox.ts`.

## Layout

- `src/shared/` — `Config.luau` (world layout and tuning) and `BrainrotData.luau`
  (the cast, rarities and mutations), shared by server and client.
- `src/server/` — `GameServer.server.luau` (the game loop: spawning, income,
  stealing, waves, shop, rebirth), `BrainrotFactory.luau` (builds the 3D
  character models) and `PlayerData.luau` (one player's session state).
- `src/client/` — `GameClient.client.luau` (HUD: cash, income, shop, lock,
  slap, event banner).
- `default.project.json` — the 3D world: conveyor belt, six player bases with
  slots, spawn, trees, lamps and a fountain.

## Status

The game is built and the place compiles with Rojo. Still to do on a PC with
Roblox Studio: publish the place as a Public experience, fill in `PLAY.json`
with its place and universe ids, take 3–4 screenshots of the game running in
Studio (one of them becomes the game's thumbnail on Roblox), and upload the
game's icon and thumbnail on the Creator Dashboard.

## License

MIT — see `LICENSE`.
