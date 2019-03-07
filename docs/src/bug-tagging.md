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

    label:linked
    
    testname01: bsc#123455
	
The `label:linked` part is a workaround to prevent 'automatic takeover' by
OpenQA. The Propagate Bug Tags script will propagate bug tags from one failed
job to another when the bug tag expression is satisfied. In this case, if the
test testname01 (from the same test suite) has failed and the environment
matches.

When bug tags are propagated you will see a comment like the following

!!! tip "JDP wrote N days ago"

    label:linked
    This is an automated message from [JDP](https://gitlab.suse.de/rpalethorpe/jdp/blob/master/notebooks/Propagate%20Bug%20Tags.ipynb)
    
    The following bug tags have been propogated: 
    
    - generic-349: bsc#1128319 [**P5 - None**(*Normal*) NEW: Bug title 1]
    - generic-350: bsc#1128321 [**P5 - None**(*Normal*) NEW: Bug title 2]
    
    This superscedes any (Automatic takeover from t#...) messages

To prevent an old tag from being propagating to new jobs you can add an
'anti-tag', like:

    label:linked
    
    testname01: bsc#123455

