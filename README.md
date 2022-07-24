# aercbook

A minimalistic address book for [the aerc mail client](https://aerc-mail.org)

## Contributing

There's a [mailing list](https://lists.sr.ht/~renerocksai/aercbook) to send
patches to, discuss, etc.

## Usage

After [building it](#building-it), configure aerc to use aercbook:

```console
# Specifies the command to be used to tab-complete email addresses. Any
# occurrence of "%s" in the address-book-cmd will be replaced with what the
# user has typed so far.
address-book-cmd=aercbook /home/rs/.config/aerc/book.txt "%s"
```

The first parameter to aercbook is the path to the address book file. In my
case, it's located where aerc's config is.

When you restart aerc now and have created an address book, aerc will
automatically show you completion options in e-mail form fields.

The way the search works, is: it searches by the KEYs -> but returns the
associated values.

## Address Book Format

Here is an [example](./book.txt):

```console
rene             :  rene@renerocks.ai
come             : ~renerocksai/come-to-sourcehut@lists.sr.ht
gh-to-sh         : ~renerocksai/GH-to-SH@lists.sr.ht
tkdevel          : ~renerocksai/telekasten.nvim-devel@lists.sr.ht
tkdiscuss        : ~renerocksai/telekasten.nvim-discuss@lists.sr.ht
tkannounce       : ~renerocksai/telekasten.nvim-announce@lists.sr.ht
ssh-docker-cr    : ~renerocksai/ssh-docker-cr@lists.sr.ht
slides           : ~renerocksai/slides@lists.sr.ht
bullets          : ~renerocksai/bullets@lists.sr.ht
real-prog-querty : ~renerocksai/real-prog-querty@lists.sr.ht
```

Everything before a colon is a KEY. The KEYs are what gets searched on.
Everything after a colon is the associated e-mail address that will be shown in
the completion list.

So you can create a shortcut XXX for aslkfjaslkdfjsadlkfslakdfj@gmail.com:

```console
XXX : aslkfjaslkdfjsadlkfslakdfj@gmail.com
```

And by pressing `X` in the e-mail field, the long e-mail address will be
suggested as completion.

## Building it

If you're a NixOS user, you can enter the nix shell:

```console
nix-shell
zig build
```

All others, make sure you have zig installed. Then run:

```console
zig build
```

This will produce `aercbook` in the `./zig-out/bin/` directory. From there, copy
it to a directory in your PATH, e.g. in my case `~/bin`.

## Tested with

- zig 0.9.1
- aerc 0.11.0
