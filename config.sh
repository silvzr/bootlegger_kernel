#!/usr/bin/env sh

KERNELSU_DIR=$(find $KERNEL_DIR -mindepth 0 -maxdepth 4 \( -iname "ksu" -o -iname "kernelsu" \) -type d ! -path "*/.git/*" | cut -c3-)
KERNELSU_GITMODULE=$(grep -i "KernelSU" $KERNEL_DIR/.gitmodules)

# Compare kernel versions in order to apply the correct patches
version_le() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# Avoid dirty uname
touch $KERNEL_DIR/.scmversion

if [[ $KERNEL_VER == "4.14" ]]; then
    cp $WORKDIR/patches/strip_out_extraversion.patch $KERNEL_DIR/
    cd $KERNEL_DIR && patch -p1 < strip_out_extraversion.patch
    msg "4.14 detected! Removing openela tag..."
fi

msg "KernelSU"
if [[ $KSU_ENABLED == "true" ]] && [[ ! -z "$KERNELSU_DIR" ]]; then
    if [[ ! -z "$KERNELSU_GITMODULE" ]]; then
        cd $KERNEL_DIR && git submodule init && git submodule update
        msg "KernelSU submodule detected! Cloning..."
    fi    

    if version_le "$KERNEL_VER" "5.9"; then
        cp $WORKDIR/patches/KernelSU/Backport/revert_backport_path_umount.patch $KERNEL_DIR/
        cd $KERNEL_DIR && patch -p1 < revert_backport_path_umount.patch
        msg "Fixing possible path_umount conflicts..."

        if [[ ! -f "$WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/add_susfs_in_kernel-$KERNEL_VER.patch" ]]; then
    	    cp $WORKDIR/patches/KernelSU/Backport/backport_path_umount.patch $KERNEL_DIR/
            cd $KERNEL_DIR && patch -p1 < backport_path_umount.patch
            msg "Backporting path_umount from 5.10.9..."
        fi
    fi

    if [[ ! -z "$MANAGER_EXPECTED_SIZE" ]] && [[ ! -z "$MANAGER_EXPECTED_HASH" ]]; then
	cd $KERNEL_DIR/$KERNELSU_DIR
        if [[ -d "$KERNEL_DIR/$KERNELSU_DIR/kernel" ]]; then
	    sed -i '/return check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH);/c\
            \    return (check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH) || check_v2_signature(path, '"$MANAGER_EXPECTED_SIZE"', "'"$MANAGER_EXPECTED_HASH"'"));' kernel/apk_sign.c
        else
	    sed -i '/return check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH);/c\
            \    return (check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH) || check_v2_signature(path, '"$MANAGER_EXPECTED_SIZE"', "'"$MANAGER_EXPECTED_HASH"'"));' apk_sign.c
        fi
	msg "KSU_EXPECTED_SIZE := $MANAGER_EXPECTED_SIZE"
        msg "KSU_EXPECTED_HASH := $MANAGER_EXPECTED_HASH"
    fi

    cp $WORKDIR/patches/KernelSU/Backport/safe_mode_ksu.patch $KERNEL_DIR/
    cd $KERNEL_DIR && patch -p1 < safe_mode_ksu.patch
    msg "Backporting KSU safe mode..."
    
    if [[ ! -f "$KERNEL_DIR/fs/susfs.c" || ! -f "$KERNEL_DIR/include/linux/susfs.h" ]]; then
        if [[ -d "$KERNEL_DIR/$KERNELSU_DIR/kernel" ]]; then
    	    cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/enable_susfs_for_ksu_auto.patch $KERNEL_DIR/$KERNELSU_DIR/
    	    cd $KERNEL_DIR/$KERNELSU_DIR && patch -p1 -F 3 < enable_susfs_for_ksu_auto.patch
        else
    	    cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/enable_susfs_for_ksu_manual.patch $KERNEL_DIR/$KERNELSU_DIR/
            cd $KERNEL_DIR/$KERNELSU_DIR && patch -p1 -F 3 < enable_susfs_for_ksu_manual.patch
        fi
    	msg "Importing SuSFS into KSU source..."

        cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/add_susfs_in_kernel-$KERNEL_VER.patch $KERNEL_DIR/
    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/susfs.c $KERNEL_DIR/fs/
    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/susfs.h $KERNEL_DIR/include/linux/
	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/sus_su.c $KERNEL_DIR/fs/
	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/sus_su.h $KERNEL_DIR/include/linux/
    	cd $KERNEL_DIR && patch -p1 -F 3 < add_susfs_in_kernel-$KERNEL_VER.patch
    	msg "Importing SuSFS for $KERNEL_VER kernel..."
    fi

    cd $KERNEL_DIR
    echo "CONFIG_KSU=y" >> $DEVICE_DEFCONFIG_FILE
    echo "CONFIG_KSU_SUSFS=y" >> $DEVICE_DEFCONFIG_FILE

    if [[ ! -z "$KERNELSU_GITMODULE" ]]; then
        KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
        KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10200))
    else
        KERNELSU_VERSION=$(cat $KERNELSU_DIR/ksu.h | grep "KERNEL_SU_VERSION" | cut -c26-)
    fi
    
    SUSFS_VERSION=$(grep "SuSFS version:" $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/add_susfs_in_kernel-$KERNEL_VER.patch | cut -d' ' -f3)
    msg "KernelSU Version: $KERNELSU_VERSION"
    msg "SuSFS version: $SUSFS_VERSION"
    sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$KERNEL_BRANCH-$KERNEL_NAME-κsu\"/" $DEVICE_DEFCONFIG_FILE
