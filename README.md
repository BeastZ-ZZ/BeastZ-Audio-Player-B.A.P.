# BeastZ Audio Player — BeamMP Server Plugin

The server-side plugin for **BeastZ Audio Player (B.A.P.)**, a customizable
in-car music player for BeamNG.drive. This plugin lets nearby players in a
BeamMP session hear each other's music as positional 3D audio coming from
their vehicle.

The client mod (the in-game UI, playlists, EQ, etc.) is distributed
separately through the BeamNG Resources listing. This repo is just the
server relay — it's what a BeamMP server owner installs to enable
multiplayer audio for their players.

## What it does

- Relays short "now playing" pings between clients so everyone can hear
  each other's music, positioned at the sending player's vehicle.
- Holds **no playback state** of its own — every message is validated and
  immediately fanned out to other synced players. The plugin does not
  store, log, or retransmit any audio file; only track/position metadata
  is relayed, and clients skip playback silently if they don't have the
  referenced file locally.
- Validates and rate-limits incoming events (fixed payload size cap,
  10 events/sec per connection) to keep a malformed or abusive client from
  spamming the relay.

## Requirements

- A running [BeamMP](https://beammp.com/) server.
- The BeastZ Audio Player **client** mod installed in the server's
  `Resources/Client/` folder, so every connecting player has the same
  music files at the same paths. Music itself is never transmitted over
  the network — only playback state (which track, position, volume) is
  relayed, so mismatched libraries just mean a listener skips playback
  silently rather than erroring.

## Installation

1. Copy the `BAP/` folder from this repo into your BeamMP server's
   `Resources/Server/` directory.
2. Make sure the client mod is present in `Resources/Client/` so joining
   players download the matching music pack.
3. Restart the BeamMP server.
4. Check the server console — you should see:
   ```
   [BAP v1.0] starting
   [BAP] ready, relaying 'bap' events
   ```

Expected layout on the server:

```text
Resources/
├── Client/
│   └── BAP.zip
└── Server/
    └── BAP/
        └── main.lua
```

## Troubleshooting

- **No "ready, relaying" message on startup** — confirm the folder is
  named `BAP` and sits directly under `Resources/Server/` (not nested
  inside an extra folder).
- **Players can't hear each other's music** — confirm every client has
  the same client mod / music pack installed via `Resources/Client/`, and
  that both players are actually synced (check the server console for
  `player <id> synced` on join).
- **Only local music is audible** — this plugin only relays playback
  state; make sure it's actually loaded (see startup message above) and
  that the client mod's multiplayer feature is enabled.

## License / usage

Please do not modify, redistribute, or repost this plugin without the
owner's permission.

---

Feedback and bug reports are welcome — please open an issue with server
console output and, if relevant, which client mod version you're running.
