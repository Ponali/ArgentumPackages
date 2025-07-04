# utape

This program is a driver that takes tape drives that are connected to the computer and virtually turns them into an unmanaged drive when a tape is inserted. This takes advantage of the virtual component system present in Halyde.

Keep in mind that the tape drive component dissapears after conversion, and the end result is an *unmanaged* drive (raw binary), and not *managed* drives (filesystem).

To install and use, run `ag install utape`, confirm, then `reboot`.

## Usage
After installing, all tapes are automatically turned into unmanaged drives. If you would like to use a tape drive for audio, you can edit the config file.

The config file is located at `/halyde/config/utape.json`, and contains 4 parameters:

- `disabled`: If true, utape will not run.
- `drives`: A list of tape drives to convert into unmanaged drives.
- `readBuffer`: Whether to buffer read instructions or not (see [Buffering](#buffering).)
- `writeBuffer`: Whether to buffer write instructions or not (see [Buffering](#buffering).)
- `writeUpdate`: Amount of time for 
- `sectorSize`: The size (in bytes) of one sector in the simulated drive. It is generally recommended to leave this at 512 bytes.

## Buffering
Programs and/or other drivers that use unmanaged drives might access content by calling the drive for every byte, instead of every sector. For a tape drive, this is very inefficient, so buffering comes into play.

Buffering will read more content from the tape than requested, so that when this extra content gets requested, it can be instantly returned without needing to call the tape drive again. This makes for a speed boost in read/write speeds.

---

Here are the changes, in-depth, that buffering will do when activated:

- When a byte gets read, the buffer gets set to the contents of the sector it resides on, so that reading bytes from the same sector later on will use the buffer rather than reading from the tape
- When a byte gets written to, it will get written into the buffer instead of the tape. If two seconds passes (`writeUpdate` value), or another sector is getting accessed, the tape will get updated with the new content of the buffer.