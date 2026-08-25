function hpc_die
    echo "ERROR: $argv" >&2
    exit 1
end

function hpc_note
    echo "==> $argv"
end

function hpc_load_defaults
    set repo $argv[1]

    set cfg $repo/config/defaults.conf
    if test -f $cfg
        for line in (string split \n (cat $cfg))
            set line (string trim $line)
            if test -z "$line"; or string match -qr '^#' -- $line
                continue
            end
            set kv (string split -m1 '=' $line)
            if test (count $kv) -ne 2
                continue
            end
            switch $kv[1]
                case TINYHPC_HOME TINYHPC_ROOT HPC_JOBS HPC_PROFILE
                    set -q $kv[1]; or set -gx $kv[1] $kv[2]
            end
        end
    end

    set -q TINYHPC_HOME; or set -gx TINYHPC_HOME /opt/tinyhpc
    set -q TINYHPC_ROOT; or set -gx TINYHPC_ROOT /opt/hpc
    set -q HPC_JOBS; or set -gx HPC_JOBS 4
    set -q HPC_PROFILE; or set -gx HPC_PROFILE native

    # Compatibilidade com as versões iniciais do projeto.
    set -gx HPC_ROOT $TINYHPC_ROOT
    set -gx HPC_CACHE $TINYHPC_ROOT/cache
    set -gx HPC_SRC $TINYHPC_ROOT/src
    set -gx HPC_BUILD $TINYHPC_ROOT/build
    set -gx HPC_SOFTWARE $TINYHPC_ROOT/software
    set -gx HPC_MODULEFILES $TINYHPC_ROOT/modulefiles
    set -gx HPC_LOGS $TINYHPC_ROOT/logs
end

function hpc_read_manifest
    set manifest $argv[1]
    test -f $manifest; or hpc_die "manifesto não encontrado: $manifest"

    for v in (set -n | string match 'PKG_*')
        set -e $v
    end

    for line in (string split \n (cat $manifest))
        set line (string trim $line)
        if test -z "$line"; or string match -qr '^#' -- $line
            continue
        end
        set kv (string split -m1 '=' $line)
        if test (count $kv) -eq 2
            set -gx PKG_$kv[1] $kv[2]
        end
    end
end

function hpc_require_layout
    for d in $HPC_CACHE $HPC_SRC $HPC_BUILD $HPC_SOFTWARE $HPC_MODULEFILES $HPC_LOGS
        test -d $d; or hpc_die "$d não existe; rode o bootstrap do TinyHPC"
    end
end

function hpc_fetch
    set url $argv[1]
    set out $argv[2]
    set expected $argv[3]

    if not test -f $out
        hpc_note "baixando "(basename $out)
        curl -fL --retry 3 -o $out $url; or hpc_die "download falhou"
    else
        hpc_note "usando cache "(basename $out)
    end

    set got (sha256sum $out | string split ' ' | head -n1)
    if test "$expected" = UNSET
        hpc_die "checksum não travado. Use tools/lock-checksum.fish; SHA-256 atual: $got"
    end
    test "$got" = "$expected"; or hpc_die "checksum inválido: $got"
end

function hpc_extract
    set archive $argv[1]
    set dest $argv[2]
    set srcdir $argv[3]
    rm -rf $dest/$srcdir
    switch $archive
        case '*.tar.gz' '*.tgz'
            tar -xzf $archive -C $dest
        case '*.tar.xz'
            tar -xJf $archive -C $dest
        case '*.tar.bz2'
            tar -xjf $archive -C $dest
        case '*'
            hpc_die "formato não suportado: $archive"
    end
end

function hpc_apply_patches
    set src $argv[1]
    set patchdir $argv[2]
    test -d $patchdir; or return 0

    set patches (find $patchdir -maxdepth 1 -type f -name '*.patch' | sort)
    for p in $patches
        hpc_note "aplicando patch "(basename $p)
        patch -d $src -p1 < $p; or hpc_die "patch falhou: $p"
    end
end
