# Evolution

A natural selection sandbox built with Flutter. A population of simple organisms inherits three traits (size, speed and sense), pays for them in energy, and adapts to the food supply, the seasons and, if you turn them on, predators. Nothing is scripted. Every trend in the charts comes from who survives long enough to reproduce.

**[Open the live demo](https://chams99.github.io/Evolution/)**. It runs in the browser, with no install.

![A dry season two and a half minutes in: energy rings, starvation marks, the field guide, a live caption and trait cards showing speed favoured and size selected against](docs/screenshot.png)

## Reading the field

Everything on the field is explained on the field itself. A **field guide** shows what each shape means, drawn exactly as it appears. A **caption** underneath says what is happening in plain words, for example "5 born and 32 died in the last 10 seconds. Faster organisms are leaving the most offspring right now". **Trait cards** under the field show each trait's value, how far it has moved since the start, and whether selection is pushing it up or down right now.

- **The ring around each body is its energy.** It fills as the organism eats, and when it closes the organism splits in two.
- **Colour and wake show speed.** Terracotta bodies are slow. Gold bodies with long wakes are fast.
- **Body size shows the size trait.**
- **Events are marked where they happen.** Births flash, a ✕ marks starvation, and a red burst marks a predator kill.

## Learn by experiment

The **Learn** tab has five guided experiments. Each one sets up a world, asks a question, tells you what to watch, tracks a live goal, and explains what happened once you have seen it:

| # | Lesson | The question |
| --- | --- | --- |
| 1 | Survival of the fastest | Food goes to whoever reaches it first. What happens to speed? |
| 2 | Boom and bust | Food comes and goes with the seasons. Does the population just follow it? |
| 3 | Arms race | Large organisms can eat smaller ones. How do hunters and hunted respond? |
| 4 | No variation, no evolution | Every organism is identical and children are exact copies. Can anything evolve? |
| 5 | Bottleneck | A catastrophe wipes out most of the population at random. What do the survivors pass on? |

Lessons run at 4× so generations pass quickly. The **favoured** and **selected against** marks on the trait cards are a standardised selection differential: how far the parents of the last 30 seconds of births sit from the population mean. Progress is saved, and a short tour runs on the first visit.

## Play with it

- **Inspect and feed.** Tap an organism to follow it: its energy, genome, offspring and kills, and its whole living family, ringed on the field. Tap empty ground to drop food.
- **Cause disasters.** Strike with a **meteor**, trigger a **famine**, or make **food rain**, then watch who recovers.
- **Watch the season.** The ground turns dry and warm when food is short, and green when it is plentiful.
- **Catch milestones.** New generations, population crashes, trait records and the fate of the organism you are following pop up on the field.
- **Compare environments.** Four presets push selection in different directions (see below), and every parameter can be tuned. The same seed always replays the same run.
- **Control time.** Play at 1× to 16×, or step one simulated second at a time. Keyboard: `Space` plays or pauses, `→` steps, `R` restarts, `1` selects the inspect tool and `2` the meteor.
- **Keep the data.** Copy the full history as CSV, with one row per simulated second.
- **Share a run or a lesson.** `?preset=hunters&seed=3&at=240` opens Hunters with seed 3, four minutes in. `?lesson=bottleneck` opens a lesson directly.

## The model

On every tick, each organism:

1. **Looks around** within its sense radius. If predation is on and something at least 1.3× its size is nearby, it turns away. Otherwise it turns toward the closest food (or smaller organism), or wanders.
2. **Moves** at its speed, turning at most 0.3 rad per tick.
3. **Pays energy**: `basal · size² + move · size² · speed² + sense · radius`.
4. **Splits in two** when its energy reaches `150 · size²`. The child takes half the energy and a copy of the genome with independent Gaussian mutations (7% standard deviation by default).
5. **Dies** when it runs out of energy, reaches its lifespan, or is eaten.

Bodies below size 1 can only digest part of each food item. Without that rule, shrinking would always win. Food appears at a rate that rises and falls with a sine-wave season.

| Trait | Helps | Costs |
| --- | --- | --- |
| Size | Digests whole meals, stores more, can eat organisms 1.3× smaller | Every movement costs more, and reproduction needs more energy |
| Speed | Reaches food first, outruns predators | Cost grows with the square of speed |
| Sense | Finds food and threats from further away | A constant drain, proportional to radius |

### What the presets do

These results come from [`tool/balance.dart`](tool/balance.dart): 10 simulated minutes, seeds 1 to 3.

| Preset | Setup | Typical outcome |
| --- | --- | --- |
| Temperate | Steady food, mild seasons | Size stays near 1, speed and sense creep up |
| Drought | Scarce food, harsh dry spells | Numbers crash every season, speed stays low |
| Bloom | Plenty of food | The largest populations, and the fastest rise in speed |
| Hunters | Predation on | Size, speed and sense escalate together |

![The Arms race lesson in progress: hunters with long wakes and a live goal in the side panel](docs/lesson.png)

## How it is built

```
lib/
  sim/            The simulation, in plain Dart with no Flutter imports
    world.dart        Rules: sensing, movement, metabolism, reproduction, death
    genome.dart       Traits, limits and mutation
    spatial_grid.dart Bucket grid for neighbour queries
    rng.dart          Seeded random source, so every run can be replayed
    sample.dart       Per-second statistics and CSV export
  app/            The interface
    lab_controller.dart  Runs the world on a fixed timestep; tools, milestones, insight
    lessons.dart         The five experiments and their goals
    lab_screen.dart      Side-by-side layout on wide screens, tabs on phones
    widgets/             Field and chart painters, overlays, panels, lessons, tour
test/
  sim/            Determinism, bounds, food, births, predation, seasons, disasters, selection, lineage
  app/            Every lesson completes with its seed; layouts at phone, tablet and desktop sizes
tool/balance.dart Headless runner used to tune the energy model
```

The engine never imports Flutter, so the tests, the balance tool and the app all run exactly the same rules. The UI repaints the field from a `ValueNotifier` on every frame, and redraws the charts only when a new sample arrives, once per simulated second. Ten simulated minutes run headless in one to four seconds, depending on population size.

## Run it locally

Requires Flutter 3.41 or newer.

```sh
flutter pub get
flutter run -d chrome        # or any connected device
flutter test
dart run tool/balance.dart   # optional: preset outcomes over 600 simulated seconds
```

## Credits

Space Grotesk, DM Sans and Space Mono are used under the SIL Open Font License. The licence texts are in [`assets/fonts`](assets/fonts).

Released under the [MIT License](LICENSE).
