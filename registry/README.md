# Minikube Registry Helper

An utility to minikube that can help push and pull from the minikube registry using custom domain names.  The custom domain names will be made resolveable from with in cluster and at minikube node.

[![asciicast](https://asciinema.org/a/254537.svg)](https://asciinema.org/a/254537)

## Start minikube

```shell
minikube profile demo
minikube start -p demo
```

> **Note**
>
>If you want to use `cri-0` as runtime then:
>
>```shell
> minikube start -p demo --container-runtime=cri-o
> ```

## Enable internal registry

```shell
minikube addons enable registry
```

Verifying the registry deployment

```shell
kubectl get pods -n kube-system
```

```shell
NAME                                        READY   STATUS    RESTARTS   AGE
coredns-576cbf47c7-q7xgf                    1/1     Running   0          4m25s
coredns-576cbf47c7-w9rxx                    1/1     Running   0          4m25s
default-http-backend-5957bfbccb-j8f7j       1/1     Running   0          4m24s
etcd-minikube                               1/1     Running   0          3m47s
kube-addon-manager-minikube                 1/1     Running   0          3m30s
kube-apiserver-minikube                     1/1     Running   0          3m43s
kube-controller-manager-minikube            1/1     Running   0          3m28s
kube-proxy-rcndv                            1/1     Running   0          4m25s
kube-scheduler-minikube                     1/1     Running   0          3m34s
nginx-ingress-controller-5bbcd969c5-5rzsx   1/1     Running   0          4m23s
registry-sg45m                              1/1     Running   0          4m24s
storage-provisioner                         1/1     Running   0          4m23s
```

```
kubectl get svc -n kube-system
```

```
NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
default-http-backend   NodePort    10.107.246.111   <none>        80:30001/TCP    4m54s
kube-dns               ClusterIP   10.96.0.10       <none>        53/UDP,53/TCP   5m1s
registry               ClusterIP   10.111.151.121   <none>        80/TCP          4m54s
```

>
> **NOTE:**
> Please make a note of the CLUSTER-IP of `registry` service


## Configure registry aliases

To be able to push and pull images from internal registry we need to make the registry entry in minikube node's **hosts** file and make them resolvable via **CoreDNS**

```shell
kubectl apply -n kube-system \
  -f registry-aliases-config.yaml \
  -f node-etc-hosts-update.yaml \
  -f patch-coredns-job.yaml
```

You can check the mikikube vm's `/etc/hosts` file for the registry aliases entries:

```shell
$ minikube ssh -- sudo cat /etc/hosts
127.0.0.1       localhost
127.0.1.1 demo
10.111.151.121  example.com
10.111.151.121  example.com
10.111.151.121  test.com
10.111.151.121  test.org
```

The above output shows that the Daemonset has added the `registryAliases` from the ConfigMap pointing to the internal registry's __CLUSTER-IP__.

## Update CoreDNS

The coreDNS would have been automatically updated by the patch-cordns-job. A successful job run will have coredns ConfigMap updated like:

```yaml
apiVersion: v1
data:
  Corefile: |-
    .:53 {
        errors
        health
        rewrite name example.com registry.kube-system.svc.cluster.local
        rewrite name example.org registry.kube-system.svc.cluster.local
        rewrite name test.com registry.kube-system.svc.cluster.local
        rewrite name test.org registry.kube-system.svc.cluster.local
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
```

To verify it run the following command:

```shell
kubectl get cm -n kube-system coredns -o yaml
```

Once you have successfully patched you can now push and pull from the registry using suffix `example.com`, `example.org`,`test.com` and `test.org`.

## Testing

You can verify the deployment end to end using the example [application](https://github.com/kameshsampath/minikube-registry-aliases-demo).

```shell
git clone https://github.com/kameshsampath/minikube-registry-aliases-demo
cd minikube-registry-aliases-demo
```

Make sure you set the docker context using `eval $(minikube -p demo docker-env)`

Deploy the application using [Skaffold](https://skaffold.dev):

```shell
skaffold dev --port-forward
```

Once the application is running try doing `curl localhost:8080` to see the `Hello World` response

You can also update [skaffold.yaml](./skaffold.yaml) and [app.yaml](.k8s/app.yaml), to use `test.org`, `test.com` or `example.org` as container registry urls, and see all the container image names resolves to internal registry, resulting in successful build and deployment.

> **NOTE**:
>
> You can also update [skaffold.yaml](./skaffold.yaml) and [app. yaml](.k8s/app.yaml), to use `test.org`, `test.com` or > `example.org` as container registry urls, and see all the > container image names resolves to internal registry, resulting in successful build and deployment.
