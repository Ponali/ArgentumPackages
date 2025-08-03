# libctif
This is a library that can load images in the [CTIF format](https://github.com/ChenThread/ctif). It can also let you change the image data, make new images, and save them onto a drive.

If you would like a frontend for viewing CTIF images, check [CTIF Viewer](../ctif-viewer/README.md).

## Compatibility
Here is a list of all image modes that are supported and have been tested:

- [x] OpenComputers Tier 3 GPU
- [x] OpenComputers Tier 2 GPU
- [x] ComputerCraft default palette (2x3)
- [x] ComputerCraft custom palette (2x3)
- [ ] ComputerCraft default palette (1x1)
- [ ] ComputerCraft custom palette (1x1)

Any method generally works fine when reading images, but writing images has only been tested with OC Tier 3.

Modes with 1x1 characters couldn't get tested, because no methods of generating images in 1x1 were found yet.

When making an image, please keep in mind that this library will not make a palette for you.

## Usage
Importing: `local ctif = import("ctif")`

---

`ctif.new(width: number, height: number, [bitDepth: number, charWidth: number, charHeight: number, platformId: number, palette: table])`

&nbsp;&nbsp;`bitDepth`: Number of bits to store a color. Defaults to your GPU's current color depth. See [Color and Bit Depth](#color-and-bit-depth).

&nbsp;&nbsp;`charWidth`, `charHeight`: The resolution of a character. Only 2x3 and 2x4 are supported. Defaults to 2x4.

&nbsp;&nbsp;`platformId`: The ID of the targetted image platform. See [Platform ID](#platform-ids).

&nbsp;&nbsp;`palette`: A table of colors, in [24-bit RGB](https://ocdoc.cil.li/component:gpu#rgb_color), that represent the ideal palette the image will have. Defaults to an empty table.

Returns an empty [Image table](#image-table).


`ctif.load(filePath: string)`

Returns an [Image table](#image-table), with the contents of the image from the file path.

`ctif.CCWide: boolean`

Boolean value that can be changed to indicate whether to render ComputerCraft images with double the width or not (see [Internal and rendered positions](#internal-and-rendered-positions)). Defaults to `true`.

### Image table

`image.ctif`: Information specific to the CTIF format.

&nbsp;&nbsp;`image.ctif.platformId`: The [platform ID](#platform-ids) of the image.

&nbsp;&nbsp;`image.ctif.charWidth`, `charHeight`: the resolution of a character in the image.

&nbsp;&nbsp;`image.ctif.renderCharWidth`, `image.ctif.renderCharHeight`: The resolution, in characters, to render an internal character from the image. (see [Internal and rendered positions](#internal-and-rendered-positions))

&nbsp;&nbsp;`image.renderWidth`, `image.renderHeight`: The resolution of the image, when rendered to the screen.

`width`, `height`: The resolution of the image internally.

`bitDepth`: The bit depth of every color in the image. See [Color and Bit Depth](#color-and-bit-depth).

---

`image:setPalette()`

Initiates the custom color palette of the image to the GPU.

---

`image:show([x: number, y: number, width: number, height: number, keepPalette: boolean, dx: number, dy: number])`

Shows the entire image, or a part of it, onto the screen.
If no arguments are passed, the image will show up in the top left corner of the screen.

`x`, `y`: The position of the image, in screen characters.

`width`, `height`: The width and height to crop the image to.

`keepPalette`: If the current palette should be kept. Set this to `true` if you are showing the image multiple times, as setting the palette over and over will decrease performance.

`dx`, `dy`: How much to crop left, and how much to crop top.

---

`image:getChar(x: number, y: number)`

Returns a character from the image from an [internal position](#internal-and-rendered-positions).

---

`image:setChar(x: number, y: number, chr: string, fg: number, bg: number, [isPaletteIndex: boolean])`

Set a character from the image from an [internal position](#internal-and-rendered-positions).

---

`image:get(x: number, y: number)`

Get a character from the image from a [rendered position](#internal-and-rendered-positions).

---

`image:save([filename: string])`

Saves the image into a file, or returns the binary content as a string.

---

### Platform IDs
This is a number that represent the platform the image is meant to be rendered to.

Here is a list of platform IDs used for every platform:

- `1`: OpenComputers
- `2`: ComputerCraft

### Internal and rendered positions

If you are only working with images meant for OpenComputers, you should not worry about differences between both.

When rendering images for ComputerCraft, the image will render with 2x the width, so that it looks more correct. The `width` and `height` values in the image table does not account for this, but `renderWidth` and `renderHeight` does.

If you would like to stop stretching the width of the image, set `ctif.CCWide` to `false`.

### Color and Bit Depth

When making an image using this library, the bit depth can decide how much colors your image will have. The CTIF supports bit depths of 4bpp or 8bpp.

The first 16 colors can be a custom palette that you specify. If no palette is specified, or your palette has less than 16 colors, then the remaining colors will be used by a default palette when rendered. For an OpenComputers image, it will use this algorithm: `(i*15)<<16 | (i*15)<<8 | (i*15)`. For a ComputerCraft image, it will use [this palette](https://wiki.computercraft.cc/Colours_API).

If the bit depth is set to 8bpp, then 240 extra colors will be available. These colors are made using this algorithm: `floor((j%5)*255/4)<<16 | floor((floor(j/5)%8)*255/7)<<8 | floor((floor(j/40)%6)*255/5)`, where `j` is the color index minus 16.