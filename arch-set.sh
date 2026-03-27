#!/bin/bash
# =============================================================================
# Arch Linux Gaming Installer v3.2
# ext4 + Swap File 8GB + Все шрифты + Авто-монтирование игрового диска
# ВСЕ ОШИБКИ ИСПРАВЛЕНЫ
# =============================================================================

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Глобальные переменные
TARGET_MOUNT="/mnt"
SWAP_SIZE="8G"
LOG_FILE="/tmp/arch-gaming-install.log"
GAMES_MOUNT_POINT="/games"

# Логирование
log() { echo -e "${BLUE}[LOG]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# Проверка прав root
check_root() {
    [[ $EUID -eq 0 ]] || error "Запустите скрипт от root (sudo su)"
}

# Проверка Live-среды
check_live_env() {
    if [[ -f /etc/arch-release ]]; then
        info "Обнаружена Live-среда Arch Linux ✓"
        return 0
    fi
    warn "Скрипт предназначен для запуска с Live USB Arch Linux"
    read -p "Продолжить? [y/N]: " -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
}

# Очистка при прерывании
cleanup() {
    if [[ -n "$INSTALL_STARTED" ]]; then        warn "Установка прервана. Очистка..."
        umount -R "$TARGET_MOUNT" 2>/dev/null || true
        swapoff -a 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# =============================================================================
# МЕНЮ И ВВОД ПОЛЬЗОВАТЕЛЯ
# =============================================================================

select_language() {
    info "Выбор языка системы:"
    echo ""
    echo "  1) en_US.UTF-8 (English)"
    echo "  2) ru_RU.UTF-8 (Russian)"
    echo "  3) de_DE.UTF-8 (German)"
    echo "  4) fr_FR.UTF-8 (French)"
    echo "  5) ja_JP.UTF-8 (Japanese)"
    echo "  6) zh_CN.UTF-8 (Chinese)"
    echo ""
    
    while true; do
        read -p "Выберите номер (1-6) [2]: " lang_num
        lang_num="${lang_num:-2}"
        case $lang_num in
            1) LOCALE="en_US.UTF-8"; break ;;
            2) LOCALE="ru_RU.UTF-8"; break ;;
            3) LOCALE="de_DE.UTF-8"; break ;;
            4) LOCALE="fr_FR.UTF-8"; break ;;
            5) LOCALE="ja_JP.UTF-8"; break ;;
            6) LOCALE="zh_CN.UTF-8"; break ;;
            *) echo "Неверный выбор, попробуйте снова" ;;
        esac
    done
    success "Язык: $LOCALE"
}

select_keymap() {
    info "Выбор раскладки клавиатуры:"
    echo ""
    echo "Доступные раскладки:"
    echo "  1) us (английская)"
    echo "  2) ru (русская)"
    echo "  3) de (немецкая)"
    echo "  4) fr (французская)"
    echo "  5) jp (японская)"
    echo ""
    
    while true; do        read -p "Выберите основную раскладку (1-5) [2]: " main_keymap_num
        main_keymap_num="${main_keymap_num:-2}"
        case $main_keymap_num in
            1) MAIN_KEYMAP="us" ;;
            2) MAIN_KEYMAP="ru" ;;
            3) MAIN_KEYMAP="de" ;;
            4) MAIN_KEYMAP="fr" ;;
            5) MAIN_KEYMAP="jp" ;;
            *) echo "Неверный выбор"; continue ;;
        esac
        break
    done
    
    # Предложение добавить вторую раскладку
    echo ""
    read -n 1 -p "Добавить вторую раскладку для переключения? [y/N]: " add_second
    echo
    
    if [[ "$add_second" =~ ^[Yy]$ ]]; then
        echo "Выберите вторую раскладку:"
        echo "  1) us (английская)"
        echo "  2) ru (русская)"
        echo "  3) de (немецкая)"
        echo "  4) fr (французская)"
        echo "  5) jp (японская)"
        echo ""
        
        while true; do
            read -p "Вторая раскладка (1-5): " second_keymap_num
            case $second_keymap_num in
                1) SECOND_KEYMAP="us" ;;
                2) SECOND_KEYMAP="ru" ;;
                3) SECOND_KEYMAP="de" ;;
                4) SECOND_KEYMAP="fr" ;;
                5) SECOND_KEYMAP="jp" ;;
                *) echo "Неверный выбор"; continue ;;
            esac
            break
        done
        
        if [[ -n "$SECOND_KEYMAP" ]] && [[ "$SECOND_KEYMAP" != "$MAIN_KEYMAP" ]]; then
            KEYMAP="${MAIN_KEYMAP},${SECOND_KEYMAP}"
            XKB_OPTIONS="grp:alt_shift_toggle"
            success "Раскладки: $KEYMAP (переключение: Alt+Shift)"
        else
            KEYMAP="$MAIN_KEYMAP"
            XKB_OPTIONS=""
            success "Раскладка: $KEYMAP"
        fi
    else        KEYMAP="$MAIN_KEYMAP"
        XKB_OPTIONS=""
        success "Раскладка: $KEYMAP"
    fi
}

