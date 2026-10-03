{
  actioncable = {
    dependencies = ["actionpack" "activesupport" "nio4r" "websocket-driver" "zeitwerk"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nn30fnsbqhx3yyy6vf7wxcqz3fnv7rkrbi010b5414119gqshmd";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  actionmailbox = {
    dependencies = ["actionpack" "activejob" "activerecord" "activestorage" "activesupport" "mail" "net-imap" "net-pop" "net-smtp"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cgpq8xn5apfrx89pc3phwcayqvhy10kb0sm8pqsaiy1isnminfy";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  actionmailer = {
    dependencies = ["actionpack" "actionview" "activejob" "activesupport" "mail" "net-imap" "net-pop" "net-smtp" "rails-dom-testing"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wyj251glxf2n00k6yc29r8dbys9b03mr8x5knd2kgb6xhh68zxh";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  actionpack = {
    dependencies = ["actionview" "activesupport" "cgi" "nokogiri" "racc" "rack" "rack-session" "rack-test" "rails-dom-testing" "rails-html-sanitizer"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1sq328ark8wa4c8x3y3nsv9qfysjbnn3bv8ily83dz6wdyijv91z";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  actiontext = {
    dependencies = ["actionpack" "activerecord" "activestorage" "activesupport" "globalid" "nokogiri"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rky5702sixkxb04fmpsyycqdv49kpn7nsl68v5whz6n5m15gmkr";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  actionview = {
    dependencies = ["activesupport" "builder" "cgi" "erubi" "rails-dom-testing" "rails-html-sanitizer"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rpmxm1vvga9jjym371h9q26wi4gdxf80xra5c3awr84z60ps50i";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  activejob = {
    dependencies = ["activesupport" "globalid"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fyc5paw29kwc6v5mqvpvd8354y3c4z3l8nrkls0hij93l2wvn8d";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  activemodel = {
    dependencies = ["activesupport"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "08g7lar9g9bqlvmhyc8bsvp0kzs18hhqiz1zksbbaq5530052bzp";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  activerecord = {
    dependencies = ["activemodel" "activesupport" "timeout"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0yghfgk627mc5gf5p549ilhs2hvjs5ms81dvkrixhzn9gz6ri8hs";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  activestorage = {
    dependencies = ["actionpack" "activejob" "activerecord" "activesupport" "marcel"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "167k9fgv7ymvrk737mf5zwfl8za7qhxajgdwkhypifljcn7cn6ig";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  activesupport = {
    dependencies = ["base64" "benchmark" "bigdecimal" "concurrent-ruby" "connection_pool" "drb" "i18n" "logger" "minitest" "mutex_m" "securerandom" "tzinfo"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0z1szpkxgxkq4ckgl4n51y2g3bi9f5a3wri2lci4j71vh45184kz";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  ast = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10yknjyn0728gjn6b5syynvrvrwm66bhssbxq8mkhshxghaiailm";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.4.3";
  };
  base64 = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0yx9yn47a8lkfcjmigk79fykxvr80r4m1i35q82sxzynpbm7lcr7";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.3.0";
  };
  benchmark = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0v1337j39w1z7x9zs4q7ag0nfv4vs4xlsjx2la0wpv8s6hig2pa6";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.5.0";
  };
  bigdecimal = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0612spks81fvpv2zrrv3371lbs6mwd7w6g5zafglyk75ici1x87a";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.3.1";
  };
  bootsnap = {
    dependencies = ["msgpack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14qb2gy6ypnqri92v9x8szbq7fzw27pc1z5cl367n5f5cpd2rmks";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.20.1";
  };
  builder = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pw3r2lyagsxkm71bf44v5b74f7l9r7di22brbyji9fwz791hya9";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.3.0";
  };
  byebug = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "07hsr9zzl2mvf5gk65va4smdizlk9rsiz8wwxik0p96cj79518fl";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "12.0.0";
  };
  cgi = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fzqwshg1xzbdm97havskfp6wifsgbjii00dzba0y6bih4lk1jk1";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.5.2";
  };
  coderay = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0jvxqxzply1lwp7ysn94zjhh57vc14mcshw1ygw14ib8lhc00lyw";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.1.3";
  };
  concurrent-ruby = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qfi2ns3zwkgq616fc127xiqhan7g7m7gqpwriwcr34nds1vxwdj";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.3.8";
  };
  connection_pool = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1b8nlxr5z843ii7hfk6igpr5acw3k2ih9yjrgkyz2gbmallgjkz5";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.5.5";
  };
  crass = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15djj19ynz3sbw54fsf8n7y3sha8a333f2mgvjfwhr46jhcqg1ll";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.0.7";
  };
  date = {
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1h0db8r2v5llxdbzkzyllkfniqw9gm092qn7cbaib73v9lw0c3bm";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.5.1";
  };
  debug = {
    dependencies = ["irb" "reline"];
    groups = ["development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1djjx5332d1hdh9s782dyr0f9d4fr9rllzdcz2k0f8lz2730l2rf";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.11.1";
  };
  diff-lcs = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qlrj2qyysc9avzlr4zs1py3x684hqm61n4czrsk1pyllz5x5q4s";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.6.2";
  };
  docile = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "07pj4z3h8wk4fgdn6s62vw1lwvhj0ac0x10vfbdkr9xzk7krn5cn";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.4.1";
  };
  drb = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wrkl7yiix268s2md1h6wh91311w95ikd8fy8m5gx589npyxc00b";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.2.3";
  };
  dry-core = {
    dependencies = ["concurrent-ruby" "logger" "zeitwerk"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18cn9s2p7cbgacy0z41h3sf9jvl75vjfmvj774apyffzi3dagi8c";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.2.0";
  };
  dry-inflector = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0blgyg9l4gpzhb7rs9hqq9j7br80ngiigjp2ayp78w6m1ysx1x92";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.2.0";
  };
  dry-logic = {
    dependencies = ["bigdecimal" "concurrent-ruby" "dry-core" "zeitwerk"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18nf8mbnhgvkw34drj7nmvpx2afmyl2nyzncn3wl3z4h1yyfsvys";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.6.0";
  };
  dry-struct = {
    dependencies = ["dry-core" "dry-types" "ice_nine" "zeitwerk"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wc07v0qm8zbblr74w3iy2s74sxpifyfpw9b2x01a9259icnhf03";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.8.1";
  };
  dry-types = {
    dependencies = ["bigdecimal" "concurrent-ruby" "dry-core" "dry-inflector" "dry-logic" "zeitwerk"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1g61cnmmwzff05sf8bh95qjd3hikasgvrmf3q0qk29zdw12pmndm";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.8.3";
  };
  erb = {
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14pfj6zn0p1hxj6s6s0r7d424wap8zl9zxf89nj79y8fbg16vjn5";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "6.0.7";
  };
  erubi = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1naaxsqkv5b3vklab5sbb9sdpszrjzlfsbqpy7ncbnw510xi10m0";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.13.1";
  };
  event_stream_parser = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1j73glgif3f97q3znq9ih67h5i7zd1wqzj2d33w8cqhjf2mkns52";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.0.0";
  };
  factory_bot = {
    dependencies = ["activesupport"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0xz02xlnfhj418g51w06asfpcjccf7b66dx6ly3c1k2d45rv7ghj";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "6.5.6";
  };
  factory_bot_rails = {
    dependencies = ["factory_bot" "railties"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0s3dpi8x754bwv4mlasdal8ffiahi4b4ajpccnkaipp4x98lik6k";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "6.5.1";
  };
  faker = {
    dependencies = ["i18n"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rfp6y0pc2slv83vcnayiypfjsanja5qg9wfm6wwq5dvq0nlhqdr";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.5.3";
  };
  faraday = {
    dependencies = ["faraday-net_http" "json" "logger"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0vmb5wpiz7mf2r6vjvhvfp38rrfvqjzmv7m3max0s6v28j641d4v";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.14.4";
  };
  faraday-multipart = {
    dependencies = ["multipart-post"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0mzp9rlqiryyi99bm9ii80hfsbbafh9wl8r3c5pif51pd54sk2bx";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.2.0";
  };
  faraday-net_http = {
    dependencies = ["net-http"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "125m3qri52vwh5v9dhq0dkqxf8629cxrf99yyc01pva72wasyy0f";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.4.4";
  };
  globalid = {
    dependencies = ["activesupport"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04gzhqvsm4z4l12r9dkac9a75ah45w186ydhl0i4andldsnkkih5";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.3.0";
  };
  guess_html_encoding = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16700fk6kmif3q3kpc1ldhy3nsc9pkxlgl8sqhznff2zjj5lddna";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.0.11";
  };
  htmlcompressor = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "17hzzg7alnmalb1xgv1bgw3aj5wczsijhq6c945kymkbsj7cyc26";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.4.0";
  };
  httpclient = {
    dependencies = ["mutex_m"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1j4qwj1nv66v3n9s4xqf64x2galvjm630bwa5xngicllwic5jr2b";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.9.0";
  };
  i18n = {
    dependencies = ["concurrent-ruby"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1994i044vdmzzkyr76g8rpl1fq1532wf0sb21xg5r1ilj5iphmr8";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.14.8";
  };
  ice_nine = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nv35qg1rps9fsis28hz2cq2fx1i96795f91q4nmkm934xynll2x";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.11.2";
  };
  io-console = {
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1k0lk3pwadm2myvpg893n8jshmrf2sigrd4ki15lymy7gixaxqyn";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.8.2";
  };
  irb = {
    dependencies = ["pp" "rdoc" "reline"];
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01h8bdksg0cr8bw5dhlhr29ix33rp822jmshy6rdqz4lmk4mdgia";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.16.0";
  };
  json = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "11prr7nrxh1y4rfsqa51gy4ixx63r18cz9mdnmk0938va1ajf4gy";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.18.1";
  };
  language_server-protocol = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1w5p8c2145lmqzr25bxh4ikzjm6k8y1k5lriqqdpw9pq730w1wjy";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.17.0.6";
  };
  lint_roller = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "11yc0d84hsnlvx8cpk4cbj6a4dz9pk0r1k29p0n1fz9acddq831c";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.1.0";
  };
  logger = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "00q2zznygpbls8asz5knjvvj2brr3ghmqxgr83xnrdj4rk3xwvhr";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.7.0";
  };
  loofah = {
    dependencies = ["crass" "nokogiri"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "062r891hxis58j5q735kk9sj5srxx0rv813f8m95bilsjm3gf1r0";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.25.2";
  };
  mail = {
    dependencies = ["logger" "mini_mime" "net-imap" "net-pop" "net-smtp"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1s30l5z7jkazgi4m6l6mh80rgsyhh2pp1pa5h70xclsj8z54wmq6";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.9.1";
  };
  marcel = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1xqlhq0z001b1h2i6hr7x0nrmszrd2aii1w8li1lm4gw2j45gsqn";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.1.1";
  };
  method_source = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1igmc3sq9ay90f8xjvfnswd1dybj1s3fi0dwd53inwsvqk4h24qq";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.1.0";
  };
  mini_mime = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vycif7pjzkr29mfk4dlqv3disc5dn0va04lkwajlpr1wkibg0c6";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.1.5";
  };
  mini_portile2 = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "12f2830x7pq3kj0v8nz0zjvaw02sv01bqs1zwdrc04704kwcgmqc";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.8.9";
  };
  minitest = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1mbpz92ml19rcxxfjrj91gmkif9khb1xpzyw38f81rvglgw1ffrd";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "5.27.0";
  };
  msgpack = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fhpfl9fznn6wi39xh05crswigywvyiw3rn0cbjf7prmgfm9whcp";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.8.5";
  };
  multipart-post = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a5lrlvmg2kb2dhw3lxcsv6x276bwgsxpnka1752082miqxd0wlq";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.4.1";
  };
  mutex_m = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0l875dw0lk7b2ywa54l0wjcggs94vb7gs8khfw9li75n2sn09jyg";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.3.0";
  };
  net-http = {
    dependencies = ["uri"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15k96fj6qwbaiv6g52l538ass95ds1qwgynqdridz29yqrkhpfi5";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.9.1";
  };
  net-imap = {
    dependencies = ["date" "net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0q1nq8mx22v9sn1296s45nm6dni42y3m3s1f4pg5dn3mx4xmgjdm";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.6.7";
  };
  net-pop = {
    dependencies = ["net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wyz41jd4zpjn0v1xsf9j778qx1vfrl24yc20cpmph8k42c4x2w4";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.1.2";
  };
  net-protocol = {
    dependencies = ["timeout"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a32l4x73hz200cm587bc29q8q9az278syw3x6fkc9d1lv5y0wxa";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.2.2";
  };
  net-smtp = {
    dependencies = ["net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0g4gcydr0hza3wiizny0p5q4phl3fkhfsa4r5xir8bbb9p03q41m";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.5.2";
  };
  nio4r = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18fwy5yqnvgixq3cn0h63lm8jaxsjjxkmj8rhiv8wpzv9271d43c";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.7.5";
  };
  nokogiri = {
    dependencies = ["mini_portile2" "racc"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1d9safb4dly6qmc2g06444l0zifby52yy6j1a5fa1g4j3ihm3jah";
      target = "ruby";
      type = "gem";
    };
    targets = [{
      remotes = ["https://rubygems.org"];
      sha256 = "09rmsqfzkipxi4zyp0wm54xcynni2ww9bipb6rxmkrl66a2vjvd4";
      target = "arm64-darwin";
      targetCPU = "arm64";
      targetOS = "darwin";
      type = "gem";
    } {
      remotes = ["https://rubygems.org"];
      sha256 = "0l85yw2c4iwhb7cpwfr3xyjx9lwmcpbkqjx7ajchxw71sdbp1lbz";
      target = "x86_64-darwin";
      targetCPU = "x86_64";
      targetOS = "darwin";
      type = "gem";
    } {
      remotes = ["https://rubygems.org"];
      sha256 = "0sm0h74pnjfxl1y2mzdy5wmysrc4rwnwwlnp34zmx4981d2ax7rp";
      target = "x86_64-linux-gnu";
      targetCPU = "x86_64";
      targetOS = "linux";
      type = "gem";
    } {
      remotes = ["https://rubygems.org"];
      sha256 = "13qsqdvwdnykaja86ks2lwyb828j5dv5rpakg82hbr3d99jgns8j";
      target = "aarch64-linux-gnu";
      targetCPU = "aarch64";
      targetOS = "linux";
      type = "gem";
    } {
      remotes = ["https://rubygems.org"];
      sha256 = "1jj0adrs9wmbx4lxxsxcz9pgnmkgrm5p6ycy4dl5s1mv70z320d3";
      target = "arm-linux-gnu";
      targetCPU = "arm";
      targetOS = "linux";
      type = "gem";
    }];
    version = "1.19.4";
  };
  ostruct = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04nrir9wdpc4izqwqbysxyly8y7hsfr4fsv69rw91lfi9d5fv8lm";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.6.3";
  };
  parallel = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0c719bfgcszqvk9z47w2p8j2wkz5y35k48ywwas5yxbbh3hm3haa";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.27.0";
  };
  parser = {
    dependencies = ["ast" "racc"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0a4q5h2hcihk79dbr20scgkm56l79qp7fsvfvkxlv8nmapvxg9i1";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.3.12.0";
  };
  pg = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16caca7lcz5pwl82snarqrayjj9j7abmxqw92267blhk7rbd120k";
      target = "ruby";
      type = "gem";
    };
    targets = [{
      remotes = ["https://rubygems.org"];
      sha256 = "0pqfikxxv7advxvpg72x57bcppxmxlsyazasqzbmaqrfaw5k6h3j";
      target = "arm64-darwin";
      targetCPU = "arm64";
      targetOS = "darwin";
      type = "gem";
    } {
      remotes = ["https://rubygems.org"];
      sha256 = "13df41wxcihr9lkz6i3xjycshll4imv8mf5pcb8ra0ksiy61i7jx";
      target = "x86_64-linux";
      targetCPU = "x86_64";
      targetOS = "linux";
      type = "gem";
    } {
      remotes = ["https://rubygems.org"];
      sha256 = "1mi94wpsdr1wx8vjgnmbjdz9vglm3bil7szzai8249q6gjhh8bpf";
      target = "x86_64-darwin";
      targetCPU = "x86_64";
      targetOS = "darwin";
      type = "gem";
    } {
      remotes = ["https://rubygems.org"];
      sha256 = "1skjpvj77m2x6wzh398n3p6ikpnj9iyvyxhba4kkqf027rbav606";
      target = "aarch64-linux";
      targetCPU = "aarch64";
      targetOS = "linux";
      type = "gem";
    }];
    version = "1.6.3";
  };
  pp = {
    dependencies = ["prettyprint"];
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0w5mha75hs8gdj75g8vl0sxpyp8rzvwq8a4jcmi4ah8cf370zjyz";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.6.4";
  };
  prettyprint = {
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14zicq3plqi217w6xahv7b8f7aj5kpxv1j1w98344ix9h5ay3j9b";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.2.0";
  };
  prism = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "00silqnlzzm97gn21lm39q95hjn058waqky44j25r67p9drjy1hh";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.7.0";
  };
  pry = {
    dependencies = ["coderay" "method_source"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ssv704qg75mwlyagdfr9xxbzn1ziyqgzm0x474jkynk8234pm8j";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.15.2";
  };
  pry-byebug = {
    dependencies = ["byebug" "pry"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wpa3jd46h44rjz3hjwl5c0zfx3jav4a64nm8h0g1iwv61yvn2hb";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.11.0";
  };
  psych = {
    dependencies = ["date" "stringio"];
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0x0r3gc66abv8i4dw0x0370b5hrshjfp6kpp7wbp178cy775fypb";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "5.3.1";
  };
  puma = {
    dependencies = ["nio4r"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pa9zpr51kqnsq549p6apvnr95s9flx6bnwqii24s8jg2b5i0p74";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.0";
  };
  racc = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0byn0c9nkahsl93y9ln5bysq4j31q8xkf2ws42swighxd4lnjzsa";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.8.1";
  };
  rack = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1dwgab330lsv4qppw3f52mc4ihr8lagxgll53mkmcdgr4hf3xqck";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.2.7";
  };
  rack-session = {
    dependencies = ["base64" "rack"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1s7zcxlmg88a6dam4aqbgk9xkpy6dkdfqmmcszkkliy3q3w38m2r";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.1.2";
  };
  rack-test = {
    dependencies = ["rack"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qy4ylhcfdn65a5mz2hly7g9vl0g13p5a0rmm6sc0sih5ilkcnh0";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.2.0";
  };
  rackup = {
    dependencies = ["rack"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0s48d2a0z5f0cg4npvzznf933vipi6j7gmk16yc913kpadkw4ybc";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.3.1";
  };
  rails = {
    dependencies = ["actioncable" "actionmailbox" "actionmailer" "actionpack" "actiontext" "actionview" "activejob" "activemodel" "activerecord" "activestorage" "activesupport" "railties"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0w3librd55ifs5za27afch673zyqycd7kka2fnnxmqqda5g362ls";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  rails-dom-testing = {
    dependencies = ["activesupport" "minitest" "nokogiri"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "07awj8bp7jib54d0khqw391ryw8nphvqgw4bb12cl4drlx9pkk4a";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.3.0";
  };
  rails-html-sanitizer = {
    dependencies = ["loofah" "nokogiri"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0q55i6mpad20m2x1lg5pkqfpbmmapk0sjsrvr1sqgnj2hb5f5z1m";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.6.2";
  };
  railties = {
    dependencies = ["actionpack" "activesupport" "cgi" "irb" "rackup" "rake" "thor" "tsort" "zeitwerk"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "076ywx2xs824c8bgy0fgshlfxri6v3sb3x7yy08nv9mc5rzyj41a";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "7.1.6";
  };
  rainbow = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0smwg4mii0fm38pyb5fddbmrdpifwv22zv3d3px2xx497am93503";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.1.1";
  };
  rake = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "175iisqb211n0qbfyqd8jz2g01q6xj038zjf4q0nm8k6kz88k7lc";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "13.3.1";
  };
  rbs = {
    dependencies = ["logger" "tsort"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1s2wgrmzqz82lchpjbigliy80si0mbq3162j7cda2cdvwi5pqzdi";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.10.4";
  };
  rdoc = {
    dependencies = ["erb" "psych" "tsort"];
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1dq2bani47fzyqpb4psizfmzxiznvzlajmdikdgik67wd3jx8l0g";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "6.17.0";
  };
  regexp_parser = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "192mzi0wgwl024pwpbfa6c2a2xlvbh3mjd75a0sakdvkl60z64ya";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.11.3";
  };
  reline = {
    dependencies = ["io-console"];
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0d8q5c4nh2g9pp758kizh8sfrvngynrjlm0i1zn3cnsnfd4v160i";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.6.3";
  };
  rspec-core = {
    dependencies = ["rspec-support"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bcbh9yv6cs6pv299zs4bvalr8yxa51kcdd1pjl60yv625j3r0m8";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.13.6";
  };
  rspec-expectations = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dl8npj0jfpy31bxi6syc7jymyd861q277sfr6jawq2hv6hx791k";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.13.5";
  };
  rspec-mocks = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0iqxmw0knjiz5nf6pgr8ihs6cjzh89f0ppj3fqiz8cvms79x6sh8";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.13.8";
  };
  rspec-rails = {
    dependencies = ["actionpack" "activesupport" "railties" "rspec-core" "rspec-expectations" "rspec-mocks" "rspec-support"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0jsc773kg7cqdgpqq8jhs4h02vgf7pw81chxq71y5dnfjglgq6ni";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "6.1.5";
  };
  rspec-support = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0z64h5rznm2zv21vjdjshz4v0h7bxvg02yc6g7yzxakj11byah06";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.13.7";
  };
  rubocop = {
    dependencies = ["json" "language_server-protocol" "lint_roller" "parallel" "parser" "rainbow" "regexp_parser" "rubocop-ast" "ruby-progressbar" "unicode-display_width"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wz2np5ck54vpwcz18y9x7w80c308wza7gmfcykysq59ajkadw89";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.82.1";
  };
  rubocop-ast = {
    dependencies = ["parser" "prism"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dahfpnzz63hyqxa03x8rypnrxzwyvh4i5a8ri34bzpnf3pg64j4";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.49.1";
  };
  rubocop-factory_bot = {
    dependencies = ["lint_roller" "rubocop"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1jzhj9fi1h9rh7z2j6m78hl7c3av36fpacg12wrifi24281gq5sb";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.28.0";
  };
  rubocop-rails = {
    dependencies = ["activesupport" "lint_roller" "rack" "rubocop" "rubocop-ast"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1llsxc8wm2pq8glpv5mczd1h36fazbri3wwrh7dfqra80a4pklqh";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.34.3";
  };
  rubocop-rspec = {
    dependencies = ["lint_roller" "rubocop"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cxb9i1brf1cks8anv8mdj65n9rq6jyldyd1ij9sj8zjng60si18";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.8.0";
  };
  rubocop-rspec_rails = {
    dependencies = ["lint_roller" "rubocop" "rubocop-rspec"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "004i5a4iww7l3vpaxl70ijypmi321afrslsgadbvksznf8f683aa";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.32.0";
  };
  ruby-lsp = {
    dependencies = ["language_server-protocol" "prism" "rbs"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0gaq685p1zizhsbax8gakraq46lhvy8m82v86688rzrpf9cg3j2c";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.26.11";
  };
  ruby-lsp-rspec = {
    dependencies = ["ruby-lsp"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1raf477s25l50rylq0p2rzj664gvi0r3fckxn5bcsxikf9wyb2vr";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.1.29";
  };
  ruby-openai = {
    dependencies = ["event_stream_parser" "faraday" "faraday-multipart"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0sfahyivj810211y1d1nzjmphh2r5v73sdksibbgwjigqiww4van";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "8.3.0";
  };
  ruby-progressbar = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cwvyb7j47m7wihpfaq7rc47zwwx9k4v7iqd9s1xch5nm53rrz40";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.13.0";
  };
  ruby-readability = {
    dependencies = ["guess_html_encoding" "nokogiri"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0hf2xwvjlsmkizkk7h3qvj4vdiicxal6gqcrv4awq63i0fmky8dx";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.7.3";
  };
  securerandom = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cd0iriqfsf1z91qg271sm88xjnfd92b832z49p1nd542ka96lfc";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.4.1";
  };
  simplecov = {
    dependencies = ["docile" "simplecov-html" "simplecov_json_formatter"];
    groups = ["test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "198kcbrjxhhzca19yrdcd6jjj9sb51aaic3b0sc3pwjghg3j49py";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.22.0";
  };
  simplecov-html = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ikjfwydgs08nm3xzc4cn4b6z6rmcrj2imp84xcnimy2wxa8w2xx";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.13.2";
  };
  simplecov_json_formatter = {
    groups = ["default" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0a5l0733hj7sk51j81ykfmlk2vd5vaijlq9d5fn165yyx3xii52j";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.1.4";
  };
  stringio = {
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1q92y9627yisykyscv0bdsrrgyaajc2qr56dwlzx7ysgigjv4z63";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "3.2.0";
  };
  telegram-bot = {
    dependencies = ["actionpack" "activesupport" "httpclient"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1smkcwgzx6a3mz55s7pppgyykhddspjvmaxkm064cgm4h7yl573j";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.16.7";
  };
  telegram-bot-types = {
    dependencies = ["dry-struct"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ylsm4c1j1bwpd2pgxj9znpa6z8jb4hmmkqam0g2fp5c19z0j3w8";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.7.0";
  };
  thor = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0gcarlmpfbmqnjvwfz44gdjhcmm634di7plcx2zdgwdhrhifhqw7";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.4.0";
  };
  timeout = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1jxcji88mh6xsqz0mfzwnxczpg7cyniph7wpavnavfz7lxl77xbq";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.6.1";
  };
  tsort = {
    groups = ["default" "development" "test"];
    platforms = [{
      engine = "maglev";
    } {
      engine = "mingw";
    } {
      engine = "mswin";
    } {
      engine = "mswin64";
    } {
      engine = "ruby";
    }];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "17q8h020dw73wjmql50lqw5ddsngg67jfw8ncjv476l5ys9sfl4n";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.2.0";
  };
  tzinfo = {
    dependencies = ["concurrent-ruby"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16w2g84dzaf3z13gxyzlzbf748kylk5bdgg3n1ipvkvvqy685bwd";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.0.6";
  };
  unicode-display_width = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nkz7fadlrdbkf37m0x7sw8bnz8r355q3vwcfb9f9md6pds9h9qj";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.6.0";
  };
  unicode-name = {
    dependencies = ["unicode-types"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pfvpq5v2pf164sfafx764rby3spg202wisws258qx03npgdql5k";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.14.0";
  };
  unicode-types = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ybns4spibnw11am52h7bx7bnl9sp7mpw7j7hndsh3r6fc921lc1";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.11.0";
  };
  uri = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ijpbj7mdrq7rhpq2kb51yykhrs2s54wfs6sm9z3icgz4y6sb7rp";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "1.1.1";
  };
  websocket-driver = {
    dependencies = ["base64" "websocket-extensions"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ij19k6034x0c4hw0ywa7wnk5s912r8aq0hhjss10d5z36q5dicp";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.8.2";
  };
  websocket-extensions = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0hc2g9qps8lmhibl5baa91b4qx8wqw872rgwagml78ydj8qacsqw";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "0.1.5";
  };
  zeitwerk = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pbkiwwla5gldgb3saamn91058nl1sq1344l5k36xsh9ih995nnq";
      target = "ruby";
      type = "gem";
    };
    targets = [];
    version = "2.7.5";
  };
}