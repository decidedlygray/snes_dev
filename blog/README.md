# blog/

Source text for posts on [snes.dev](https://snes.dev). Nothing here is
published automatically; posts are copied to the site by hand.

```
posts/    one Markdown file per post: NNN-short-slug.md
images/   images used by posts, prefixed with the post number
notes.md  running dev log: snags, discoveries and ideas for future posts
```

Conventions:

- Each post starts with YAML front matter (`title`, `date`, `slug`,
  `draft`). Set `draft: false` when it goes live.
- Unresolved bits are marked `> **TODO before publishing:** …`.
- Images link relatively (`../images/…`). Emulator screenshots are 256×224;
  display them scaled up with `image-rendering: pixelated`.
- ROM screenshots come from `make test` (`build/screenshots/`); copy them here
  under the post's number.
