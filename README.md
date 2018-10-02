If you are feeling brave and want to try this out, then install the *official*
Julia 1.0 distro (SUSE's won't work because of some wierd issue with compiling
a maths library) somewhere in your path and see `src/startup.jl` for using JDP
from a REPL and `src/notebook.jl` or try running the tests.

You will need to get the data from OpenQA somehow, see `src/OpenQA.jl` and
`src/TableDB.jl`. I still need to host the data in a cache somewhere, script
installation and cleanup some dead code. However the current priority is to
prove the technology works for reporting.
