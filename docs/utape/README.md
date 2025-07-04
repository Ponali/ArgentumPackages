# utape

This program is a driver that takes tape drives that are connected to the computer and virtually turns them into an unmanaged drive when a tape is inserted. This takes advantage of the virtual component system present in Halyde.

Keep in mind that the tape drive component dissapears after conversion, and the end result is an *unmanaged* drive (raw binary), and not *managed* drives (filesystem).

To install and use, run `ag install utape`, confirm, then `reboot`.

## Usage
After installing, all tapes are automatically turned into unmanaged drives. If you would like to use a tape drive for audio, you can edit the config file.

The config file is located at `/halyde/config/utape.json`, and contains 4 parameters:

- `disabled`: If true, utape will not run.
- `drives`: A list of tape drives to convert into unmanaged drives.
- `readBuffer`: If true, utape will buffer the sector of all read instructions. More bytes will be read in the tape, but it will generally be faster.
- `sectorSize`: The size (in bytes) of one sector in the simulated drive. It is generally recommended to leave this at 512 bytes.