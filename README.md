# Media Gallery

A fullscreen picture and video gallery for your own files, with a rhythm-game beat bar, an AI censor, and editors for beats, lights and censor areas. Everything runs on your own PC.

## Run it

1. Put your pictures and videos in the `images` folder. Subfolders are fine, for example `images/Trips/2024/`.
2. Double-click **`update-gallery.bat`**.

The bat file checks that everything the gallery needs is there, scans `images`, and opens the gallery in your browser. Run it again whenever you add files.

Each copy of the gallery gets its own port, so two copies on one PC never show each other's files. The first copy normally uses http://localhost:8080.

You can also use **Open folder…** in the top bar to show any folder on your PC without copying it.

The first time you open the page a short tour shows you around. Press the **?** button to see it again.

## Needs

- Windows with PowerShell (built in).
- Chrome or Edge.
- Internet the first time, to download the AI models. Your browser keeps them after that.

## Gallery

- Click a thumbnail to show it in the centre. Videos play with sound.
- **Auto** steps through everything on a timer. **Shuffle** mixes the order.
- **Face zoom** slowly zooms in on faces.
- Click the centre picture to zoom in, scroll to zoom further, and move the mouse to look around.
- **Float video…** plays a video in a window you can move and resize.
- Turn folders on or off in **Settings → Folders**.

## Beat bar and music

The beat bar starts off. Turn it on with the **Beat bar** button or **B**. Hit each circle as it reaches the box in the middle: press **J** or **K** or click the bar. Without music it runs a practice pattern.

**Music…** plays your own songs. Each song is scanned for its beat, and the circles land on it.

**Beat editor**: open it from the music player to place your own circles for a song. Your beats are used instead of the automatic ones.

## Red Light Green Light

**🔴🟢 Light** starts the game. While a video plays, the **light editor** button on the video lets you set exactly when it is green or red.

## Censor

**Censor** covers detected areas with a mosaic or another style. In **Settings → Censor** you can choose:

- what to cover: body parts, or the **whole body**
- accuracy: the Fast, Accurate and Best options guess from body pose, so they can miss areas. **Precise** uses a nudity detector and is much more accurate (see `models/README.txt`). You'll get a warning if you turn the censor on without it.
- style, shape, size, and text on top

**Censor editor**: the button on a picture lets you draw your own censor areas. They are used instead of the auto censor for that picture.

**Lock**: in **Settings → Censor → Lock**, lock the censor on with a PIN, a timer, or both. While it is locked, the censor can't be turned off and its settings can't be changed.

## Where things are saved

| What | Where |
| --- | --- |
| Your pictures and videos | `images/` |
| Custom beats, lights and censor areas | `images/.gallery-data/` |
| The list of your files | `private/` (made by the bat file) |
| Settings | Your browser |

`images/`, `private/` and downloaded models are in `.gitignore`, so they are never committed.

## Keys

| Key | Action |
| --- | --- |
| → or Space | Next |
| ← | Previous |
| A | Auto on / off |
| S | Shuffle |
| F | Face zoom on / off |
| B | Beat bar on / off |
| J or K | Hit a circle |
| M | Play / pause your music |
| Esc | Close Settings |

## Credits

Pose and body detection: Google MediaPipe. Nudity detector: NudeNet (https://github.com/notAI-tech/NudeNet, AGPL-3.0).
