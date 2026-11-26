# PCRE1 8.45 for OpenResty

The runtime uses PCRE1 8.45. Acquire `https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz` and verify SHA-256 `4e6ce03e0336e8b4a3d6c2b70b1c5e18590a5673a98186da90d4f33c23defc09`; the detached signature was verified against fingerprint `45F68D54BBE23FB3039B46E59766E084FB0F43D8`.

The bundled `config.guess` and `config.sub` did not recognize LoongArch, so the successful native build replaced them with GNU Autoconf 2.72 copies, then configured shared PCRE without JIT:

~~~sh
cp autoconf-2.72/build-aux/config.guess pcre-8.45/config.guess
cp autoconf-2.72/build-aux/config.sub pcre-8.45/config.sub
chmod +x pcre-8.45/config.guess pcre-8.45/config.sub
cd pcre-8.45
./configure --prefix=/usr --enable-shared --disable-static
make -j2
make check
make install
ldconfig
~~~

`make check` passed 5/5. The installed shared library SHA-256 was `c078b3a6a7f0dc9d4b2c81ec941edb760b55567fdf2f7d20efd27a42216a8139`. LoongArch PCRE1 has no JIT support: keep PCRE1 `--enable-jit` and OpenResty `--with-pcre-jit` disabled. The OpenResty runtime tests also verified the PCRE JIT configure flag is absent.
