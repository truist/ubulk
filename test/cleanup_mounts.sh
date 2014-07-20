#!/bin/sh

mount | grep /tmp/shunit\. | cut -d ' ' -f 3 | while read dir ; do sudo umount -f $dir ; done

sudo rm -rf /tmp/shunit\.*

echo "Remaining mounts:"
mount
