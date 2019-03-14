# Bug Tagging

This page will act as a guide to tagging anomalies (usually test
failures) with references to a [`JDP.Tracker`](@ref) item.

In an abstract, very general sense, a bug tag (see [`JDP.BugRefs`](@ref)) is
an expression which can be used to link an anomaly (or type of anomaly) to
some other entity. However, usually we tag test failures with a bug/issue
entry in a tracker, so we shall call them bug tags (for now).

At the very least, bug tags can be used to automatically identify test
failures or other anomalies which have already been investigated.

## Tagging in OpenQA

In OpenQA we can tag test failures with bug references by commenting on a job
with something like:

    generic-349: bsc#1128319

or

    * generic/349: bsc#1128319.
    * Some other text which will be ignored.

or

    generic-349:bsc#1128319, generic-350 : bsc#1128321

or even

    * test01, test02: bug#1
    * test03:bug#2,bug#3

You can included other text in your comments and it will mostly be
ignored. Also white-space is not significant around the `:`. There is also
some flexibility in how you write the test names. For example `/` will be
substituted with `-`, allowing you to use either.

The full rules are in the [`JDP.BugRefsParser`](@ref).
	
The Propagate Bug Tags script will propagate bug tags from one failed job to
another when the bug tag expression is satisfied. In this case, if the test
`generic-349`[^1] has failed and the environment matches.

!!! warning

    If OpenQA's built in bugref carry over is also enabled, then you may get
    some strange interactions between it and the JDP script.

When bug tags are propagated you will see a comment like the following

!!! tip "JDP wrote N days ago"

    This is an automated message from [JDP](https://gitlab.suse.de/rpalethorpe/jdp/blob/master/notebooks/Propagate%20Bug%20Tags.ipynb)
    
    The following bug tags have been propagated: 
    
    - generic-349: bsc#1128319 [**P5 - None**(*Normal*) NEW: Bug title 1]
    - generic-350: bsc#1128321 [**P5 - None**(*Normal*) NEW: Bug title 2]

To prevent an old tag from being propagating to new jobs you can add an
'anti-tag', like:

    generic-349:! bsc#1128319

An anti-tag won't be propagated itself. It just stops any more propagations
of tags which match its pattern. If you delete the comment containing the tag
(and update the cache) then propagation should continue.

!!! warning

    You should write the `!` immediately after the `:`. Do not insert
    white-space between them.

[^1]:

    This will be expanded to the Fully Qualified Name (FQN). For example;
    `fstests:btrfs:generic-349` if it is in the btrfs test suite or
    `fstests:xfs:generic-349` if it is in the xfs suit.
