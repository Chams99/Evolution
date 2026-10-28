# Evolution

A live drop of pond water under a microscope, built with Flutter. Microbes hunt algae, swell as they feed, and divide in two. Their daughters inherit three traits (size, swimming speed and eyesight), each with a tiny random change. Every trait helps, and every trait costs energy. Nothing is scripted: every trend you see comes from which microbes manage to divide before they starve.

**[Open the live demo](https://chams99.github.io/Evolution/)**. It runs in the browser, with no install.

![A drop of pond water one minute in: stained microbes with flagella and red eyespots, algae, the field guide, and trait cards showing speed favoured and size selected against](docs/screenshot.png)

## What you are looking at

The view works like a microscope camera feed, with a live indicator, ×400 magnification and a 50 µm scale bar. Nothing else sits on top of it. The **field guide** at the top of the Learn tab explains every shape, drawn exactly as it appears in the drop:

- **A microbe** is a translucent cell. It swells and fills with granules as it eats.
- **Two nuclei** mean it is about to divide. When it does, you see it pinch in two.
- **Its tail (flagellum)** shows speed: longer and faster whipping means a quicker swimmer.
- **The red eyespot** shows sense: a bigger spot sees algae and danger from further away.
- **Colour is family.** Every founder cell has its own stain colour and passes it to all its descendants, so you can watch a few families take over the drop.
- **Algae** are the small green cells. They grow faster when the lamp is bright, and the lamp slowly brightens and dims.
- **Ghosts and bursts** show deaths: grey and shrivelled for starvation, a burst for a microbe engulfed by a predator.

A **caption** under the drop says what is happening in plain words, for example "4 divided and 32 died in the last 10 seconds. Smaller microbes are dividing most often right now". **Trait cards** under the controls show each trait's value, how far it has moved since the start, a trend line, and whether selection is pushing it up or down right now.

Every microbe also gets a made-up Latin name from its family and its traits, such as *Wiggula velox* (fast), *Glorbia magna oculata* (large and sharp-eyed) or *Smudgella fulminans* (lightning fast). Hover over the name to see what each word means.

## Learn by experiment

The **Learn** tab has five guided experiments. Each one sets up a sample, asks a question, tells you what to watch, tracks a live goal, and explains what happened once you have seen it:

| # | Lesson | The question |
| --- | --- | --- |
| 1 | Survival of the fastest | Algae go to whoever reaches them first. What happens to swimming speed? |
| 2 | Boom and bust | The lamp brightens and dims, and algae grow with it. Does the population just follow the light? |
| 3 | Arms race | Big microbes can engulf smaller ones. How do hunters and hunted respond? |
| 4 | No variation, no evolution | Every microbe is a perfect clone. Can anything evolve? |
| 5 | Bottleneck | A disaster wipes out most of the drop at random. What do the survivors pass on? |

Lessons run at 4× so generations pass quickly (the bottleneck lesson runs at 2× so you can aim the UV pulse). The **favoured** and **selected against** marks on the trait cards are a standardised selection differential: how far the parents of the last 30 seconds of births sit from the population mean. Progress is saved, and a short tour runs on the first visit.

## Test your own idea

The app opens on a choice: **test an idea**, follow the **guided experiments**, or **just watch** the drop. Testing an idea works like a real controlled experiment:

1. **Change one thing**: add predators, remove variation, speed up mutation, shorten lifespans, or double the algae.
2. **Predict** whether average size, speed or eyesight will end up higher, lower or about the same.
3. **Run both drops** side by side for 8 simulated minutes. Both start from the same seed, with the same founders in the same places, so your change is the only difference.
4. **Read the verdict**, worked out from the two drops' real averages, then **repeat with a new seed** to see whether it holds. Some changes win in every drop. Others flip from seed to seed, which is a result too.

The three strongest effects (predators raise size, no variation keeps speed low, faster mutation raises speed) are checked in the tests against seeds 1 to 3.

![An experiment after 8 simulated minutes: average size rising only in the drop with predators, the whole population shifting toward larger sizes, and a verdict confirming the prediction](docs/experiment.png)

## Run the lab

- **Inspect and pipette.** Tap a microbe to follow it: its species, energy, genome, divisions, and its whole living family, circled in the drop. Tap empty water to pipette in algae.
- **Cause disasters.** Fire a **UV pulse** to sterilise a circle of the drop, **drain** most of the algae, or **add** a fresh culture, then watch who recovers.
- **Follow the families.** The Families chart (a Muller plot) shows each founder's share of the drop over time, in the same colours as the cells.
- **Catch milestones.** New generations, population crashes, families dying out ("Only 3 families left", "One family has taken over the drop") and the fate of the microbe you are following pop up on the view.
- **Compare samples.** Four samples push selection in different directions (see below), and every parameter can be tuned. The same seed always replays the same run.
- **Control time.** Play at 1× to 16×, or step one simulated second at a time. Keyboard: `Space` plays or pauses, `→` steps, `R` restarts, `1` selects inspect and `2` the UV pulse.
- **Keep the data.** Copy the full history as CSV, with one row per simulated second.
- **Share a run or a lesson.** `?preset=predators&seed=3&at=240` opens the predator sample with seed 3, four minutes in. `?lesson=bottleneck` opens a lesson directly.

## The model

The world is 960 × 600 µm. On every tick, each microbe:

1. **Looks around** within its sense radius. If predation is on and something at least 1.3× its size is nearby, it turns away. Otherwise it turns toward the closest alga (or smaller microbe), or wanders.
2. **Swims** at its speed, turning at most 0.3 rad per tick.
3. **Pays energy**: `basal · size² + move · size² · speed² + sense · radius`.
4. **Divides in two** when its energy reaches `150 · size²`. The daughter takes half the energy and a copy of the genome with independent Gaussian mutations (7% standard deviation by default).
5. **Dies** when it runs out of energy, reaches its lifespan, is engulfed, or is caught in a UV pulse.

Cells below size 1 can only digest part of each alga. Without that rule, shrinking would always win. Algae appear at a rate that rises and falls with the lamp's sine-wave light cycle.

| Trait | Helps | Costs |
| --- | --- | --- |
| Size | Digests whole algae, stores more, can engulf microbes 1.3× smaller | Every movement costs more, and dividing needs more energy |
| Speed | Reaches algae first, outswims predators | Cost grows with the square of speed |
| Sense | Finds algae and threats from further away | A constant drain, proportional to radius |

### What the samples do

These results come from [`tool/balance.dart`](tool/balance.dart): 10 simulated minutes, seeds 1 to 3.

| Sample | Setup | Typical outcome |
| --- | --- | --- |
| Pond | Steady algae, gentle light cycle | Size stays near 1, speed and sense creep up |
| Drying puddle | Scarce algae, long dim spells | Numbers crash every cycle, speed stays low |
| Algae bloom | Algae everywhere | The largest populations, and the fastest rise in speed |
| Predators | Big microbes engulf small ones | Size, speed and eyesight escalate together |

![The Arms race lesson: large predatory microbes with big eyespots, and a live goal in the side panel](docs/lesson.png)

## Design

**One colour system**, defined in [`theme.dart`](lib/app/theme.dart), where every colour has a single job:

| Role | Colour | Used for |
| --- | --- | --- |
| Neutrals | warm ink, cream, muted greys | the interface, and the slide, which is warm ivory so the live view matches the panels |
| Accent | gold | buttons, selection and trait data, and nothing else |
| Alert | terracotta | deaths, crashes and the UV pulse |
| Life | one algae green | algae, on the slide and in the charts, and nothing else |
| Data | eight family stains | equal OKLCH lightness (0.57) and chroma (0.105), hues spread around the wheel with green skipped, so no family looks louder than another and none can be mistaken for algae |

Traits are told apart by icon and label rather than by competing colours.

**Rendered figures.** The microbes and algae are illustrations rendered by [`tool/render_sprites.py`](tool/render_sprites.py): brightfield-style cells with a dark membrane and a refractive rim, granular cytoplasm, a nucleus with its nucleolus, a contractile vacuole and food vacuoles holding eaten algae. Each cell has three states (hungry, fed, dividing), and algae come as single *Chlorella*-like cells, pairs and four-cell colonies. Bodies are rendered in greyscale and tinted with the family stain on the GPU. They are drawn with `Canvas.drawAtlas` from full-, half- and quarter-size sheets, whichever is closest to the on-screen size, so hundreds of cells stay smooth and fast.

**One icon everywhere.** The icon is the view itself: one stained microbe and a few algae on the slide, seen through the eyepiece. [`tool/render_icons.py`](tool/render_icons.py) draws it with the same cell and algae figures and writes every platform's set from it: an adaptive Android icon with a themed monochrome layer, iOS and macOS sets, a multi-size Windows icon, and the web favicon, touch and install icons. Sizes of 48 px and under get a simpler, bolder drawing so they stay readable. Launch screens on Android and iOS show the same lens on the dark background, so the app never flashes white while it starts.

## How it is built

```
lib/
  sim/            The simulation, in plain Dart with no Flutter imports
    world.dart        Rules: sensing, movement, metabolism, division, death, families
    genome.dart       Traits, limits and mutation
    spatial_grid.dart Bucket grid for neighbour queries
    rng.dart          Seeded random source, so every run can be replayed
    sample.dart       Per-second statistics and CSV export
  app/            The interface
    lab_controller.dart  Runs the world on a fixed timestep; tools, milestones, insight
    lessons.dart         The five guided experiments and their goals
    experiment.dart      Your own experiment: one change, a prediction, a control drop and the verdict
    microbes.dart        Family colours and Latin names
    lab_screen.dart      Side-by-side layout on wide screens, tabs on phones
    widgets/             Microscope view, field guide, charts, panels, lessons, tour
test/
  sim/            Determinism, bounds, food, division, predation, light cycle, disasters, selection, families
  app/            Every lesson completes with its seed; names; layouts at phone, tablet and desktop sizes
tool/
  balance.dart        Headless runner used to tune the energy model
  render_sprites.py   Renders the microbe and algae figures at three sizes
  render_icons.py     Renders the app icon, every platform's icon set and the launch images
  render_social.py    Composes the link-preview card from a screenshot
web/
  index.html          Loading screen with step-by-step progress, theme colour and link-preview tags
  flutter_bootstrap.js  Starts the app and reports each start-up step to the loading screen
```

The engine never imports Flutter, so the tests, the balance tool and the app all run exactly the same rules. The microscope view repaints from a `ValueNotifier` on every frame, and the charts redraw only when a new sample arrives, once per simulated second. Ten simulated minutes run headless in one to four seconds, depending on population size.

**Waiting is shown, never hidden.** The site is built to WebAssembly where the browser supports it (Chrome, Edge and Android), which downloads about 15% less than the JavaScript build that Firefox and Safari get. On a first visit the page shows a progress bar that follows the real start-up steps, and the microbe figures download alongside the engine, so the first frame already shows them. Repeat visits load from the browser cache and opened in about a quarter of a second in testing. In an experiment, *Finish now* runs the rest of the time a slice per frame, so the drops and the progress bar race ahead instead of the screen freezing.

## Run it locally

Requires Flutter 3.41 or newer.

```sh
flutter pub get
flutter run -d chrome        # or any connected device
flutter test
dart run tool/balance.dart   # optional: sample outcomes over 600 simulated seconds
```

## Credits

Space Grotesk, DM Sans and Space Mono are used under the SIL Open Font License. The licence texts are in [`assets/fonts`](assets/fonts).

Released under the [MIT License](LICENSE).
