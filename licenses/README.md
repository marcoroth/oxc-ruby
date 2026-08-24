# Licenses of what this gem builds against

A precompiled gem ships a native extension with [Oxc](https://github.com/oxc-project/oxc) compiled into it, so the terms that cover Oxc cover part of what is being distributed.

They are carried here so that whoever received the gem has them in hand.

| File                  | Covers                                                  | License    |
|-----------------------|---------------------------------------------------------|------------|
| `oxc-MIT.txt`         | Oxc itself                                              | MIT        |
| `oxc-THIRD-PARTY.txt` | the code Oxc carries from TypeScript and from `miette`  | Apache-2.0 |

The gem's own Ruby, C, and Rust code is MIT, in `LICENSE.txt` at the root.