select_timezone() {
    info "Выбор часового пояса:"
    echo ""
    echo "  1) Europe/Moscow (Москва)"
    echo "  2) Europe/Kiev (Киев)"
    echo "  3) Europe/London (Лондон)"
    echo "  4) Europe/Berlin (Берлин)"
    echo "  5) Asia/Tokyo (Токио)"
    echo "  6) Asia/Shanghai (Шанхай)"
    echo "  7) UTC"
    echo ""
    
    while true; do
        read -p "Выберите номер (1-7) [1]: " tz_num
        tz_num="${tz_num:-1}"
        case $tz_num in
            1) TIMEZONE="Europe/Moscow"; break ;;
            2) TIMEZONE="Europe/Kiev"; break ;;
            3) TIMEZONE="Europe/London"; break ;;
            4) TIMEZONE="Europe/Berlin"; break ;;
            5) TIMEZONE="Asia/Tokyo"; break ;;
            6) TIMEZONE="Asia/Shanghai"; break ;;
            7) TIMEZONE="UTC"; break ;;
            *) echo "Неверный выбор" ;;
        esac
    done
    success "Часовой пояс: $TIMEZONE"
}

get_user_info() {
    echo ""
    info "Настройка пользователя:"
    
    read -p "Имя хоста (hostname) [arch-gaming]: " HOSTNAME
    HOSTNAME="${HOSTNAME:-arch-gaming}"
    
    read -p "Имя пользователя [gamer]: " USERNAME
    USERNAME="${USERNAME:-gamer}"
    
    read -sp "Пароль для $USERNAME: " USER_PASS
    echo
    read -sp "Подтвердите пароль: " USER_PASS_CONFIRM
    echo
        while [[ "$USER_PASS" != "$USER_PASS_CONFIRM" ]]; do
        error "Пароли не совпадают!"
        read -sp "Пароль для $USERNAME: " USER_PASS
        echo
        read -sp "Подтвердите пароль: " USER_PASS_CONFIRM
        echo
    done
    
    read -sp "Пароль root (или нажмите Enter для того же): " ROOT_PASS
    echo
    ROOT_PASS="${ROOT_PASS:-$USER_PASS}"
    
    success "Пользователь: $USERNAME, Хост: $HOSTNAME"
}

