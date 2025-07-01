# libocif
This is a library, meant to run on Halyde, that can read and decode files with the OCIF container and its most used codecs, and then set its own pixels, put the image onto the screen, and convert it into ANSI art.

This is a library: If you're looking for a frontend to use this library on, check [OCIF Tools](../ocif-tools/README.md).

## Compatibility
Dimming characters with alpha values that are strictly between 0 and 1 is supported when showing images on the screen.

Currently Supported codecs:

- [x] 5 (raw)
- [x] 6 (complex)
- [x] 7 (complex)
- [x] 8 (complex)

ANSI output uses 24-bit color, which as of right now, [isn't supported by Halyde](../ocif-tools/README.md#problems-with-ansi-compatibility).

## Usage
Importing: `local ocif = import("ocif")`

---

`ocif.new(width: number, height: number): table`

Returns a new empty [Image table](#image-table).


`ocif.load(filePath: string): table`

Returns an [Image table](#image-table) based on the file path of the image given.

### Image table
`image.ocif`: Information about the OCIF format used.

&nbsp;&nbsp;`image.ocif.codec`: Codec used by the image file.


`image.width`: Width of the image.

`image.height`: Height of the image.

`image.data`: Raw data of the image.

---

`image:set(x: number, y: number, char: string, [foreground: number, background: number, alpha: number])`

Set a specific character into the image.

`x`: X position, in range `[1,width]`

`y`: Y position, in range `[1,height]`

`char`: Character to put on the image.

`foreground`: Foreground color, in the GPU color format (24-bit)

`background`: Background color, in the GPU color format (24-bit)

`alpha`: Alpha value of the character's background (0 is transparent, 1 is opaque)

---

`image:show(x: number, y: number)`

Shows the image onto the screen.

`x`: X position, in range `[1,width]`

`y`: Y position, in range `[1,height]`

---

`image:toansi(): string`

Converts the image into an ANSI string. [May not be rendered properly inside Halyde.](../ocif-tools/README.md#problems-with-ansi-compatibility)