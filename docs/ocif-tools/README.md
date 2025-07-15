# OCIF Tools
This package contains an application named `ocif` that allows you to take a MineOS `.pic` file and show it on the screen, or convert it into ANSI art.
This package can be installed by running `ag install ocif-tools`.

This app is a frontend: If you're looking for a library, or some more in-depth documentation, check [libocif](../libocif/README.md).

This app was only tested on Tier 3 GPUs, as it is the required tier for MineOS to install.

## Show images
To show any picture on-screen, run `ocif show [file].pic`, while replacing "[file]" with the name of the file you want to show.

![](images/show.png)

Images in MineOS are mostly transparent, like this one shown here for example. If you'd like to change the background color for transparent pixels, set the `-b` flag to the background color, in 24-bit hexadecimal.

![](images/show-white.png)

## Convert to ANSI
To convert any picture into ANSI art, run `ocif to-ansi [file].pic [output]`. Replace "[file]" with the filename of the picture, and "[output]" with the filename of the output file.

A default background can be encoded into the output file with the `-b` flag, just like with the `show` command.

For more information on the ANSI output, check the [libocif compatibility](../libocif/README.md#compatibility).