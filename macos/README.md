# mac setup

## nfs

/etc/auto_nfs
```
ubuntu-dragon -fstype=nfs,resvport,rw,bg,soft,intr,rsize=65536,wsize=65536 192.168.0.2:/home/dragon
ubuntu-loki1-980-1tb -fstype=nfs,resvport,rw,bg,soft,intr,rsize=65536,wsize=65536 192.168.0.2:/loki1-980-1tb
ubuntu-loki1-sa510-2tb -fstype=nfs,resvport,rw,bg,soft,intr,rsize=65536,wsize=65536 192.168.0.2:/loki1-sa510-2tb
```

/etc/auto_master
```
#
# Automounter master map
#
+auto_master            # Use directory service
#/net                   -hosts          -nobrowse,hidefromfinder,nosuid
/home                   auto_home       -nobrowse,hidefromfinder
/Network/Servers        -fstab
/-                      -static
/Users/dragon   auto_nfs
```

```
sudo automount -cv
```

```
~ showmount -e 192.168.0.2
Exports list on 192.168.0.2:
/home/dragon                        192.168.0.0/24
```

```
ln -s /mnt/nfs/ubuntu-dragon ~/ubuntu-dragon

ln -s /mnt/nfs/ubuntu-loki1-980-1tb ~/ubuntu-loki1-980-1tb

ln -s /mnt/nfs/ubuntu-loki1-sa510-2tb ~/ubuntu-loki1-sa510-2tb
```

## tmux

```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

## .vimrc

```
mkdir -p ~/.vim/undodir
```
