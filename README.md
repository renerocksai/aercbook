# aercbook

A minimalistic address book for [the aerc e-mail client](https://aerc-mail.org).
It enables fuzzy tab-completion of e-mail addresses in aerc.

# Contributing

There's a [mailing list](https://lists.sr.ht/~renerocksai/aercbook) to send
patches to, discuss, etc. If you're used to GitHub's pull-request workflow,
[check out this page](https://man.sr.ht/~renerocksai/migrate-to-sourcehut/PR.md)
to see how to send me pull-requests or maybe even better-suited alternatives
(patch-sets).

# Usage

After [building it](#building-it) and making sure the `aercbook` command is in
your PATH, configure aerc to use aercbook:

In your **aerc.conf**, enable the `address-book-cmd` setting as follows:

```console
# Specifies the command to be used to tab-complete email addresses. Any
# occurrence of "%s" in the address-book-cmd will be replaced with what the
# user has typed so far.
address-book-cmd=aercbook /home/rs/.config/aerc/book.txt "%s"
```

If `aercbook` is not in your path, you may optionally specify the full path to
aercbook like so:

```console
address-book-cmd=/home/rs/bin/aercbook /home/rs/.config/aerc/book.txt "%s"
```

The first parameter to aercbook is the path to the address book file. In my
case, it's `book.txt`, located where aerc's config is.

The second parameter `"%s"` will be replaced by aerc with what the user has
typed so far. Do not change this.

When you restart aerc now and have created an address book, aerc will
automatically show you completion options in e-mail form fields. Use the
<kbd>TAB</kbd> key to browse through the suggestions or keep typing to narrow
them down.

The way the search works, is: it searches the KEYs (think: aliases, shortcuts)
but returns the associated e-mails.

See [address book format](#address-book-format) for what I mean with keys.

# Search Modes

## * : Dump Address Book

Type `*` as the **first** character of the search. This will list the entire
address book as suggestions to tab through.

## xx* : Dump entries starting with xx

Type the beginning of a KEY, followed by an asterisk, and only address book
entries whose keys **start with** the term before the asterisk will be listed.
E.g. `r*` will list all entries with keys that start with an `r`.

## Default: Fuzzy search

A modified Levenshtein's or edit distance is used to sort matching keys in order
to enable fuzzy searching. Hence, you don't need to type in keys exactly as
specified in the address book. E.g. instead of `rene`, you can type `ee` which
will rank `rene` higher than e.g. `ellipsis`, eventhough the latter starts with
an `e`.

The modification to the Levenshtein distance is: search words matching the
beginning of keys will be preferred by subtracting their length from the
resulting distance. E.g. "ren" will have an edit distance to the key "rene" of
1, but since the first three characters match the key, the resulting distance is
1-3 = -2, giving "ren" preference over matches with an edit distance of 1 that
don't start with "ren".

# Address Book Format

Here is an [example](./book.txt) of mainly my mailing list aliases:

```console
rene             :  Rene Schallner <rene@renerocks.ai>
come             : ~renerocksai/come-to-sourcehut@lists.sr.ht
gh-to-sh         : ~renerocksai/GH-to-SH@lists.sr.ht
tkdevel          : ~renerocksai/telekasten.nvim-devel@lists.sr.ht
tkdiscuss        : ~renerocksai/telekasten.nvim-discuss@lists.sr.ht
tkannounce       : ~renerocksai/telekasten.nvim-announce@lists.sr.ht
ssh-docker-cr    : ~renerocksai/ssh-docker-cr@lists.sr.ht
slides           : ~renerocksai/slides@lists.sr.ht
bullets          : ~renerocksai/bullets@lists.sr.ht
real-prog-querty : ~renerocksai/real-prog-querty@lists.sr.ht
aercbook         : ~renerocksai/aercbook@lists.sr.ht
```

Everything before a colon is a KEY. The KEYs are what gets searched on.
Everything after a colon is the associated e-mail address that will be shown in
the completion list.

So you can create a shortcut XXX for aslkfjaslkdfjsadlkfslakdfj@gmail.com:

```console
XXX : aslkfjaslkdfjsadlkfslakdfj@gmail.com
```

And by pressing X in the e-mail field, the long e-mail address will be
suggested as completion.

**Please note:**

- Everything is case-sensitive!

# Building it

If you're on NixOS or use the Nix package manager, a `shell.nix` file is
provided. It will provide you with `zig 0.9.1` and all dependencies relevant for
building aercbook NixOS-style. Enter the shell and build aercbook like this:

```console
nix-shell
zig build
```

All others, make sure you have [zig 0.9.1](https://ziglang.org/download/)
installed. Then run:

```console
zig build
```

This will produce `aercbook` in the `./zig-out/bin/` directory. From there,
**copy it to a directory in your PATH**, e.g. in my case: `~/bin`.

# Tested with

- zig 0.9.1
- aerc 0.11.0
- on Linux: NixOS 22.05 ([patched for aerc 0.11.0 instead of
  0.10.0](https://sr.ht/~renerocksai/nixpkgs/))
