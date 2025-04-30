{ pkgs ? import <nixpkgs> {}  }:pkgs.mkShell {
  allowUnfree = true;
  packages = with pkgs; [
    kind
    kubectl
    jq
    awscli2
    crossplane-cli
    kubernetes-helm
  ];
}
