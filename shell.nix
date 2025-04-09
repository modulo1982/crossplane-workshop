{ pkgs ? import <nixpkgs> {}  }:pkgs.mkShell {
  allowUnfree = true;
  packages = with pkgs; [
    gum
    gh
    kind
    kubectl
    yq-go
    jq
    awscli2
    upbound
    teller
    crossplane-cli
    kubernetes-helm
  ];
}
