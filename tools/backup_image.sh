IMG="$1"
DEST="$2"
VERSION="$3"

case "$2" in
    v*)  # $2 starts with 'v'
        DEST="$3"
        VERSION="$2"
        ;;
esac

if [ -z "$IMG" ]; then
    echo "Usage: $0 Targetimage <Destination> <version>"
    echo "Example $0 MultiBoot_Admin v0.5"
    echo "Example $0 MultiBoot_Admin /mnt/wdmycloud/finalimages"
	echo "This script has a default destination directory of  mnt/wdmycloud/finalimages. Please update to your own default destination"
    exit 1
fi

if [ -z "$DEST" ]; then
    #update default destination as needed
    echo "Using default destination of /mnt/wdmycloud/pi/final_images/${IMG}_${VERSION}.tar.gz"
    DEST="/mnt/wdmycloud/pi/final_images" 
    exit 1
fi

if [ ! -d "/mnt/realimages/$IMG" ]; then
    echo "/mnt/realimages/$IMG directory does not exist"
    exit 1
fi
DEST="${DEST%/}"

echo  "archiving  /mnt/realimages/${IMG} to ${DEST}/${IMG}_${VERSION}.tar.gz"
sudo tar -czf "${DEST}/${IMG}_${VERSION}.tar.gz" -C /mnt/realimages "${IMG}"