select_system_disk() {
    echo ""
    info "=== Выбор диска для установки системы ==="
    warn "⚠️  Все данные на выбранном диске будут УДАЛЕНЫ!"
    echo ""
    
    echo "Доступные диски:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep disk
    echo ""
    
    mapfile -t disks < <(lsblk -d -n -o NAME | grep -v loop)
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        error "Не найдено дисков для установки!"
    fi
    
    for i in "${!disks[@]}"; do
        disk_info=$(lsblk -d -n -o NAME,SIZE,MODEL /dev/${disks[$i]} 2>/dev/null | tr -s ' ')
        echo "  $((i+1))) /dev/${disks[$i]} - $disk_info"
    done
    echo ""
    
    while true; do
        read -p "Выберите номер диска для системы: " disk_num
        if [[ "$disk_num" =~ ^[0-9]+$ ]] && [[ $disk_num -ge 1 ]] && [[ $disk_num -le ${#disks[@]} ]]; then
            SYS_DISK="/dev/${disks[$((disk_num-1))]}"
            break
        fi
        warn "Неверный номер"
    done
    
    success "Диск системы: $SYS_DISK"
    
    echo ""    warn "Вы выбрали: $SYS_DISK"
    read -p "Продолжить и УДАЛИТЬ все данные на этом диске? [YES/no]: " confirm
    if [[ "$confirm" != "YES" ]]; then
        error "Установка отменена пользователем"
    fi
}

select_games_disk() {
    echo ""
    info "=== Настройка диска для игр (опционально) ==="
    echo "Отдельный диск для игр позволит хранить игры отдельно от системы."
    echo "Это удобно для переустановки системы без удаления игр."
    echo ""
    
    read -n 1 -p "Использовать отдельный диск для игр? [y/N]: " use_games_disk
    echo
    
    if [[ ! "$use_games_disk" =~ ^[Yy]$ ]]; then
        GAMES_DISK=""
        info "Игры будут установлены на системный диск"
        return
    fi
    
    info "Выберите диск для игровой библиотеки:"
    
    # Получаем список дисков кроме системного
    mapfile -t disks < <(lsblk -d -n -o NAME | grep -v loop | grep -v "$(basename $SYS_DISK)")
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        warn "Нет доступных дисков. Игры будут на системном разделе."
        GAMES_DISK=""
        return
    fi
    
    echo "Доступные диски:"
    for i in "${!disks[@]}"; do
        disk_info=$(lsblk -d -n -o NAME,SIZE,MODEL /dev/${disks[$i]} 2>/dev/null | tr -s ' ')
        echo "  $((i+1))) /dev/${disks[$i]} - $disk_info"
    done
    echo "  0) Пропустить"
    echo ""
    
    while true; do
        read -p "Выберите номер диска: " disk_num
        if [[ "$disk_num" == "0" ]]; then
            GAMES_DISK=""
            info "Пропущено"
            return
        fi
        if [[ "$disk_num" =~ ^[0-9]+$ ]] && [[ $disk_num -ge 1 ]] && [[ $disk_num -le ${#disks[@]} ]]; then            GAMES_DISK="/dev/${disks[$((disk_num-1))]}"
            break
        fi
        warn "Неверный номер"
    done
    
    read -p "Точка монтирования [/games]: " custom_mount
    if [[ -n "$custom_mount" ]]; then
        GAMES_MOUNT_POINT="/$custom_mount"
    else
        GAMES_MOUNT_POINT="/games"
    fi
    
    success "Диск игр: $GAMES_DISK → $GAMES_MOUNT_POINT"
}

select_desktop() {
    echo ""
    info "=== Выбор окружения рабочего стола ==="
    echo ""
    echo "  1) GNOME (современное, много функций)"
    echo "  2) Plasma KDE (лёгкое, настраиваемое)"
    echo "  3) Minimal (только окно входа, без DE)"
    echo ""
    
    while true; do
        read -p "Выберите номер (1-3) [2]: " de_num
        de_num="${de_num:-2}"
        case $de_num in
            1) 
                DE="gnome"
                DE_PACKAGES="gnome gnome-extra"
                DISPLAY_MANAGER="gdm"
                break ;;
            2) 
                DE="plasma"
                DE_PACKAGES="plasma plasma-meta konsole dolphin"
                DISPLAY_MANAGER="sddm"
                break ;;
            3) 
                DE="minimal"
                DE_PACKAGES="xorg-server xorg-xinit"
                DISPLAY_MANAGER="lightdm"
                break ;;
            *) echo "Неверный выбор" ;;
        esac
    done
    success "Окружение: $DE"
}
select_gpu_drivers() {
    echo ""
    info "=== Выбор видеокарты ==="
    echo ""
    echo "  1) NVIDIA (проприетарные, версия 580xx)"
    echo "  2) NVIDIA (проприетарные, актуальные)"
    echo "  3) AMD / Intel (открытые)"
    echo "  4) VirtualBox / VMware"
    echo ""
    
    while true; do
        read -p "Выберите номер (1-4) [3]: " gpu_num
        gpu_num="${gpu_num:-3}"
        case $gpu_num in
            1)
                GPU_DRIVERS="nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils"
                GPU_AUR="yay"
                break ;;
            2)
                GPU_DRIVERS="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
                GPU_AUR="yay"
                break ;;
            3)
                GPU_DRIVERS="mesa lib32-mesa xf86-video-amdgpu xf86-video-intel vulkan-radeon lib32-vulkan-radeon"
                GPU_AUR=""
                break ;;
            4)
                GPU_DRIVERS="virtualbox-guest-utils open-vm-tools"
                GPU_AUR=""
                break ;;
            *) echo "Неверный выбор" ;;
        esac
    done
    success "Драйверы: $GPU_DRIVERS"
}

# =============================================================================
# РАЗБИЕНИЕ ДИСКА (ext4)
# =============================================================================

