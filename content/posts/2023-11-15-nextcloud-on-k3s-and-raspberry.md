---
title: "Setting up NextCloud on Raspberry Pi 4 using k3s"
date: 2023-11-20T14:30:00+02:00
lastmod: 2023-11-20T21:40:00+02:00
draft: false
---

## Introduction

I was setting up a NextCloud instance on my Raspberry Pi 4, using k3s, and found
out that there are quite some step-by-step guides on how to do that, none of
them fully addressed all the issues I had, so I decided to write yet another
guide on how to that. Mostly for myself, but maybe it will be useful for someone
else. In particular, I faced the following issues:

- MetalLB switching to CRDs instead of config maps.
- Raspberry Pi not working well with MetalLB when using Wi-Fi.
- Longhorn on a single node.
- NextCloud HTTPS issue on Android client.
- And also solving some warnings that NextCloud explicitly warns about.

### Why Raspberry?

Because I have one and it is very energy efficient.

### Why k3s?

Because it is very lightweight and easy to set up. And when you have multiple
projects running on the same machine, managing them via Docker or Docker compose
becomes less convenient.

## Useful links

I mostly followed these guides, except for some specific problems:

- [Deploy Nextcloud on k3s](https://greg.jeanmart.me/2020/04/13/deploy-nextcloud-on-kuberbetes--the-self-hos/)
- [k3s rocks](https://k3s.rocks/install-setup)
- [Raspberry Pi k3s stories](https://gdha.github.io/pi-stories)

## Outline

1. [Install dependencies](#install-dependencies)
2. [Install k3s and set up access from a remote (client) machine](#remote-access)
3. [Install and set up Helm on a client machine](#helm)
4. [Install MetalLB](#metallb)
5. [Install Nginx ingress controller](#nginx)
6. [Install cert-manager](#cert-manager)
7. [Set up persistent storage with Longhorn](#longhorn})
8. [Install NextCloud](#nextcloud})

## 1. Install dependencies {#install-dependencies}

### General

At minimum, you'll need `curl` and `ssh`, which should be both already installed
and set up on your Raspberry Pi. However, it is probably a good idea to update
`ca-certificates`, install `open-iscsi` and `nfs-common` in case you decide to
use an NFS for storage, and install `wireguard` if you are going to use a
Wireguard as a flannel backend. This should not matter on a single-node, yet does not hurt to install them:

```bash
sudo apt update && sudo apt install -y \
	curl \
	ca-certificates \
	open-iscsi \
	wireguard \
	nfs-common
```

### Debian/Ubuntu specific

[Raspberry Pi OS](https://www.raspberrypi.com/software/) is Ubuntu-based, so it
makes sense to follow the recommended
[steps](https://docs.k3s.io/advanced#ubuntu--debian) for Ubuntu/Debian
distributions, which boils down to updating the default firewall rules:

```bash
ufw allow 6443/tcp # apiserver
ufw allow from 10.42.0.0/16 to any # pods
ufw allow from 10.43.0.0/16 to any # services
```

### Raspberry Pi specific

Append the `cgroups` as suggested
[here](https://docs.k3s.io/advanced#raspberry-pi). But unlike mentioned there,
they were in `/boot/firmware/cmdline.txt` not `/boot/cmdline.txt`. Also vim did
not work, so I used nano.

Thus, add
```text
cgroup_memory=1 cgroup_enable=memory
```
to `/boot/firmware/cmdline.txt`.

The resulting file can look something like this:

```text
console=serial0,115200 dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc quiet splash cgroup_memory=1 cgroup_enable=memory
```

There is also a Pi specific dependency for VXLAN (although it is probably better
to use Wireguard):

```bash
sudo apt install linux-modules-extra-raspi
```


## 2. Install k3s and set up remote access {#remote-access}

### Install k3s

Install k3s as suggested [here](https://docs.k3s.io/quick-start), but with some
[options](https://docs.k3s.io/installation/configuration):

```bash
curl -sfL https://get.k3s.io | sh -s  - \
	server \
	--cluster-init \
	--disable servicelb \
	--disable traefik \
	--flannel-backend wireguard-native \
	--write-kubeconfig-mode 644 \
  --tls-san [public IP address or hostname]
```

The command above installs and sets up a k3s server, but

- Disables ServiceLB because we will use MetalLB instead.
- Disables Traefik because we will use Nginx ingress controller instead.
- Sets up Wireguard as a flannel backend. This is should not really matter as
  long you are using a single node cluster.
- Sets `/etc/rancher/k3s/k3s.yaml` to 644 mode (`-rw-r--r--`).

Check that k3s server is up and running:

```bash
systemctl status k3s
```

Check that nodes and pods are running, and verify that there is no Traefik or
ServiceLB:

```bash
kubectl get nodes -A -o wide
kubectl get pods -A -o wide
```

### Set up remote access

Copy the `/etc/rancher/k3s/k3s.yaml` file to your client machine

```bash
scp raspberry.example.com:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

where `raspberry.example.com` is the public IP address or the hostname of your
Raspberry.

Then change the `clusters[0].server` (there should be just one cluster at this
point) from `https://127.0.0.1:6443` to `https://raspberry.example.com:6443`. If
you are trying to access it outside of your network, make sure you have set up
the port forwarding to port 6443 on the Raspberry Pi.

Alternatively, you can copy `k3s.yaml` to any other location, but then you'll
need to set the `KUBECONFIG` environment variable to point to that file, or
explicitly use the `--kubeconfig` parameter with `kubectl`.

Check that you can access the cluster:

```bash
kubectl get nodes -A -o wide
```

## 3. Install Helm {#helm}

Install it via an official [installation script](https://helm.sh/docs/intro/install/#from-script):

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

or using a package manager, e.g.,

```bash
brew install helm
```

or

```bash
sudo pacman -S helm
```

or any other suitable package manager.

## 4. Install MetalLB {#metallb}

Here, I am mostly following
[Greg's tutorial](https://greg.jeanmart.me/2020/04/13/install-and-configure-a-kubernetes-cluster-w/),
but some things have changed since it was written. It particular:

- Helm's stable channel was [archived](https://github.com/helm/charts).
- There were
  [breaking changes](https://metallb.universe.tf/release-notes/#version-0-13-2)
  in MetalLB version 0.13: it uses CRDs instead of config maps now. There are
  [instructions](https://metallb.universe.tf/configuration/migration_to_crds/)
  for migrating though.

Add and update MetalLB repo:

```bash
helm repo add metallb https://metallb.github.io/metallb
helm repo update
```

Install MetalLB:

```bash
helm install metallb metallb/metallb --namespace kube-system
```

Wait until all the pods are initialized and running:

```bash
kubectl get pods -A -o wide
```

Then create `config.yaml`, which specifies the address pool and L2 advertisement.
Address pool should be:

- inside your subnet,
- but outside of the DHCP server address pool, otherwise there might be
  conflicts.

For example, if your subnet is `192.168.97.0/24` and your DHCP server address
pool is `192.168.97.200-192.168.97.250`, you could use a pool like
`192.168.97.10-192.168.97.50`.

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: kube-system
spec:
  addresses:
  - 192.168.97.10-192.168.97.50
status: {}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: kube-system
spec:
  ipAddressPools:
  - default
status: {}
```

Apply these configs:

```bash
kubectl apply -f config.yaml
```

Check that everything is running:

```bash
kubectl get pods -n kube-system -o wide
```

### Fix MetalLB on Raspberry Pi when using Wi-Fi

Most tutorials are setting up MetalLB in ARP mode. It seems that most of them
are also using a wired connection, because they never mention the issue with
unstable connections.

In summary, the issue is that when when everything is set up, you can always
access your applications from Raspberry (using local IP), often from another
machine in the same network (using local IP), and sometimes from outside of the
network using public IP. To make matters worse, when trying to debug it with
`tcpdump`, the issue disappears, making an impression that there are some
quantum processes involved, which behave differently when observed. In reality,
of course, everything is simpler: when using `tcpdump` or other package
sniffers, you put the network interface in promiscuous mode. And the solution to
this issue is to put the network interface in promiscuous mode all the time.

Here are some links discussing the issue and offering potential solutions:

-
  [Reddit thread](https://www.reddit.com/r/kubernetes/comments/ga5ud9/metallb_externalip_can_not_access_from_network/)
  discussing the issue.
- [MetalLB issue](https://github.com/metallb/metallb/issues/253) on GitHub:
  layer2 mode doesn't receive broadcast packets on VM unless promiscuous mode is
  enabled.
- [MetalLB issue](https://github.com/metallb/metallb/issues/535) on GitHub: L2
  mode multiple replicas is not working with the bridge until promiscuous mode
  enabled.
- [Raspberry Pi OS issue](https://github.com/raspberrypi/linux/issues/2677) on
  GitHub: Wifi interface replies on arp requests only in promiscuous mode.
- [MetalLB issue](https://github.com/metallb/metallb/issues/284) on GitHub:
  Layer 2 mode on RPi.

My solution was to put the network interface in promiscuous, as suggested in
some of the links above:

```bash
ip link set wlan0 promisc on
```

However, this does not persist across boots, so I have also added a crontab entry:

```crontab
@reboot ip link set wlan0 promisc on
```

## 5. Install Nginx ingress controller {#nginx}

Following [these steps](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx), add and update the repo:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Create `values.yaml` overriding some default values:

```yaml
defaultBackend:
  enabled: false
controller:
  allowSnippetAnnotations: true
  service:
    loadBalancerIP: 192.168.97.10
```

The config above:

- Disables
  [default backed](https://kubernetes.github.io/ingress-nginx/user-guide/default-backend/),
- Allows snippet annotations, to be able to specify
  `nginx.ingress.kubernetes.io/server-snippet` annotations in ingress configs,
- Sets the IP address of the controller for easier port-forwarding on the router
  (this is, of course, optional, but makes things easier).

Note that `loadBalancerIP` should be from the available pool defined in MetalLB.
You can skip it and get a random allocation, but then port forwarding on the
router should be changed to account for an actual IP. E.g., if MetalLB uses a
pool `192.168.97.10-192.168.97.50`, then we can use `192.168.97.10` as a
`loadBalancerIP`.

Then install using a Helm chart with overridden values:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
	--namespace kube-system \
	-f values.yaml
```

Check that everything was deployed

```bash
kubectl get pods -n kube-system -o wide
kubectl get services  -n kube-system -o wide
```

Check that it's working by running `curl` on the public IP of the following command:

```bash
kubectl get services -n kube-system -o wide -w ingress-nginx-controller
```

E.g., in this case this should be `192.168.97.10`:

```bash
curl 192.168.97.10
```

It should return an Nginx with a 404 error page.

It makes sense, at this stage, to set up port forwarding on your router,
pointing to ports 80 and 443 of your ingress controller (i.e, not Raspberry Pi
IP, but the one we have just used).

## 6. Install cert-manager {#cert-manager}

Add the repo

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

Install

```bash
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.1 \
  --set installCRDs=true
```

Check that pods are running

```
kubectl get pods --namespace cert-manager
```

Create a cluster issuer following
[these steps](https://cert-manager.io/docs/configuration/acme/http01/). It makes
sense to create two cluster issuers:
[staging](https://letsencrypt.org/docs/staging-environment/) and prod, because
Let's Encrypt have different rate limits for staging and prod services.
`config.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: admin@nextcloud.example.com # change this
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: admin@nextcloud.example.com # change this
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply this config:

```bash
kubectl apply -f config.yaml
```

Check that it worked:

```bash
kubectl describe clusterissuer letsencrypt-staging -n cert-manager
kubectl describe clusterissuer letsencrypt-prod -n cert-manager
```

## 7. Set up persistent storage with Longhorn {#longhorn}

Using Longhorn is definitely an overkill for a single node cluster, but although
it creates a level of complexity, it also removes some other pain points, so
we'll set it up. Alternatively, one can use
[persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
and persistent volume claims directly.

Follow
[these steps](https://longhorn.io/docs/1.4.1/deploy/install/install-with-helm/)
to install it using Helm. First, add the repo

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

Then change the values in `values.yaml`:

```yaml
defaultSettings:
  defaultReplicaCount: 1
  defaultDataPath: [path on the host machine]
  replicaSoftAntiAffinity: false
  replicaDiskSoftAntiAffinity: false
ingress:
   annotations:
     cert-manager.io/cluster-issuer: "letsencrypt-staging" # maybe, change later
   host: longhorn.nextcloud.example.com # change this
   ingressClassName: nginx
   tls: true
   tlsSecret: longhorn-tls
longhornUI:
  replicas: 1
persistence:
  defaultClassReplicaCount: 1
csi:
  attacherReplicaCount: 1
  provisionerReplicaCount: 1
  resizerReplicaCount: 1
  snapshotterReplicaCount: 1
```

The config above does the following things:

- Sets all replicas to 1, because we are using a single node cluster with a
  single hard drive.
- Turns off anti-affinity. Anti-affinity tries to place replicas on different
  nodes or drives, but since we have only one node, there is no point in this.
- Specifies the path on the host machine (our Raspberry Pi).
- Sets up ingress and TLS using the staging issuer: we'll switch to prod
  issuers, once the whole set up is working.

Then install

```bash
helm install longhorn longhorn/longhorn \
	--namespace longhorn-system \
	--create-namespace \
	--version 1.5.1 \
	-f values.yaml
```

and check that it's working

```bash
kubectl get pods -n longhorn-system
kubectl get services -n longhorn-system -o wide
```

You can also check out GUI, by creating a port forwarding

```bash
kubectl port-forward service/longhorn-frontend 8081:80 -n longhorn-system
```

and accessing it on `localhost:8081`.

## 8. Install NextCloud {#nextcloud}

Mostly following [k3s.rocks](https://k3s.rocks/localstorage-longhorn/) here.

First, add the repo

```bash
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update
```

And edit `values.yaml` (run `helm show values nextcloud/nextcloud > values.yaml`
for the default values.):

```yaml
replicaCount: 1

ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 4G
    kubernetes.io/tls-acme: "true"
    cert-manager.io/cluster-issuer: letsencrypt-staging # change later
    nginx.ingress.kubernetes.io/server-snippet: |-
      server_tokens off;
      proxy_hide_header X-Powered-By;
      rewrite ^/.well-known/webfinger /index.php/.well-known/webfinger last;
      rewrite ^/.well-known/nodeinfo /index.php/.well-known/nodeinfo last;
      rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
      rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json;
      location = /.well-known/carddav {
        return 301 $scheme://$host/remote.php/dav;
      }
      location = /.well-known/caldav {
        return 301 $scheme://$host/remote.php/dav;
      }
      location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
      }
      location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
        deny all;
      }
      location ~ ^/(?:autotest|occ|issue|indie|db_|console) {
        deny all;
      }
  tls:
    - secretName: nextcloud-tls
      hosts:
        - nextcloud.example.com # change this
  labels: {}
  path: /
  pathType: Prefix

phpClientHttpsFix:
  enabled: true
  protocol: https

nextcloud:
  host: nextcloud.example.com # change this
  username: admin # change this
  password: changeme # change this
  configs:
    proxy.config.php: |-
      <?php
      $CONFIG = array (
        'trusted_proxies' => array(
          0 => '127.0.0.1',
          1 => '10.0.0.0/8',
        ),
        'forwarded_for_headers' => array('HTTP_X_FORWARDED_FOR'),
      );

persistence:
  enabled: true
  storageClass: "longhorn"
  accessMode: ReadWriteOnce
  size: 10Gi

  nextcloudData:
    enabled: true
    storageClass: "longhorn"
    accessMode: ReadWriteOnce
    size: 50Gi
```

The config above does the following things:

- Sets the replica count to 1.
- Sets up ingress with TLS using the staging issuer.
- Fixes the HTTPS issue (I notices only when trying to set up connection on an
  Android device).
- Fixes the untrusted proxy warning.
- Creates a default user with a password.
- Sets up persistent storage claims using Longhorn: a disk for NextCloud, and a
  disk for data.

Then, create a namespace and install:

```bash
kubectl create namespace nextcloud
helm install nextcloud nextcloud/nextcloud \
  --namespace nextcloud \
  --values values.yaml
```

Check that pods are running:

```bash
kubectl get pods -n nextcloud
kubectl get services -n nextcloud -o wide
```

And check that certificates were issued (this might take a few minutes):

```bash
kubectl get certificaterequest -n nextcloud -o wide
kubectl get certificate -n nextcloud -o wide
```

If certificates were issued succesfully and you can access NextCloud on
`nextcloud.example.com` (assuming you set all the port forwarding on your NAT
correctly), you can switch to prod issuers by changing the following, and then run:

```bash
helm upgrade nextcloud nextcloud/nextcloud \
  --namespace nextcloud \
  --values values.yaml
```

You can also do the same for Longhorn UI, if you are planning to access it remotely.

## Enjoy

It should be up and running.
