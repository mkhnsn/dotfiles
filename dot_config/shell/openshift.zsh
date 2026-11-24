# OpenShift Local (CRC) for the client engagement. Deployed only on dev_openshift
# machines (.chezmoiignore.tmpl); env.zsh sources it when it's there.
if command -v oc >/dev/null 2>&1; then
  export KUBECONFIG="$HOME/.kube/config"   # ~/.kube -> the Windows .kube (symlink)
  alias k=oc
  alias kubectl=oc
fi
alias ansiblevenv='source ~/ansible-venv/bin/activate'