partition_disk() {
    info "=== Разбиение диска: $SYS_DISK (ext4) ==="
    
    if [[ -d /sys/firmware/efi ]]; then
        UEFI_MODE=true
        info "Обнаружен UEFI режим"
    else
        UEFI_MODE=false
        info "Обнаружен BIOS/Legacy режим"
    fi    
    warn "Удаление существующих разделов на $SYS_DISK..."
    wipefs --all "$SYS_DISK" 2>/dev/null || true
    partx -d "$SYS_DISK" 2>/dev/null || true
    
    if $UEFI_MODE; then
        info "Создание разделов (UEFI):"
        echo "  - /dev/${SYS_DISK##*/}1 : EFI System Partition (512M)"
        echo "  - /dev/${SYS_DISK##*/}2 : Root (ext4, всё остальное)"
        echo "  - Swap: файл 8GB (будет создан после установки)"
        
        parted -s "$SYS_DISK" mklabel gpt
        parted -s "$SYS_DISK" mkpart primary fat32 1MiB 513MiB
        parted -s "$SYS_DISK" set 1 esp on
        parted -s "$SYS_DISK" mkpart primary ext4 513MiB 100%
        
        mkfs.fat -F32 "${SYS_DISK}1"
        mkfs.ext4 -F "${SYS_DISK}2"
        
        EFI_PART="${SYS_DISK}1"
        ROOT_PART="${SYS_DISK}2"
        
    else
        info "Создание разделов (BIOS):"
        echo "  - /dev/${SYS_DISK##*/}1 : BIOS Boot Partition (1M)"
        echo "  - /dev/${SYS_DISK##*/}2 : Root (ext4, всё остальное)"
        echo "  - Swap: файл 8GB (будет создан после установки)"
        
        parted -s "$SYS_DISK" mklabel msdos
        parted -s "$SYS_DISK" mkpart primary 1MiB 2MiB
        parted -s "$SYS_DISK" set 1 bios_grub on
        parted -s "$SYS_DISK" mkpart primary ext4 2MiB 100%
        
        mkfs.ext4 -F "${SYS_DISK}2"
        
        ROOT_PART="${SYS_DISK}2"
    fi
    
    success "Разделы созданы (ext4)"
}

mount_partitions() {
    info "Монтирование разделов..."
    
    mount "${ROOT_PART}" "$TARGET_MOUNT"
    
    if $UEFI_MODE; then
        mkdir -p "$TARGET_MOUNT/boot"
        mount "${EFI_PART}" "$TARGET_MOUNT/boot"
    fi    
    success "Разделы смонтированы"
}

setup_games_disk() {
    if [[ -z "$GAMES_DISK" ]]; then
        return
    fi
    
    info "Настройка диска для игр: $GAMES_DISK"
    
    read -n 1 -p "Отформатировать $GAMES_DISK? (ext4) [y/N]: " format_disk
    echo
    if [[ "$format_disk" =~ ^[Yy]$ ]]; then
        wipefs --all "$GAMES_DISK" 2>/dev/null || true
        mkfs.ext4 -F "$GAMES_DISK"
    fi
    
    # Создаём точку монтирования в целевой системе
    mkdir -p "$TARGET_MOUNT$GAMES_MOUNT_POINT"
    
    # ИСПРАВЛЕНИЕ: Создаём директорию /etc если её ещё нет
    mkdir -p "$TARGET_MOUNT/etc"
    
    # Получаем UUID диска
    GAMES_UUID=$(blkid -s UUID -o value "$GAMES_DISK")
    
    # Записываем в fstab.games
    echo "UUID=$GAMES_UUID $GAMES_MOUNT_POINT ext4 defaults,noatime,x-gvfs-show 0 2" >> "$TARGET_MOUNT/etc/fstab.games"
    
    success "Диск игр настроен: $GAMES_DISK → $GAMES_MOUNT_POINT"
}

# =============================================================================
# УСТАНОВКА БАЗОВОЙ СИСТЕМЫ
# =============================================================================

install_base_system() {
    info "=== Установка базовой системы ==="
    
    timedatectl set-ntp true
    
    info "Обновление зеркал..."
    reflector --country Russia --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true
    
    info "Установка пакетов: base linux linux-firmware ext4..."
    pacstrap -K "$TARGET_MOUNT" \
        base \
        linux linux-firmware \
        e2fsprogs \        networkmanager \
        sudo \
        nano \
        vim \
        git \
        curl \
        wget \
        dosfstools \
        mtools \
        os-prober \
        grub efibootmgr
    
    success "Базовая система установлена"
}

# =============================================================================
# НАСТРОЙКА СИСТЕМЫ (CHROOT)
# =============================================================================

