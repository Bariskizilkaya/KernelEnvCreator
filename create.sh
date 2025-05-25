#!/bin/bash
echo "Dependencies are installing."
sudo apt install libncurses5-dev libssl-dev bison flex libelf-dev gcc make openssl libc6-dev
# Step 1: Fetch kernel versions from kernel.org
echo "Fetching available kernel versions from kernel.org..."
KERNEL_LIST=$(curl -s https://www.kernel.org/pub/linux/kernel/v6.x/ | grep -oP 'linux-\K[0-9]+\.[0-9]+(\.[0-9]+)?(?=\.tar\.xz)' | sort -Vr | uniq)

# Step 2: Convert to array
KERNEL_ARRAY=($KERNEL_LIST)

# Step 3: Display menu
echo "Available Linux Kernel Versions:"
for i in "${!KERNEL_ARRAY[@]}"; do
    echo "[$i] ${KERNEL_ARRAY[$i]}"
done

# Step 4: Prompt user to select one
read -p "Enter the number of the kernel you want to download and build: " SELECTED_INDEX

# Check for valid input
if [[ ! "$SELECTED_INDEX" =~ ^[0-9]+$ ]] || [ "$SELECTED_INDEX" -ge "${#KERNEL_ARRAY[@]}" ]; then
    echo "Invalid selection. Exiting."
    exit 1
fi

SELECTED_VERSION=${KERNEL_ARRAY[$SELECTED_INDEX]}
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${SELECTED_VERSION}.tar.xz"

echo "Selected kernel version: $SELECTED_VERSION"
echo "Downloading from $KERNEL_URL..."

# Step 5: Download and extract
wget "$KERNEL_URL" -O "linux-${SELECTED_VERSION}.tar.xz"
tar -xf "linux-${SELECTED_VERSION}.tar.xz"

# Step 6: Compile
cd "linux-${SELECTED_VERSION}" || exit
echo "Running make defconfig..."
make defconfig
make kvm_guest.config

echo "Compiling kernel... this may take a while."
make -j$(nproc)

echo "Kernel $SELECTED_VERSION has been compiled successfully."

wget https://storage.googleapis.com/syzkaller/wheezy.img

echo "wheezy.img downloaded successfully."

echo "Trying to emulate the kernel with QEMU..."

qemu-system-x86_64 \
	-m 2G \
	-smp 2 \
	-kernel arch/x86/boot/bzImage \
	-append "console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0" \
	-drive file=wheezy.img,format=raw \
	-net user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:10021-:22 \
	-net nic,model=e1000 \
	-enable-kvm \
	-nographic \
	-pidfile vm.pid \
	2>&1 | tee vm.log