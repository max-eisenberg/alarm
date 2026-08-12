# Don't Touch My Laptop

Open Terminal in this folder and run:

```bash
./alarm
```

That’s it. The first run opens the one permission you need. Turn on your terminal under **Input Monitoring**, quit and reopen Terminal, then run `./alarm` again.

The alarm never requests administrator access or a Terminal password. Closing the lid puts the Mac to sleep, so the alarm only operates while the lid is open.

## Pick a sound

```bash
./alarm goose
./alarm car
./alarm mother
./alarm meep
```

Available sounds: `scream`, `goose`, `car`, `villager`, `mother`, `meep`.

Want it extra sensitive?

```bash
./alarm goose feral
```

Sensitivity choices: `chill`, `balanced`, `feral`.

## What happens

1. Keep your hands off for three seconds while it arms.
2. Moving or touching the MacBook triggers the alarm.
3. Put it back in its original position and the noise stops; the MacBook stays armed.
4. Press **OWNER UNLOCK**, then use Touch ID or your Mac password to disarm.

When the alarm fires, it unmutes the current output and drives it at full volume. Your previous volume and mute settings are restored when the alarm stops.

Useful only if something looks wrong:

```bash
./alarm check
./alarm help
```

## Rebuild

```bash
./build.sh
```

Technical notes and security limitations are in [TECHNICAL.md](./TECHNICAL.md).
# alarm