configure_system() {
    info "=== Настройка системы ==="
    
    info "Генерация fstab..."
    genfstab -U "$TARGET_MOUNT" >> "$TARGET_MOUNT/etc/fstab"
    
    # Добавляем запись для игр если есть
    if [[ -f "$TARGET_MOUNT/etc/fstab.games" ]]; then
        cat "$TARGET_MOUNT/etc/fstab.games" >> "$TARGET_MOUNT/etc/fstab"
        rm -f "$TARGET_MOUNT/etc/fstab.games"
    fi
    
    info "Подготовка chroot окружения..."
    
    # Экспорт переменных для chroot
    export LOCALE KEYMAP XKB_OPTIONS TIMEZONE HOSTNAME USERNAME USER_PASS ROOT_PASS
    export DE DE_PACKAGES DISPLAY_MANAGER GPU_DRIVERS GAMES_MOUNT_POINT SWAP_SIZE SYS_DISK
    
    cat > "$TARGET_MOUNT/root/post-install.sh" << 'CHROOT_SCRIPT'
#!/bin/bash
set -e

# 1. Locale
echo "${LOCALE} UTF-8" > /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP%%,*}" > /etc/vconsole.conf
[[ -n "$XKB_OPTIONS" ]] && echo "XKBOPTIONS=\"$XKB_OPTIONS\"" >> /etc/vconsole.conf

# 2. Timezoneln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# 3. Hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# 4. Root password
echo "root:${ROOT_PASS}" | chpasswd

# 5. Пользователь + sudoers
useradd -m -G wheel,audio,video,storage,input,kvm,render -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd
echo "${USERNAME} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME}
chmod 0440 /etc/sudoers.d/${USERNAME}

# 6. Initramfs
mkinitcpio -P

# 7. Загрузчик - ИСПРАВЛЕНО
if [[ -d /boot/efi ]] || [[ -d /boot/EFI ]]; then
    # UEFI режим
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux
else
    # BIOS режим - используем SYS_DISK
    if [[ -n "$SYS_DISK" ]]; then
        grub-install --target=i386-pc "$SYS_DISK"
    else
        # Пробуем определить из fstab
        ROOT_DEV=$(grep -v '^#' /etc/fstab | grep ' / ' | awk '{print $1}' | sed 's/[0-9]*$//')
        if [[ -n "$ROOT_DEV" ]]; then
            grub-install --target=i386-pc "$ROOT_DEV"
        else
            echo "ERROR: Cannot determine root device for GRUB installation"
            exit 1
        fi
    fi
fi

GRUB_CMDLINE="quiet splash loglevel=3 mitigations=off pcie_aspm=off processor.max_cstate=1"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"/" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# 8. Сеть
systemctl enable NetworkManager
# 9. Обновление системы
pacman -Syu --noconfirm

# 10. Видео драйверы
if [[ -n "${GPU_DRIVERS}" ]]; then
    pacman -S --needed --noconfirm ${GPU_DRIVERS}
fi

# 11. Desktop Environment
if [[ "$DE" == "gnome" ]]; then
    pacman -S --needed --noconfirm ${DE_PACKAGES}
    systemctl enable gdm
elif [[ "$DE" == "plasma" ]]; then
    pacman -S --needed --noconfirm ${DE_PACKAGES}
    systemctl enable sddm
elif [[ "$DE" == "minimal" ]]; then
    pacman -S --needed --noconfirm ${DE_PACKAGES} ${DISPLAY_MANAGER}
    systemctl enable lightdm
fi

# 12. SWAP FILE 8GB
info "Создание swap-файла ${SWAP_SIZE}..."
fallocate -l ${SWAP_SIZE} /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab
success "Swap-файл ${SWAP_SIZE} создан"

# 13. Установка yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd /tmp && rm -rf yay

# 14. CachyOS репозиторий
curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o /tmp/cachyos-repo.tar.xz
tar xvf /tmp/cachyos-repo.tar.xz -C /tmp && cd /tmp/cachyos-repo
./cachyos-repo.sh
pacman-key --populate cachyos
pacman -Syyu --noconfirm
cd / && rm -rf /tmp/cachyos-repo /tmp/cachyos-repo.tar.xz

# 15. Игровые пакеты
yay -S --needed --noconfirm \
    google-chrome \
    vesktop \
    ayugram-desktop \
    prismlauncher \    steam-tui \
    proton-ge-custom-bin

pacman -S --needed --noconfirm \
    steam \
    flatpak \
    nodejs \
    python310

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 16. Игровые утилиты
pacman -S --needed --noconfirm \
    gamemode lib32-gamemode \
    goverlay \
    mangohud lib32-mangohud \
    gamescope \
    vkd3d-proton \
    protonup-qt

# 17. Zapret
if bash <(curl -s https://raw.githubusercontent.com/kartavku