elif
   [[ $KSU_ENABLED == "true" ]]; then
    if [[ $KERNELSU_REPO == "backslashxx/KernelSU" ]]; then
    	cd $KERNEL_DIR && curl -LSs "https://raw.githubusercontent.com/$KERNELSU_REPO/$KERNELSU_BRANCH/kernel/setup.sh" | bash -s v2.1.1-10
    else
	cd $KERNEL_DIR && curl -LSs "https://raw.githubusercontent.com/$KERNELSU_REPO/$KERNELSU_BRANCH/kernel/setup.sh" | bash -s $KERNELSU_BRANCH
    fi

    if version_le "$KERNEL_VER" "5.9"; then
        if [[ ! -f "$WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/add_susfs_in_kernel-$KERNEL_VER.patch" ]]; then
    	    cp $WORKDIR/patches/KernelSU/Backport/backport_path_umount.patch $KERNEL_DIR/
            cd $KERNEL_DIR && patch -p1 < backport_path_umount.patch
            msg "Backporting path_umount from 5.10.9..."
        fi

        # cd $KERNEL_DIR/KernelSU && git revert 898e9d4f8ca9b2f46b0c6b36b80a872b5b88d899
        # msg "Readding support for Non GKI kernels..."

	if [[ $KSU_MANAGER == "true" ]]; then
	    cd $WORKDIR/out/manager && wget -q https://nightly.link/tiann/KernelSU/workflows/build-manager/main/ksud-x86_64-unknown-linux-musl.zip
	    unzip ksud-x86_64-unknown-linux-musl.zip && mv x86_64-unknown-linux-musl/release/* .
	    mv *.apk manager.apk && chmod +x ksud
	    MANAGER_SIGNATURE=$(./ksud debug get-sign manager.apk)
	    MANAGER_EXPECTED_SIZE=$(echo "$MANAGER_SIGNATURE" | grep 'size:' | sed 's/.*size: //; s/,.*//')
	    MANAGER_EXPECTED_HASH=$(echo "$MANAGER_SIGNATURE" | grep 'hash:' | sed 's/.*hash: //; s/,.*//')
            msg "Backporting latest KSU manager..."
	fi
    fi

    if [[ ! -z "$MANAGER_EXPECTED_SIZE" ]] && [[ ! -z "$MANAGER_EXPECTED_HASH" ]]; then
	cd $KERNEL_DIR/KernelSU
	sed -i '/return check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH);/c\
        \    return (check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH) || check_v2_signature(path, '"$MANAGER_EXPECTED_SIZE"', "'"$MANAGER_EXPECTED_HASH"'"));' kernel/apk_sign.c
	msg "KSU_EXPECTED_SIZE := $MANAGER_EXPECTED_SIZE"
        msg "KSU_EXPECTED_HASH := $MANAGER_EXPECTED_HASH" && cd $WORKDIR
    fi

    if [[ $KERNELSU_REPO == "backslashxx/KernelSU" ]]; then
    	cp $WORKDIR/patches/KernelSU/Backport/hook_patches_xxksu-$KERNEL_VER.patch $KERNEL_DIR/
    	cd $KERNEL_DIR && patch -p1 -F 3 < hook_patches_xxksu-$KERNEL_VER.patch
    	msg "Importing scope minimized KSU hooks for $KERNEL_VER kernel..."
    else	
	cp $WORKDIR/patches/KernelSU/Backport/hook_patches_ksu-$KERNEL_VER.patch $KERNEL_DIR/
    	cd $KERNEL_DIR && patch -p1 < hook_patches_ksu-$KERNEL_VER.patch
    	msg "Importing KSU hooks for $KERNEL_VER kernel..."

    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/enable_susfs_for_ksu_auto.patch $KERNEL_DIR/KernelSU/
    	cd $KERNEL_DIR/KernelSU && patch -p1 -F 3 < enable_susfs_for_ksu_auto.patch
    	msg "Importing SuSFS into KSU source..."

    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/add_susfs_in_kernel-$KERNEL_VER.patch $KERNEL_DIR/
    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/susfs.c $KERNEL_DIR/fs/
    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/susfs.h $KERNEL_DIR/include/linux/
    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/sus_su.c $KERNEL_DIR/fs/
    	cp $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/sus_su.h $KERNEL_DIR/include/linux/
    	cd $KERNEL_DIR && patch -p1 -F 3 < add_susfs_in_kernel-$KERNEL_VER.patch 
    	msg "Importing SuSFS into $KERNEL_VER kernel..." && touch .susfs_patched
    fi

    cd $KERNEL_DIR
    if [[ ! -f "$WORKDIR/patches/KernelSU/Backport/hook_patches_ksu-$KERNEL_VER.patch" ]]; then
        echo "CONFIG_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
	echo "CONFIG_HAVE_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
	echo "CONFIG_KPROBE_EVENTS=y" >> $DEVICE_DEFCONFIG_FILE
        echo "CONFIG_KSU_SUSFS=y" >> $DEVICE_DEFCONFIG_FILE
        msg "Hook patches not found! Using kprobes..."
    else
    	echo "CONFIG_KSU=y" >> $DEVICE_DEFCONFIG_FILE
	echo "CONFIG_KSU_EXTRAS=y" >> $DEVICE_DEFCONFIG_FILE
	if [[ $KERNELSU_REPO != "backslashxx/KernelSU" ]]; then
    	    echo "CONFIG_KPROBES=n" >> $DEVICE_DEFCONFIG_FILE # it will conflict with KSU hooks if it's on
	    echo "CONFIG_KSU_SUSFS=y" >> $DEVICE_DEFCONFIG_FILE
	fi
    fi

    KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
    KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10200))
    msg "KernelSU Version: $KERNELSU_VERSION"

    if [[ -f "$KERNEL_DIR/.susfs_patched" ]]; then
    	SUSFS_VERSION=$(grep "SuSFS version:" $WORKDIR/patches/KernelSU/SuSFS/$KERNEL_VER/add_susfs_in_kernel-$KERNEL_VER.patch | cut -d' ' -f3)
    	msg "SuSFS version: $SUSFS_VERSION"
    fi
    sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$KERNEL_BRANCH-$KERNEL_NAME-κsu\"/" $DEVICE_DEFCONFIG_FILE
fi
if [[ $KSU_ENABLED == "false" ]]; then
    echo "KernelSU Disabled"
    cd $KERNEL_DIR
    echo "CONFIG_KSU=n" >> $DEVICE_DEFCONFIG_FILE
    echo "CONFIG_KPROBES=n" >> $DEVICE_DEFCONFIG_FILE # just in case KSU is left on by default

    KERNELSU_VERSION="Disabled"
    SUSFS_VERSION="Disabled"
    sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$KERNEL_BRANCH-$KERNEL_NAME\"/" $DEVICE_DEFCONFIG_FILE
fi
