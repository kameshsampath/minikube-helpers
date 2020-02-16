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

To test test the setup you can use the example app, when deploys a [Tekton](https://tekton.dev) task and run to build a simple hello world image.

### Deploy Tekton pipelines

```shell
kubectl apply --filename https://storage.googleapis.com/tekton-releases/latest/release.yaml
```

Wait for the tekton-pipelines pods to be up and running.

>
> **NOTE:**
> You can watch the status using the command `kubectl get pods --namespace tekton-pipelines -w`, use CTRL+C to terminate the watch.

Once tekton pipelines is up you can build and deploy the hello world app:

```shell
kubectl apply --filename example/build-resources.yaml
kubectl apply --filename example/build.yaml
```

If all our configurations are right then you should have a deployment called `helloworld` up and running. If you examine the deployment YAML `kubectl get deployment helloworld -oyaml`, it will be using the image from `dev.local`- which is the alias we configured for the internal registry.

>
> **NOTE:**
> The first build might take time as the images will pulled for the first time

## Cleanup

```shell
kubectl delete --filename example/build-resources.yaml \
  --filename example/build.yaml
kubectl delete --filename example/deployment.yaml  \
  --filename example/service.yaml
```
