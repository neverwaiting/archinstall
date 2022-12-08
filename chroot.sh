#!/bin/sh

install() {
  pacman --noconfirm --needed -S $@
}

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

echo -e "en_US.UTF-8 UTF-8\nzh_CN.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

HOSTNAME=$(cat /etc/hostname)
cat << EOF >> /etc/hosts
127.0.0.1 localhost
::1	localhost
127.0.0.1	$HOSTNAME.localdomain	$HOSTNAME
EOF

name="wintersun"
password="zdy.1234"

# create user
useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 
echo "$name:$password" | chpasswd
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/temp
chsh -s /bin/zsh "$name" >/dev/null 2>&1

# set root password same with user's password
echo -e "$password\n$password" | passwd

install networkmanager
systemctl enable NetworkManager
systemctl start NetworkManager

# ucode intel/amd
if [ -n "$(lscpu | awk '/Model name/' | grep AMD)" ]; then
  UCODE="amd-ucode"
else
  UCODE="intel-ucode"
fi
install grub efibootmgr $UCODE os-prober

grub-install --target="$(uname -m)-efi" --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg

# update mirror source
install reflector
reflector --country China --latest 5 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist > /dev/null 2>&1
cat << EOF >> /etc/pacman.conf
[archlinuxcn]
SigLevel = Optional TrustAll
Server = https://repo.archlinuxcn.org/\$arch
EOF
pacman -Sy --noconfirm archlinux-keyring archlinuxcn-keyring

echo -e "please choice your GPU driver:\n"\
        "\t1) Intel integrated video card\n"\
        "\t2) Amd integrated video card\n"\
        "\t3) Nivdia external video card\n"
read -p"(default=1): " driver
if [ -z $driver ]; then driver="1"; fi
case $driver in
  "1")
    # for intel
    install mesa vulkan-intel xf86-video-intel;;
  "2")
    # for amd
    install mesa vulkan-radeon xf86-video-amdgpu;;
  "3")
    # for nvidia
    install linux-lts nvidia-lts nvidia-settings nvidia-utils;;
esac

install xorg xorg-server xorg-xinit
install openssh && systemctl enable sshd
install cronie && systemctl enable cronie
install openvpn starship zsh git wget zip unzip ripgrep fd fzf cmake ccls htop benchmark man-pages
install go lua luarocks nodejs npm python python-pip websocketd
install lf feh picom libnotify dunst
install bat mediainfo ffmpeg ffmpegthumbnailer imagemagick\
 calcurse exiv2 sxiv xclip gimp zathura zathura-pdf-mupdf obs-studio \
 mpv noto-fonts noto-fonts-emoji pipewire pamixer pulseaudio pulsemixer\
 python-pywal ueberzug bmon yt-dlp lynx
install net-tools brave-bin
install alsa-utils
install figlet neofetch
install v2ray qv2ray

USER_HOME="/home/$name"
USER_LOCAL_HOME="$USER_HOME/.local"
USER_CONFIG_HOME="$USER_HOME/.config"
MIRROR_GITHUB_URL="https://github.91chi.fun/https://github.com"

# install input for chinese
install fcitx5-im fcitx5-chinese-addons fcitx5-lua fcitx5-pinyin-zhwiki
install adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts
USER_FCITX_THEME_DIR="$USER_LOCAL_HOME/share/fcitx5/themes" 
[ -d "$USER_FCITX_THEME_DIR" ] || sudo -u "$name" mkdir -p "$USER_FCITX_THEME_DIR"
sudo -u "$name" git -C "$USER_FCITX_THEME_DIR" clone "$MIRROR_GITHUB_URL/sxqsfun/fcitx5-sogou-themes.git"
sudo -u "$name" cp -r "$USER_FCITX_THEME_DIR/fcitx5-sogou-themes/Alpha-black" "$USER_FCITX_THEME_DIR"

# install dwm(dynamic window manager), st(simple terminal), dmenu(menu bar)
install_git_project() {
  for pname in "$@"; do
    git clone "$MIRROR_GITHUB_URL/neverwaiting/$pname.git"
    pushd $pname && make clean install > /dev/null 2>&1 && popd
  done
}
mkdir tools && pushd tools && install_git_project dwm st dmenu dwmblocks && popd
mv /tools "$USER_HOME/tools"
chown -R "$name":wheel "$USER_HOME/tools"

# install yay(AUR) for user
sudo -u "$name" git -C "$USER_HOME/tools" clone https://aur.archlinux.org/yay.git && \
sudo -u "$name" sed -i 's/https:\/\/github.com/https:\/\/github.91chi.fun\/https:\/\/github.com/g' "$USER_HOME/tools/yay/PKGBUILD" && \
pushd "$USER_HOME/tools/yay" && \
sudo -u "$name" GOPROXY="https://goproxy.cn" makepkg --noconfirm -si && \
popd || echo -e "########## install yay error! ##########\n"

# install yesplaymusic
sudo -u "$name" git -C "$USER_HOME/tools" clone https://aur.archlinux.org/yesplaymusic.git && \
sudo -u "$name" sed -i 's/https:\/\/github.com/https:\/\/github.91chi.fun\/https:\/\/github.com/g' "$USER_HOME/tools/yesplaymusic/PKGBUILD" && \
pushd "$USER_HOME/tools/yesplaymusic" && \
sudo -u "$name" GOPROXY="https://goproxy.cn" makepkg --noconfirm -si && \
popd && ln -sf /opt/YesPlayMusic/yesplaymusic /bin/yesplaymusic || echo -e "########## install yesplaymusic error! ##########\n"

# install zsh syntax highlight plugin
sudo -u "$name" yay -S --noconfirm zsh-fast-syntax-highlighting

sudo -u "$name" yay -S --noconfirm lolcat

# set dotfiles
sudo -u "$name" git clone "$MIRROR_GITHUB_URL/neverwaiting/dotfiles.git" "$USER_HOME/dotfiles"&& \
sudo -u "$name" cp -r "$USER_HOME/dotfiles/.config" "$USER_HOME/" && \
sudo -u "$name" cp -r "$USER_HOME/dotfiles/.local" "$USER_HOME/" && \
sudo -u "$name" cp "$USER_HOME/dotfiles/.zprofile" "$USER_HOME/" && \
sudo -u "$name" cp "$USER_CONFIG_HOME/npm/npmrc" "$USER_HOME/.npmrc" || echo -e "########## set dotfiles error! ##########\n"

# configuration for picom
sed -i "s/^fade-in-step = \S*/fade-in-step = 0.08;/; s/^fade-out-step = \S*/fade-out-step = 0.08;/; s/^backend = \S*/backend = \"glx\";/" /etc/xdg/picom.conf

# install grub-theme
git clone "$MIRROR_GITHUB_URL/vinceliuice/grub2-themes.git" && pushd grub2-themes && ./install.sh -b -t stylish -s 4k && popd && rm -rf grub2-themes

rm -rf $USER_HOME/{.bash_logout,.bash_profile,.bashrc,tools,dotfiles}
