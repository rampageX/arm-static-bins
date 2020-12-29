Source: [FSArchiver](https://www.fsarchiver.org/)

Results:

	file ./fsarchiver
	./haproxy: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped

Info:

```
fsarchiver -h
====> fsarchiver version 0.8.6-git (YYYY-MM-DD) - http://www.fsarchiver.org <====
Distributed under the GPL v2 license (GNU General Public License v2).
 * usage: fsarchiver [<options>] <command> <archive> [<dev1> [<dev2> [...]]]
<commands>
 * savefs: save filesystems to an archive file (backup a device to a file)
 * restfs: restore filesystems from an archive (overwrites the existing data)
 * savedir: save directories to the archive (similar to a compressed tarball)
 * restdir: restore data from an archive which is not based on a filesystem
 * archinfo: show information about an existing archive file and its contents
 * probe [detailed]: show list of filesystems detected on the disks
<options>
 -o: overwrite the archive if it already exists instead of failing
 -v: verbose mode (can be used several times to increase the level of details)
 -d: debug mode (can be used several times to increase the level of details)
 -A: allow to save a filesystem which is mounted in read-write (live backup)
 -a: allow to save a filesystem when acls and xattrs are not supported
 -x: enable support for experimental features (they are disabled by default)
 -e <pattern>: exclude files and directories that match that pattern
 -L <label>: set the label of the archive (comment about the contents)
 -z <level>: legacy compression level from 0 (very fast) to 9 (very good)
 -Z <level>: zstd compression level from 1 (very fast) to 22 (very good)
 -s <mbsize>: split the archive into several files of <mbsize> megabytes each
 -j <count>: create more than one (de)compression thread. useful on multi-core cpu
 -c <password>: encrypt/decrypt data in archive, "-c -" for interactive password
 -h: show help and information about how to use fsarchiver with examples
 -V: show program version and exit
<information>
 * Support included for: lzo=yes, lzma=yes, lz4=yes, zstd=yes
 * Support for ntfs filesystems is unstable: don't use it for production.
<examples>
 * save only one filesystem (/dev/sda1) to an archive:
   fsarchiver savefs /data/myarchive1.fsa /dev/sda1
 * save two filesystems (/dev/sda1 and /dev/sdb1) to an archive:
   fsarchiver savefs /data/myarchive2.fsa /dev/sda1 /dev/sdb1
 * restore the first filesystem from an archive (first = number 0):
   fsarchiver restfs /data/myarchive2.fsa id=0,dest=/dev/sda1
 * restore the second filesystem from an archive (second = number 1):
   fsarchiver restfs /data/myarchive2.fsa id=1,dest=/dev/sdb1
 * restore two filesystems from an archive (number 0 and 1):
   fsarchiver restfs /data/arch2.fsa id=0,dest=/dev/sda1 id=1,dest=/dev/sdb1
 * restore a filesystem from an archive and convert it to reiserfs:
   fsarchiver restfs /data/myarchive1.fsa id=0,dest=/dev/sda1,mkfs=reiserfs
 * restore a filesystem from an archive and specify extra mkfs options:
   fsarchiver restfs /data/myarchive1.fsa id=0,dest=/dev/sda1,mkfs=ext4,mkfsopt="-I 256"
 * restore a filesystem from an archive and specify a new label and a new UUID:
   fsarchiver restfs /data/myarchive1.fsa id=0,dest=/dev/sda1,label=root,uuid=5f6e5f4f-dc2a-4dbd-a6ea-9ca997cde75e
 * save the contents of /usr/src/linux to an archive (similar to tar):
   fsarchiver savedir /data/linux-sources.fsa /usr/src/linux
 * save a filesystem (/dev/sda1) to an archive split into volumes of 680MB:
   fsarchiver savefs -s 680 /data/myarchive1.fsa /dev/sda1
 * save a filesystem and exclude all files/dirs called 'pagefile.*':
   fsarchiver savefs /data/myarchive.fsa /dev/sda1 --exclude='pagefile.*'
 * generic exclude for 'share' such as '/usr/share' and '/usr/local/share':
   fsarchiver savefs /data/myarchive.fsa --exclude=share
 * absolute exclude valid for '/usr/share' but not for '/usr/local/share':
   fsarchiver savefs /data/myarchive.fsa --exclude=/usr/share
 * save a filesystem (/dev/sda1) to an encrypted archive:
   fsarchiver savefs -c mypassword /data/myarchive1.fsa /dev/sda1
 * same as before but prompt for password in the terminal:
   fsarchiver savefs -c - /data/myarchive1.fsa /dev/sda1
 * extract an archive made of simple files to /tmp/extract:
   fsarchiver restdir /data/linux-sources.fsa /tmp/extract
 * show information about an archive and its filesystems:
   fsarchiver archinfo /data/myarchive2.fsa
```