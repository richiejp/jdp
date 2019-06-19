# User Preferences

While the majority of [JDP's config](conf) is set in the conf directory on the
JDP host. User preferences are taken from other, more accessible places. Where
they can be written and read by other applications.

## OpenQA

Notifications preferences can be set by adding TOML sections to OpenQA job
group descriptions. These are at least read by the
[Status Difference](reports/Report-Status-Diff.html) report which interprets
the pattern strings as regular expressions and matches them against test names
and suites. The script also takes the job group where the TOML was written
into account, so notification settings are not shared between job groups. This
means you can use the pattern '.' and it will notify you for all tests on a
given job group and no others.

The functions below extract and interpret the TOML and show an example of what
the TOML may look like.

```@docs
JDP.Trackers.OpenQA.extract_toml
```

```@docs
JDP.Trackers.OpenQA.load_notify_preferences
```
