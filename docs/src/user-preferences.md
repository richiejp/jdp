# User Preferences

While the majority of [JDP's config](conf) is set in the conf directory on the
JDP host. User preferences are taken from other, more accessible places. Where
they can be written and read by other applications.

## OpenQA

Notifications preferences can be set by adding TOML sections to OpenQA job
group descriptions. These are at least read by the
[Status Difference](reports/Report-Status-Diff.html) report.

The functions below extract and interpret the TOML.

```@docs
JDP.Trackers.OpenQA.extract_toml
```

```@docs
JDP.Trackers.OpenQA.load_notify_preferences
```
