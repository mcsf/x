# x

_Hands-off task management_

![Demo animation](https://raw.githubusercontent.com/mcsf/x/master/demo.gif)

([MP4 video here](https://raw.githubusercontent.com/mcsf/x/master/demo.mp4))

## Install

* Place `x` and `o` anywhere included in your shell's `$PATH`.
* Make sure they can be executed with `chmod +x <file>`.

## Requirements

* [fzf](https://github.com/junegunn/fzf) (>= 0.22)
* [dateseq](https://github.com/mcsf/dateseq) for the `-P` option

Beyond that, a POSIX-ish environment is assumed. Currently only tested on macOS, this should however work on most UNIX-like systems.

* bash (>= 3.2)
* BSD- or Linux-compatible: date, getopt, mktemp
* POSIX: cat, cut, grep, ls, tail, touch, rm

## FAQ

* **But... this is in Bash!**

That's not a question.


* **The question is: why?**

Because, OK?
