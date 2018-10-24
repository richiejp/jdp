# Work in progress...

If you are feeling brave and want to try this out, then install the *official*
Julia 1.0 distro (SUSE's won't work because of some wierd issue with compiling
a maths library) somewhere in your path. Then see `src/startup.jl` for using
JDP from a REPL and `src/notebook.jl` for using it with Jupyter (recommended)
or try running the tests (I have no idea why you would want to do that, but it
is something you can do).

You will need to get the data from OpenQA somehow. This is possible by
following the instructions in `src/report.ipynb`, but I would advise against
downloading too many builds/results because you will die of old age before it
finishes. In the future we will create a central data cache to take the load
off OpenQA.

Note that if you have Jupyter installed you can probably view
`src/report.ipynb` without doing any other setup. You just won't be able to
rerun the code snippets.
