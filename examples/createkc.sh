kubectl get secret platform-ref-azure-akscluster -o jsonpath='{.data.kubeconfig}' | base64 -d > $1
