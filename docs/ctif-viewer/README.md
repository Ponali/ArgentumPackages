# CTIF Viewer
This is a frontend that can open and view CTIF images using [libctif](../libctif/README.md).

libctif automatically renders ComputerCraft images with 2x the width. If you want to render the image without widening the width, use the `-o` flag or `--oc-char-ratio`.

If you would like to show the image in fullscreen (just like [asiekierka's OC implementation](https://github.com/ChenThread/ctif/blob/master/viewers/oc/ctifview.lua)), then use the `-f` flag or `--fullscreen` flag.

# Differences with OCIF
The CTIF image format uses custom color palettes to use with the GPU, which makes it impossible to have multiple CTIF images on-screen at once, thus the experience will be different than using `ocif show` with [OCIF Tools](../ocif-tools/README.md).

The custom palette also raises some issues with colors from the background and the image informations on Tier 2 screens. If you cannot use a tier 3 screen, then the only solution is to open the image in fullscreen.