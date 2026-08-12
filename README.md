# 🚨 Don't Touch My Laptop 🚨

Turn your MacBook into a tiny, extremely dramatic security guard.

Someone touches it? **AAAAAAAAAA.**<br>
Someone picks it up? **HONK HONK, CRIMINAL.**<br>
It was you all along? Touch ID lets the laptop know the call is coming from inside the house.

> [!WARNING]
> This software may cause thieves, roommates, coworkers, and nearby geese to reconsider their choices.

## Release the beast

Open Terminal in this folder and run:

```bash
./alarm
```

That’s it. Your Mac is now emotionally prepared for betrayal.

The first run opens the one permission you need. Turn on your terminal under **Input Monitoring**, quit and reopen Terminal, then run `./alarm` again.

The alarm never requests administrator access or a Terminal password. Closing the lid puts the Mac to sleep, so the alarm only operates while the lid is open.

## Choose your fighter

```bash
./alarm goose
./alarm car
./alarm mother
./alarm meep
```

Available sounds: `scream`, `goose`, `car`, `villager`, `mother`, `meep`.

There are no good choices here. Only loud ones.

Want it to react like a chihuahua that just heard a leaf fall three streets away?

```bash
./alarm goose feral
```

Sensitivity choices:

- `chill` — “Hmm. Probably fine.”
- `balanced` — “Hey! Who did that?”
- `feral` — “THE TABLE MOVED. THIS IS NOT A DRILL.”

## The highly scientific process

1. Keep your hands off for three seconds while the laptop studies the vibes.
2. Moving or touching the MacBook triggers the alarm.
3. Put it back in its original position and the noise stops; the MacBook remains suspicious and armed.
4. Press **OWNER UNLOCK**, then use Touch ID or your Mac password to prove you are not three raccoons in a trench coat.

When the alarm fires, it unmutes the current output and drives it at full volume. Your previous volume and mute settings are restored when the alarm stops.

If the beast seems confused:

```bash
./alarm check
./alarm help
```

## Summon a fresh binary

```bash
./build.sh
```

Technical notes and security limitations are in [TECHNICAL.md](./TECHNICAL.md).

## Serious-ish disclaimer

This is an unprivileged process, not a force field. It cannot prevent a hard shutdown, reboot, recovery-mode access, or a determined wizard. Closing the lid also puts the Mac to sleep, at which point it dreams peacefully instead of guarding your stuff.

Use responsibly. Warn anyone with a beverage, a heart condition, or excellent hearing.
