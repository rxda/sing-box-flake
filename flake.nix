{
  description = "Sing-box latest/beta auto-update flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sing-box-src = {
      url = "github:SagerNet/sing-box/dev-next"; # 追踪 main 分支获取最新代码
      flake = false;
    };
  };

  nixConfig = {
    # 使用 extra- 前缀，这样它会追加到现有缓存列表，而不是覆盖它们
    extra-substituters = [ "https://rxda-cache.cachix.org" ];
    extra-trusted-public-keys = [ "rxda-cache.cachix.org-1:LDGrYaB+dF7wh+uWMLjh5VsckzFnnCyGkMH1sKHN++g=" ];
  };

  outputs = { self, nixpkgs, sing-box-src, inputs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # 参考官方定义的构建函数
          sing-box-package = pkgs.buildGoModule rec {
            pname = "sing-box";
            # 动态获取版本号，或者写死为 latest-git
            version = "unstable-${inputs.sing-box-src.lastModifiedDate}";

            src = sing-box-src;

            # deleteVendor = true;
            # 重点：对于自动化仓库，vendorHash 会随代码变动
            # 我们在 Github Action 里会自动更新这个哈希
            vendorHash = "sha256-fCwERlWIgeu5n9Eav/DlnneVKkvk+T6J09hFRC/7Sqg=";

            tags = [
              "with_quic"
              "with_dhcp"
              "with_wireguard"
              "with_utls"
              "with_acme"
              "with_clash_api"
              "with_gvisor"
              "with_tailscale" # 包含你想要的 1.13+ tailscale 特性
            ];

            subPackages = [ "cmd/sing-box" ];

            nativeBuildInputs = [ pkgs.installShellFiles ];

            ldflags = [
              "-X=github.com/sagernet/sing-box/constant.Version=${version}"
            ];

            # 保留官方的补全和系统服务处理
            postInstall = ''
              installShellCompletion release/completions/sing-box.{bash,fish,zsh}

              substituteInPlace release/config/sing-box{,@}.service \
                --replace-fail "/usr/bin/sing-box" "$out/bin/sing-box" \
                --replace-fail "/bin/kill" "${pkgs.coreutils}/bin/kill"
              install -Dm444 -t "$out/lib/systemd/system/" release/config/sing-box{,@}.service

              install -Dm444 release/config/sing-box.rules $out/share/polkit-1/rules.d/sing-box.rules
              install -Dm444 release/config/sing-box-split-dns.xml $out/share/dbus-1/system.d/sing-box-split-dns.conf
            '';
          };
        in
        {
          default = sing-box-package;
        });

      # 提供 Overlay 供主配置使用
      overlays.default = final: prev: {
        sing-box-beta = self.packages.${final.system}.default;
      };
    };
}
