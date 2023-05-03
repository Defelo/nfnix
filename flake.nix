{
  outputs = {...}: {
    lib = let
      split = sep: s: builtins.filter builtins.isString (builtins.split sep s);
      repeat = w: s: builtins.concatStringsSep "" (builtins.genList (_: s) w);
      indent = w: s: builtins.concatStringsSep "\n" (map (l: (repeat w " ") + l) (split "\n" s));
      addNames = x:
        if builtins.isAttrs x
        then map (name: x.${name} // {inherit name;}) (builtins.attrNames x)
        else x;
      flatten = builtins.foldl' (acc: x:
        acc
        ++ (
          if builtins.isList x
          then flatten x
          else [x]
        )) [];
    in rec {
      mkChain = {
        name,
        type ? null,
        hook ? null,
        priority ? let
          prios = {
            prerouting = -100;
            postrouting = 100;
          };
        in
          if type != null && hook != null
          then
            if builtins.hasAttr hook prios
            then prios.${hook}
            else 0
          else null,
        policy ? null,
        rules ? [],
      }: let
        h1 =
          if type != null && hook != null
          then "type ${type} hook ${hook}${
            if priority != null
            then " priority ${toString priority}"
            else ""
          };"
          else "";
        h =
          if h1 != "" && policy != null
          then "${h1} policy ${policy};"
          else h1;
        r =
          (
            if h != ""
            then [h]
            else []
          )
          ++ (flatten rules)
          ++ (
            if h == "" && policy != null
            then [policy]
            else []
          );
      in ''
        chain ${name} {
        ${indent 2 (builtins.concatStringsSep "\n" r)}
        }'';
      mkTable = {
        family ? null,
        name,
        chains ? [],
      }: ''
        table ${
          if builtins.isNull family
          then ""
          else "${family} "
        }${name} {
        ${indent 2 (builtins.concatStringsSep "\n" (map mkChain (addNames chains)))}
        }'';
      mkRuleset = {tables ? []}: builtins.concatStringsSep "\n" (map mkTable (addNames tables));

      vmap = x: "vmap { ${builtins.concatStringsSep ", " (map (k: "${k} : ${x.${k}}") (builtins.attrNames x))} }";
      iifname_jump = f: x: "iifname ${vmap (builtins.listToAttrs (map (name: {
          inherit name;
          value = "jump ${f name}";
        })
        x))}";

      ct_state = "ct state vmap { related : accept, established : accept, invalid : drop }";
      icmpv6 = "icmpv6 type { nd-neighbor-solicit, nd-router-advert, nd-neighbor-advert } accept";
      allow_icmp_pings = [
        "icmp type echo-request accept"
        "icmpv6 type echo-request accept"
      ];
      default_input = [ct_state icmpv6];
      default_forward = [ct_state];
    };
  };
}
