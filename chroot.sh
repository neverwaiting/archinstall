#!/bin/sh

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

pacman --noconfirm --needed -S networkmanager
systemctl enable NetworkManager
systemctl start NetworkManager

# ucode intel/amd
if [ -n "$(lscpu | awk '/Model name/' | grep AMD)" ]; then
  UCODE="amd-ucode"
else
  UCODE="intel-ucode"
fi
pacman --noconfirm --needed -S grub efibootmgr $UCODE os-prober

grub-install --target="$(uname -m)-efi" --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg

# update mirror source
pacman --noconfirm --needed -S reflector
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
    pacman --noconfirm --needed -S mesa vulkan-intel xf86-video-intel;;
  "2")
    # for amd
    pacman --noconfirm --needed -S mesa vulkan-radeon xf86-video-amdgpu;;
  "3")
    # for nvidia
    pacman --noconfirm --needed -S nvidia nvidia-settings nvidia-utils;;
esac

pacman --noconfirm --needed -S xorg xorg-server xorg-xinit
pacman --noconfirm --needed -S openssh && systemctl enable sshd
pacman --noconfirm --needed -S openvpn zsh git wget zip unzip ripgrep fd fzf cmake ccls htop benchmark man-pages
pacman --noconfirm --needed -S go lua nodejs npm python python-pip
pacman --noconfirm --needed -S lf feh picom libnotify dunst
pacman --noconfirm --needed -S bat mediainfo ffmpegthumbnailer imagemagick\
 calcurse exiv2 sxiv xclip gimp zathura zathura-pdf-mupdf obs-studio ncmpcpp\
 mpd mpv noto-fonts noto-fonts-emoji pipewire pamixer pulseaudio pulsemixer python-pywal
pacman --noconfirm --needed -S net-tools firefox firefox-i18n-zh-cno
pacman --noconfirm --needed -S alsa-utils
pacman --noconfirm --needed -S figlet neofetch
pacman --noconfirm --needed -S v2ray qv2ray

USER_HOME="/home/$name"
USER_LOCAL_HOME="$USER_HOME/.local"
USER_CONFIG_HOME="$USER_HOME/.config"
MIRROR_GITHUB_URL="https://github.91chi.fun/https://github.com"

# install input for chinese
pacman --noconfirm --needed -S fcitx5-im fcitx5-chinese-addons fcitx5-lua fcitx5-pinyin-zhwiki
pacman --noconfirm --needed -S adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts
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
mkdir tools && pushd tools && install_git_project dwm st dmenu && popd
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

sudo -u "$name" yay -S --noconfirm lolcat

# set dotfiles
sudo -u "$name" git clone "$MIRROR_GITHUB_URL/neverwaiting/dotfiles.git" "$USER_HOME/dotfiles"&& \
sudo -u "$name" cp -r "$USER_HOME/dotfiles/.config" "$USER_HOME/" && \
sudo -u "$name" cp -r "$USER_HOME/dotfiles/.local" "$USER_HOME/" && \
sudo -u "$name" cp "$USER_HOME/dotfiles/.zprofile" "$USER_HOME/" && \
sudo -u "$name" cp "$USER_CONFIG_HOME/x11/Xmodmap" "$USER_HOME/.Xmodmap" && \
sudo -u "$name" cp "$USER_CONFIG_HOME/npm/npmrc" "$USER_HOME/.npmrc" || echo -e "########## set dotfiles error! ##########\n"

# add font CascadiaCode
USER_FONT_DIR="$USER_LOCAL_HOME/share/fonts"
sudo -u "$name" mkdir -p $USER_FONT_DIR && \
sudo -u "$name" wget "$MIRROR_GITHUB_URL/ryanoasis/nerd-fonts/releases/download/v2.2.2/CascadiaCode.zip" -O "$USER_FONT_DIR/CascadiaCode.zip" && \
sudo -u "$name" unzip "$USER_FONT_DIR/CascadiaCode.zip" -d "$USER_FONT_DIR" || echo -e "########## add nerd font error! ##########\n"

MIRROR_RAW_GITHUB_URL="https://github.91chi.fun/https://raw.github.com"
# install oh-my-zsh and powerlevel10k theme
sudo -u "$name" curl -fsL "$MIRROR_RAW_GITHUB_URL/ohmyzsh/ohmyzsh/master/tools/install.sh" | \
  sed 's/https:\/\/github.com/https:\/\/github.91chi.fun\/https:\/\/github.com/g' > "$USER_HOME/omzinstall.sh"
sudo -u "$name" ZSH="$USER_CONFIG_HOME/zsh/oh-my-zsh" sh "$USER_HOME/omzinstall.sh" --unattended && \
sudo -u "$name" git clone --depth=1 "$MIRROR_GITHUB_URL/romkatv/powerlevel10k.git" "$USER_CONFIG_HOME/zsh/oh-my-zsh/custom/themes/powerlevel10k" && \
rm -rf $USER_HOME/{.zshrc,omzinstall.sh} || echo -e "########## install oh-my-zsh or powerlevel10k error! ##########\n"

rm -rf $USER_HOME/{.bash_logout,.bash_profile,.bashrc}
