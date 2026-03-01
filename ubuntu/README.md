# ubuntu setup

## nfs

/etc/exports
```
# /etc/exports: the access control list for filesystems which may be exported
#		to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/home/dragon/ 192.168.0.0/24(rw,sync,no_subtree_check,insecure,all_squash,anonuid=1000,anongid=1000)
/loki1-980-1tb/ 192.168.0.0/24(rw,sync,no_subtree_check,insecure,all_squash,anonuid=1000,anongid=1000)
/loki1-sa510-2tb 192.168.0.0/24(rw,sync,no_subtree_check,insecure,all_squash,anonuid=1000,anongid=1000)
```
```
sudo exportfs -ra
```

```
sudo systemctl enable --now nfs-kernel-server
```

## tmux

```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

## .vimrc

```
sudo apt install vim-gtk3
mkdir -p ~/.vim/undodir
```