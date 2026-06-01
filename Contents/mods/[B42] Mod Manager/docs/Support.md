# Mod Support Links

Mod Manager lets mod authors add support links to `mod.info`. When a supported link is present, the mod list shows a small support marker, and the mod information panel shows clickable links in the `Support` row.

## Supported services

Add one or more of these fields to `mod.info`:

| Field | Service | Accepted link format |
|-------|---------|----------------------|
| `tribute` | Tribute | `https://web.tribute.tg/...` |
| `ko-fi` | Ko-fi | `https://ko-fi.com/...` |
| `buy-me-a-coffee` | Buy Me a Coffee | `https://buymeacoffee.com/...` |
| `donationalerts` | DonationAlerts | `https://www.donationalerts.com/...` |
| `patreon` | Patreon | `https://www.patreon.com/...` |
| `boosty` | Boosty | `https://boosty.to/...` |

The value must be the full `https://` link. Usernames, handles, shortened links, and links with another domain are ignored.

## Example

```
name=My Awesome Mod
id=MyAwesomeMod
author=Mod Author
poster=poster.png
tribute=https://web.tribute.tg/d/example
patreon=https://www.patreon.com/example
boosty=https://boosty.to/example
```

You can use a single service or list several services at once. Mod Manager displays valid links in this order: Tribute, Ko-fi, Buy Me a Coffee, DonationAlerts, Patreon, Boosty.

## Invalid values

These values are ignored:

```
patreon=example
patreon=patreon.com/example
patreon=https://example.com/example
kofi=https://ko-fi.com/example
```

In the last line, the link itself is valid, but the field name is not. Use `ko-fi=` instead.

## Notes for mod authors

- Put the support fields in the root `mod.info` file of your mod.
- Leave a field out if you do not use that service.
- Invalid or empty support fields do not show up in the UI.
- Links are opened through Steam's link filter when selected in Mod Manager.