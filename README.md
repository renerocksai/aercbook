![](./aercbook.png)

# aercbook

A minimalistic address book for [the aerc e-mail client](https://aerc-mail.org).
It enables fuzzy tab-completion of e-mail addresses in aerc.

- fuzzy-search in address book for tab-completion, with wildcard support
- add to address book from the command line
- parse e-mail headers and add To: and CC: addresses to address book

What you get:

```console
aercbook --help
 aercbook v0.1.3
 Search in inputfile's keys for provided search-term.
 Or add to inputfile.

Usage:
  Search :
    aercbook inputfile search-term

    search-term may be:
       * : dump entire address book (values)
     xx* : search for keys that start with xx, dump their values
     xxx : fuzzy-search for keys that match xx, dump their values

  Add by key and value :
    aercbook inputfile -a key [value]

    Adding only a key will set the value identical to the key:
    -a mykey        ->  will add "mykey : mykey" to the inputfile
    -a mykey  value ->  will add "mykey : value" to the inputfile

  Add-from e-mail :
  cat email | aercbook inputfile --parse [--add-all] [--add-from] [--add-to] \
                                         [--add-cc]

    Parses the piped-in e-mail for e-mail addresses. Specify any
    combination of --add-from, --add-to, and --add-cc, or use
    --add-all to add them all.

    --add-from : scan the e-mail for From: addresses and add them
    --add-to   : scan the e-mail for To: addresses and add them
    --add-cc   : scan the e-mail for CC: addresses and add them
    --add-all  : scan the e-mail for all of the above and add them

    Note: e-mails like `My Name <my.name@domain.org>` will be
    split into:
      key  : My Name
      value: My Name <my.name@domain.org>
```

# Contributing

There's a [mailing list](https://lists.sr.ht/~renerocksai/aercbook) to send
patches to, discuss, etc. If you're used to GitHub's pull-request workflow,
[check out this page](https://man.sr.ht/~renerocksai/migrate-to-sourcehut/PR.md)
to see how to send me pull-requests or maybe even better-suited alternatives
(patch-sets).

# Getting it

You can download aercbook from its [refs
page](https://git.sr.ht/~renerocksai/aercbook/refs). Pick the latest version,
e.g. `v0.1.1`, then download the executable for your operating system.

Binary downloads are named with the following postfixes:

- `--aarch64-macos.gz` : for macOS ARM (e.g. M1)
- `--aarch64-x86_64-linux.gz` : for Linux
- `--aarch64-x86_64-macos.gz` : for Intel Macs
- `--aarch64-x86_64-windows.exe.zip` : for Windows

After downloading, extract the `.gz` files like this:

```console
gunzip aercbook-v0.1.1--x86_64-linux.gz
```

**Note:** You might want to rename the executable to `aercbook` (without the
version and platform information), or create an `aercbook` symlink for it.

On Windows, right-click on the `.zip` file and choose "Extract all..." from the
context menu. After that, you may want to right-click and rename the extracted
file to `aerckook.exe`.

# Usage

After [downloading](#getting-it) or [building it](#building-it), and making sure
the `aercbook` command is in your PATH, configure aerc to use aercbook:

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

# Adding to the address book

## From the command line

Aercbook supports adding to the address book from the command line:

```console
aercbook book.txt -a key [email]

# examples
aercbook book.txt -a rene rene@renerocksai
aercbook book.txt -a rene '"Rene Schallner" <rene@renerocks.ai>'
aercbook book.txt -a 'Rene Schallner' '"Rene Schallner" <rene@renerocks.ai>'

# if email is omitted, key becomes email
# example: add a single e-mail address
aercbook -a me@domain.org
```

## From a piped-in e-mail

You can pipe entire e-mails from aerc to aercbook, and let aercbook parse the
headers for to- and cc- addresses, then add them to the address book.

From `aercbook --help`:

```
  Add-from e-mail :

  cat email | aercbook inputfile --parse [--add-all] [--add-from] [--add-to] \
                                         [--add-cc]

    Parses the piped-in e-mail for e-mail addresses. Specify any
    combination of --add-from, --add-to, and --add-cc, or use
    --add-all to add them all.

    --add-from : scan the e-mail for From: addresses and add them
    --add-to   : scan the e-mail for To: addresses and add them
    --add-cc   : scan the e-mail for CC: addresses and add them
    --add-all  : scan the e-mail for all of the above and add them

    Note: e-mails like `My Name <my.name@domain.org>` will be
    split into:
      key  : My Name
      value: My Name <my.name@domain.org>
```

So you can configure a **binds.conf** entry like this:

```
[view]

# ... existing stuff ...

# on `aa` (add all), add all from-, to-, and cc- addresses to the address book
aa = :pipe -m aercbook /home/rs/.config/aerc/book.txt --parse --add-all<Enter>
```

If you're not interested in the output of the adding, e.g. which e-mails have
been added, which ignored (key exists), then you can silence it by adding the
`-b` parameter to the `pipe` command:

```
# on `aa` (add all), add all to- and cc- addresses to the address book
aa = :pipe -m -b aercbook /home/rs/.config/aerc/book.txt --parse --add-all<Enter>
```

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

someone@mail.org
```

- Everything before a colon is a KEY.
- single-item lines are KEYs and values (e-mail addresses to show) at the same
  time

The KEYs are what gets searched on. Everything after a colon is the associated
e-mail address that will be shown in the completion list.

So you can create a shortcut XXX for aslkfjaslkdfjsadlkfslakdfj@gmail.com:

```console
XXX : aslkfjaslkdfjsadlkfslakdfj@gmail.com
```

And by pressing X in the e-mail field, the long e-mail address will be
suggested as completion.

**Please note:**

- Everything is case-sensitive!

# Building it

Make sure you have the latest stable release of zig, [zig
0.11.0](https://ziglang.org/download/) installed. Then run:

```console
zig build
```

This will produce `aercbook` in the `./zig-out/bin/` directory. From there,
**copy it to a directory in your PATH**, e.g. in my case: `~/bin`.

# Tested with

- zig 0.11.0
- aerc 0.13.0
- on Linux:
  - NixOS 22.05 ([patched for aerc 0.11.0 instead of 0.10.0](https://sr.ht/~renerocksai/nixpkgs/))
  - Ubuntu 20.04.5 LTS on crostini (ChromeOS x86_64)
