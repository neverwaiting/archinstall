#!/bin/sh

temp_packages_dir="/tmp/packages"

pacman_install() {
  pacman --noconfirm --needed -S $@
}

aur_install() {
  storage_dir=${temp_packages_dir:-"/tmp/packages"}
  [ -d "$storage_dir" ] || mkdir -p "$storage_dir"
  for item in $@; do
    sudo -u "$name" git -C "$storage_dir" clone "https://aur.archlinux.org/${item}.git" && \
    sudo -u "$name" sed -iE 's#(https://github.com)#https://github.91chi.fun/\1#g' "$storage_dir/$item/PKGBUILD" && \
    pushd "$storage_dir/$item" && \
    sudo -u "$name" GOPROXY="https://goproxy.cn" makepkg --noconfirm -si && \
    popd || echo -e "########## AUR: Install $item failed! ##########\n"
  done
}

yay_install() {
  sudo -u "$name" yay -S --noconfirm $@
}

git_install() {
  storage_dir=${temp_packages_dir:-"/tmp/packages"}
  [ -d "$storage_dir" ] || mkdir -p "$storage_dir"
  pushd "$storage_dir"
  for repo in $@; do
    git clone "$repo"
    repo_name=$(echo "$repo" | sed -E 's/.+\/(.+)\.git/\1/')
    pushd "$repo_name" && make clean install > /dev/null 2>&1 && popd
  done
  popd
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

pacman_install networkmanager && systemctl enable NetworkManager && systemctl start NetworkManager

# ucode intel/amd
if [ -n "$(lscpu | awk '/Model name/' | grep AMD)" ]; then
  UCODE="amd-ucode"
else
  UCODE="intel-ucode"
fi
pacman_install grub efibootmgr $UCODE os-prober

grub-install --target="$(uname -m)-efi" --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg

# update mirror source
pacman_install reflector
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
    pacman_install mesa vulkan-intel xf86-video-intel;;
  "2")
    # for amd
    pacman_install mesa vulkan-radeon xf86-video-amdgpu;;
  "3")
    # for nvidia
    pacman_install linux-lts nvidia-lts nvidia-settings nvidia-utils;;
esac

pacman_install openssh && systemctl enable sshd
pacman_install cronie && systemctl enable cronie

USER_HOME="/home/$name"
USER_LOCAL_HOME="$USER_HOME/.local"
USER_CONFIG_HOME="$USER_HOME/.config"
MIRROR_GITHUB_URL="https://github.91chi.fun/https://github.com"

# install input for chinese
pacman_install fcitx5-im fcitx5-chinese-addons fcitx5-lua fcitx5-pinyin-zhwiki
pacman_install adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts
USER_FCITX_THEME_DIR="$USER_LOCAL_HOME/share/fcitx5/themes" 
[ -d "$USER_FCITX_THEME_DIR" ] || sudo -u "$name" mkdir -p "$USER_FCITX_THEME_DIR"
sudo -u "$name" git -C "$USER_FCITX_THEME_DIR" clone "$MIRROR_GITHUB_URL/sxqsfun/fcitx5-sogou-themes.git"
sudo -u "$name" cp -r "$USER_FCITX_THEME_DIR/fcitx5-sogou-themes/Alpha-black" "$USER_FCITX_THEME_DIR"

while IFS=',' read -a packs; do
  if [ -z "${packs[0]}" ]; then
    pacpackages="$pacpackages ${packs[1]}"
  elif [ "${packs[0]}" == "Y" ]; then
    yaypackages="$yaypackages ${packs[1]}"
  elif [ "${packs[0]}" == "A" ]; then
    aurpackages="$aurpackages ${packs[1]}"
  elif [ "${packs[0]}" == "G" ]; then
    gitpackages="$gitpackages ${packs[1]}"
  fi
done < packages.csv

aur_install yay
[ -z "$pacpackages" ] || pacman_install "$pacpackages"
[ -z "$aurpackages" ] || aur_install "$aurpackages" 
[ -z "$yaypackages" ] || yay_install "$yaypackages"
[ -z "$gitpackages" ] || git_install "$gitpackages" 
[ -x /opt/YesPlayMusic/yesplaymusic ] && ln -sf /opt/YesPlayMusic/yesplaymusic /bin/yesplaymusic

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

# clean unused files
rm -rf $USER_HOME/{.bash_logout,.bash_profile,.bashrc,dotfiles}
