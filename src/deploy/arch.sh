IMAGE_NAME=$1
IMAGE_INSTALL_PATH=/boot/vmlinuz-$IMAGE_NAME
PRESET_PATH=/etc/mkinitcpio.d/$IMAGE_NAME.preset
INITRAMFS_PATH=/boot/initramfs-$IMAGE_NAME.img

# TODO: take architecture as parameter.
cp -v arch/x86/boot/bzImage $IMAGE_INSTALL_PATH
cp -v /etc/mkinitcpio.d/linux.preset $PRESET_PATH
sed -i "s@ALL_kver=\".*\"@ALL_kver=\"$IMAGE_INSTALL_PATH\"@g" $PRESET_PATH
sed -i "s@default_image=\".*\"@default_image=\"$INITRAMFS_PATH\"@g" $PRESET_PATH
mkinitcpio -p $IMAGE_NAME
grub-mkconfig -o /boot/grub/grub.cfg