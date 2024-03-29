apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  annotations:
    kfctl.kubeflow.io/force-delete: "false"
  clusterName: kubeflow-workshop.cn-northwest-1.eksctl.io
  creationTimestamp: null
  name: kubeflow-workshop
  namespace: kubeflow
spec:
  applications:
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: namespaces/base
    name: namespaces
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: application/v3
    name: application
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/istio-1-3-1-stack
    name: istio-stack
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cluster-local-gateway-1-3-1
    name: cluster-local-gateway
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: istio/istio/base
    name: istio
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cert-manager-crds
    name: cert-manager-crds
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cert-manager-kube-system-resources
    name: cert-manager-kube-system-resources
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/cert-manager
    name: cert-manager
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: metacontroller/base
    name: metacontroller
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/oidc-authservice
    name: oidc-authservice
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/dex-auth
    name: dex
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: admission-webhook/bootstrap/overlays/application
    name: bootstrap
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: spark/spark-operator/overlays/application
    name: spark-operator
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws
    name: kubeflow-apps
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: aws/istio-ingress/base_v3
    name: istio-ingress
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: knative/installs/generic
    name: knative
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: kfserving/installs/generic
    name: kfserving
  - kustomizeConfig:
      repoRef:
        name: manifests
        path: stacks/aws/application/spartakus
    name: spartakus
  plugins:
  - kind: KfAwsPlugin
    metadata:
      creationTimestamp: null
      name: aws
    spec:
      auth:
        basicAuth:
          password: 12341234
          username: admin@kubeflow.org
      enablePodIamPolicy: false
      region: cn-northwest-1
  repos:
  - name: manifests
    uri: file:{FULL_PATH}/manifests-1.2.0.tar.gz
  version: v1.2-branch
status:
  reposCache:
  - localPath: '".cache/manifests/manifests-1.2.0"'
    name: manifests
  - localPath: '".cache/manifests/manifests-1.2.0"'
    name: manifests
  - localPath: '".cache/manifests/manifests-1.2.0"'
    name: manifests
  - localPath: '".cache/manifests/manifests-1.2.0"'
    name: manifests
  - localPath: '".cache/manifests/manifests-1.2.0"'
    name: manifests
  - localPath: '".cache/manifests/manifests-1.2.0"'
    name: manifests
  - localPath: '".cache/manifests/manifests-1.2.0"'
    name: manifests
