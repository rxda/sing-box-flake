{
  description = "Sing-box Latest Release Flake (Auto-updated by GitHub Actions)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sing-box-src = {
      # ！！！格式警告：修改此 URL 会导致 GitHub Action 匹配失败 ！！！
      url = "github:SagerNet/sing-box/v1.13.0-rc.2";
      flake = false;
    };
  };

  # 允许使用者自动获取你的二进制缓存
  nixConfig = {
    extra-substituters = [ "https://rxda-cache.cachix.org" ];
    extra-trusted-public-keys = [ "rxda-cache.cachix.org-1:LDGrYaB+dF7wh+uWMLjh5VsckzFnnCyGkMH1sKHN++g=" ];
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      # 支持 x86 和 ARM 架构
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.buildGoModule rec {
            pname = "sing-box";
            # ！！！格式警告：修改此变量名会导致 GitHub Action 匹配失败 ！！！
            version = "1.13.0-rc.2";

            src = inputs.sing-box-src;

            # 多个实验特性用逗号隔开
            GOEXPERIMENT = "greenteagc,jsonv2";

            # 同时也需要在处理依赖阶段开启，否则 vendorHash 可能会在本地和 CI 环境不一致
            overrideModAttrs = (_: {
              GOEXPERIMENT = "greenteagc,jsonv2";
            });

            # 哈希会自动被 GitHub Action 里的脚本更新
            vendorHash = "sha256-Qj2+1Lht6lEEC1ve/hTZiE/NhJwf0KKiFqr1FfDxjsQ=";

            # 包含所有增强特性
            tags = [
              "with_quic"
              "with_dhcp"
              "with_wireguard"
              "with_utls"
              "with_acme"
              "with_clash_api"
              "with_gvisor"
              "with_tailscale"
            ];

            subPackages = [ "cmd/sing-box" ];

            nativeBuildInputs = [ pkgs.installShellFiles ];

            ldflags = [
              "-X github.com/sagernet/sing-box/constant.Version=${version}"
            ];

            # 保持与官方包一致的收尾工作（补全脚本和服务文件）
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
        });

      # 提供 Overlay 选项，虽然你现在直接引用 packages，但留着是个好习惯
      overlays.default = final: prev: {
        sing-box-unstable = self.packages.${final.system}.default;
      };
    };
}
