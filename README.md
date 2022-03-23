# corednssync
## Description
This repo can help syncing k8s coredns dns record to let you expose your ingress to k8s pods.

## Usage
I assume that you already had ingress and ingress controller ready.

If you depoly your cluster on bare-metal machine, you will probably having a nodeport service managed by ingress controller to expose your ingress service.
Find your NodePort service by using command
```
kubectl get svc -A
```

Should have something like this
(In my case, mine is `ingress-nginx` in namespace called `ingress-nginx` )
```
vp@vp-VirtualBox:~$ kubectl get svc -A
NAMESPACE       NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
default         kubernetes          ClusterIP   10.96.0.1        <none>        443/TCP                      12d
default         nginx-service-1     ClusterIP   10.100.250.246   <none>        8081/TCP                     21h
default         nginx-service-1-2   ClusterIP   10.99.221.106    <none>        8081/TCP                     17h
default         nginx-service-2     ClusterIP   10.107.167.22    <none>        8082/TCP                     21h
default         nginx-service-2-2   ClusterIP   10.111.186.204   <none>        8082/TCP                     17h
ingress-nginx   ingress-nginx       NodePort    10.111.151.160   <none>        80:30080/TCP,443:30443/TCP   18h
kube-system     kube-dns            ClusterIP   10.96.0.10       <none>        53/UDP,53/TCP,9153/TCP       12d
```

Grab the `service` and `servicenamespace` managed by ingress controller, and fill it into the deployment variable, that it.
