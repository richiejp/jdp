var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#JDP-1",
    "page": "Home",
    "title": "JDP",
    "category": "section",
    "text": "Extensible, sometimes automated, test/bug review and reporting development environment. The broader aim is to make prototyping arbitrary reporting and inter-tool workflows cheap so that experimentation in this area has a convex payoff.Initially targeted at SUSE\'s QA Kernel & Networking team\'s requirements, but this is intended to have general applicability at least within SUSE QA."
},

{
    "location": "#Install-1",
    "page": "Home",
    "title": "Install",
    "category": "section",
    "text": "The goal is to do this in a single command, but for now it takes a few more.note: Note\nSUSE employees and associates should view this at: gitlab.suse.de/rpalethorpe/jdp"
},

{
    "location": "#Docker-1",
    "page": "Home",
    "title": "Docker",
    "category": "section",
    "text": "You can install using Docker by doing the following from the directory where you cloned this repo. This is probably the easiest way if you just want to quickly try it out.docker build -t jdp:latest -f install/Dockerfile .Or you can substitute the build command for the following which will get a pre-built image from hub.docker.com (it may not be up to date).docker pull suserichiejp/jdp:latestThen you can inject the access details for the data cache server if you have them. Using the data cache can save a lot of time.docker build -t jdp:latest -f install/Dockerfile-slave \\\n             --build-arg REDIS_MASTER_HOST=ip-or-name \\\n             --build-arg REDIS_MASTER_AUTH=password .note: Note\nIf you pulled from dockerhub (or wherever) then you will need to change the tag name to suserichiejp/jdp:latest (or whatever).Then run itdocker run -it -p 8889:8889 jdp:latestWith a bit of luck you will see a message from Jupyter describing what to do next. The Docker image also contains two volumes which you may mount. See the Dockerfile for more info.You can use the Docker image for developing JDP itself by mounting the src volume. However this is probably not a good long term solution."
},

{
    "location": "#Other-1",
    "page": "Home",
    "title": "Other",
    "category": "section",
    "text": "You can use install/Dockerfile as a guide. Also check conf/*.toml.You can run JDP directly from the git checkout. Just install the deps listed in the Dockerfile and modify the conf files (which should include there own documentation)."
},

{
    "location": "#Usage-1",
    "page": "Home",
    "title": "Usage",
    "category": "section",
    "text": ""
},

{
    "location": "#With-Jupyter-1",
    "page": "Home",
    "title": "With Jupyter",
    "category": "section",
    "text": "If you are using the Docker image then just browse to localhost:8889. If not then start Jupyter yourself.Open either the notebooks/Report-DataFrames.ipynb or notebooks/Propagate Bug Tags.ipynb Jupyter notebooks which are (hopefully) self documenting. I have only tested them with Jupyter itself, but there are fancier alternatives such as JupyterLab and, of course, Emacs."
},

{
    "location": "#Other-2",
    "page": "Home",
    "title": "Other",
    "category": "section",
    "text": "You can also use the library from a Julia REPL or another project. For example in a julia REPL you could runinclude(\"src/init.jl\")Also the run directory contains scripts which are intended to automate various tasks. These can be executed with Julia in a similar way to julia run/all.jl."
},

{
    "location": "#Automation-1",
    "page": "Home",
    "title": "Automation",
    "category": "section",
    "text": "JDP is automated using SUSE\'s internal Gitlab CI instance. Which automates building and testing the containers as well as deployment and the execution of various scripts/services. See install/gitlab-ci.*."
},

{
    "location": "#Documentation-1",
    "page": "Home",
    "title": "Documentation",
    "category": "section",
    "text": "Further documentation can be found at richiejp.github.io/jdp or rpalethorpe.io.suse.de/jdpYou can also find documentation at the Julia REPL by typing ? followed by an identifier or in a notebook you can type @doc identifier in a code cell.The following image may give you some intuition for what JDP is.(Image: Outer Architecture)"
},

{
    "location": "bugrefs/#",
    "page": "BugRefs",
    "title": "BugRefs",
    "category": "page",
    "text": ""
},

{
    "location": "bugrefs/#Bug-References-1",
    "page": "BugRefs",
    "title": "Bug References",
    "category": "section",
    "text": "Modules = [JDP.BugRefs, JDP.BugRefsParser]"
},

{
    "location": "bugrefs/#JDP.BugRefs",
    "page": "BugRefs",
    "title": "JDP.BugRefs",
    "category": "module",
    "text": "Bug references are usually a three letter abreviation (TLA) for a tracker instance (e.g. bugzilla.suse.com -> bsc) followed by a # and then an id number, so for example bsc#12345.\n\nTest failures can be \'tagged\' with a bug reference. This usually looks something like test01:bsc#12345. There are also anti-tags which signal that a failure should no longer be associated with a given bug. These look like test01:!bsc#12345.\n\nThis module provides methods for processing bug references and tags which are typically included in a comment on a test failure, but can be taken from any text.\n\n\n\n\n\n"
},

{
    "location": "bugrefs/#JDP.BugRefs.extract_tags!-Tuple{Dict{String,Array{JDP.BugRefs.Ref,N} where N},String,JDP.Tracker.TrackerRepo}",
    "page": "BugRefs",
    "title": "JDP.BugRefs.extract_tags!",
    "category": "method",
    "text": "Parse some text for Bug tags and add them to the given tags index\n\n\n\n\n\n"
},

{
    "location": "bugrefs/#JDP.BugRefs.Ref",
    "page": "BugRefs",
    "title": "JDP.BugRefs.Ref",
    "category": "type",
    "text": "A reference to a bug on a particular tracker\n\n\n\n\n\n"
},

{
    "location": "bugrefs/#BugRefs-1",
    "page": "BugRefs",
    "title": "BugRefs",
    "category": "section",
    "text": "Modules = [JDP.BugRefs]"
},

{
    "location": "bugrefs/#JDP.BugRefsParser",
    "page": "BugRefs",
    "title": "JDP.BugRefsParser",
    "category": "module",
    "text": "Parser for the Bug references (tags) DSL\n\nSee parse_comment\'s docs for the format.\n\n\n\n\n\n"
},

{
    "location": "bugrefs/#JDP.BugRefsParser.parse_comment-Tuple{String}",
    "page": "BugRefs",
    "title": "JDP.BugRefsParser.parse_comment",
    "category": "method",
    "text": "parse_comment(text)\n\nTry to extract the test-name:bug-ref pairs from a comment\n\nBelow is the approximate syntax in EBNF. Assume letter ∈ [a-Z] and digit ∈ [0-9] and whitespace is allowed between testnames, bugrefs, \':\' and \',\'. However there should be no gap between \':\' and \'!\'.\n\ntestname = letter | digit { letter | digit | \'_\' | \'-\' }\ntracker = letter { letter }\nid = letter | digit { letter | digit }\nbugref = tracker \'#\' id\ntagging = testname {\',\' testname} \':\' [\'!\'] bugref {\',\' bugref}\ntaggings = tagging { tagging }\n\nA tagging can assign many bug references to many testnames, which means you can have something like: test1, test2: bsc#1234, git#a33f4. Which tags tests 1 and 2 with both bug references.\n\nComments many contain many taggings along with other random text. If the algorithm finds an error it discards the current tagging and starts trying to parse a new tagging from the point where it failed.\n\n\n\n\n\n"
},

{
    "location": "bugrefs/#JDP.BugRefsParser.tokval-Tuple{JDP.BugRefsParser.Token}",
    "page": "BugRefs",
    "title": "JDP.BugRefsParser.tokval",
    "category": "method",
    "text": "tokval(tok)\n\nGet the textual value of any AbstractToken. \n\nImplement using SubString and not [n:m] because the former is zero-copy.\n\n\n\n\n\n"
},

{
    "location": "bugrefs/#JDP.BugRefsParser.AbstractToken",
    "page": "BugRefs",
    "title": "JDP.BugRefsParser.AbstractToken",
    "category": "type",
    "text": "Some kind of symbol or even an expression; so long as it can be represented by SubString\n\n\n\n\n\n"
},

{
    "location": "bugrefs/#BugRefsParser-(Internal)-1",
    "page": "BugRefs",
    "title": "BugRefsParser (Internal)",
    "category": "section",
    "text": "Modules = [JDP.BugRefsParser]"
},

{
    "location": "conf/#",
    "page": "Conf",
    "title": "Conf",
    "category": "page",
    "text": ""
},

{
    "location": "conf/#JDP.Conf",
    "page": "Conf",
    "title": "JDP.Conf",
    "category": "module",
    "text": "Gives access to configuration files\n\n\n\n\n\n"
},

{
    "location": "conf/#JDP.Conf.confmerge-Tuple{Any,Any}",
    "page": "Conf",
    "title": "JDP.Conf.confmerge",
    "category": "method",
    "text": "Like Base.merge, but recurses into Dictionaries\n\n\n\n\n\n"
},

{
    "location": "conf/#JDP.Conf.get_conf-Tuple{Symbol}",
    "page": "Conf",
    "title": "JDP.Conf.get_conf",
    "category": "method",
    "text": "get_conf(name::Symbol)::Dict\n\nGet the configuration for name. If a temporary in-memory conf has been set with set_conf then it will return that. Otherwise it will return the contents of ../conf/name.toml merged with ~/.config/jdp/name.toml. The contents of the home directory config win in the event of a conflict.\n\n\n\n\n\n"
},

{
    "location": "conf/#JDP.Conf.set_conf-Tuple{Symbol,Dict}",
    "page": "Conf",
    "title": "JDP.Conf.set_conf",
    "category": "method",
    "text": "Used to override the contents of the configuration files for testing (for now)\n\n\n\n\n\n"
},

{
    "location": "conf/#JDP.Conf.set_usr_path-Tuple{String}",
    "page": "Conf",
    "title": "JDP.Conf.set_usr_path",
    "category": "method",
    "text": "Override the user specific config path for unit testing\n\n\n\n\n\n"
},

{
    "location": "conf/#Conf-1",
    "page": "Conf",
    "title": "Conf",
    "category": "section",
    "text": "Modules = [JDP.Conf]Modules = [JDP.Conf]"
},

{
    "location": "functional/#",
    "page": "Functional",
    "title": "Functional",
    "category": "page",
    "text": ""
},

{
    "location": "functional/#JDP.Functional",
    "page": "Functional",
    "title": "JDP.Functional",
    "category": "module",
    "text": "Helpers for functional style programming\n\n\n\n\n\n"
},

{
    "location": "functional/#JDP.Functional.bc-Tuple{Any}",
    "page": "Functional",
    "title": "JDP.Functional.bc",
    "category": "method",
    "text": "Backwards Curry\n\n\n\n\n\n"
},

{
    "location": "functional/#JDP.Functional.c-Tuple{Any}",
    "page": "Functional",
    "title": "JDP.Functional.c",
    "category": "method",
    "text": "Curry\n\nThis allows partial function application by wrapping the passed function f in two lambdas. This provides a limited form of Currying.\n\nWhen a function is wrapped with c the first time you call it, it will return a new function with the arguments you supplied already applied. So that\n\nc(f) = f\'\nf\'(a, b, ...) = f\'\'\nf\'\'(u, v, ...) = f(a, b, ..., u, v, ...)\n\nwhere \"a, b, ...\" and \"u, v, ...\" are lists of arbitrary variables.\n\nExamples\n\nClassic currying example:\n\nadd(x, y) = x + y\nadd2(y) = c(add)(2)\n\nThis is useful when chaining operations due to limitations of the do-syntax and the chain operator |>:\n\ncmap = c(map)\ncfilter = c(filter)\n\n1:10 |> cmap() do x\n    x^2\nend |> cfilter() do x\n    x > 50\nend\n\nNote that functions like cmap are generally already defined by this module.\n\n\n\n\n\n"
},

{
    "location": "functional/#JDP.Functional.doif-Tuple{Function,Function,Any}",
    "page": "Functional",
    "title": "JDP.Functional.doif",
    "category": "method",
    "text": "Do fn(val) if cond(val) else nothing\n\nIf the condition is true then returns the result of fn(val) otherwise returns  nothing. This can be chained with cdefault to provide a default value when cond(val) is false.\n\n\n\n\n\n"
},

{
    "location": "functional/#Functional-1",
    "page": "Functional",
    "title": "Functional",
    "category": "section",
    "text": "Modules = [JDP.Functional]Modules = [JDP.Functional]"
},

{
    "location": "repository/#",
    "page": "Repository",
    "title": "Repository",
    "category": "page",
    "text": ""
},

{
    "location": "repository/#JDP.Repository.AbstractItem",
    "page": "Repository",
    "title": "JDP.Repository.AbstractItem",
    "category": "type",
    "text": "Some kind of item tracked by a tracker\n\n\n\n\n\n"
},

{
    "location": "repository/#JDP.Repository.fetch-Union{Tuple{C}, Tuple{I}, Tuple{I,C,Union{Array{String,1}, String}}} where C where I<:JDP.Repository.AbstractItem",
    "page": "Repository",
    "title": "JDP.Repository.fetch",
    "category": "method",
    "text": "Get one or more items of the given in the specified container\n\nThe exact behaviour depends on what is requested. If the data can not be retrieved from the local data cache then it may request it from a remote source.\n\n\n\n\n\n"
},

{
    "location": "repository/#JDP.Repository.refresh-Tuple{Array{JDP.BugRefs.Ref,1}}",
    "page": "Repository",
    "title": "JDP.Repository.refresh",
    "category": "method",
    "text": "Refresh the local cached data for the given bug references\n\n\n\n\n\n"
},

{
    "location": "repository/#Repository-1",
    "page": "Repository",
    "title": "Repository",
    "category": "section",
    "text": "Modules = [JDP.Repository]Modules = [JDP.Repository]"
},

{
    "location": "trackers/#",
    "page": "Trackers",
    "title": "Trackers",
    "category": "page",
    "text": ""
},

{
    "location": "trackers/#Bug-References-1",
    "page": "Trackers",
    "title": "Bug References",
    "category": "section",
    "text": "Modules = [JDP.Tracker, JDP.Trackers.OpenQA, JDP.Trackers.Bugzilla]"
},

{
    "location": "trackers/#JDP.Tracker",
    "page": "Trackers",
    "title": "JDP.Tracker",
    "category": "module",
    "text": "Trackers are external sources of information which track some kind of item.\n\nFor example Bugzilla and OpenQA are both considered trackers by JDP. Bugzilla tracks bugs and OpenQA tracks test results. GitWeb could also be considered a tracker which tracks git commits. Some services may track a number of different items.\n\nDesign note\n\nHopefully new trackers can eventually be declaratively defined in conf/trackers.toml. However this is difficult when most of them seem to use different authentication methods and different data formats. So we begin with tracker specific code (e.g. trackers/Bugzilla.jl) and then try to generialise them if feasible.\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Tracker.Api",
    "page": "Trackers",
    "title": "JDP.Tracker.Api",
    "category": "type",
    "text": "Information about a tracker\'s API\n\nThis is a generic interface for tracker features which are simple/standard enough to configure via conf/trackers.toml. Tracker specific features are handled by Tracker specific methods dispatched on the Session type parameter\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Tracker.TrackerRepo",
    "page": "Trackers",
    "title": "JDP.Tracker.TrackerRepo",
    "category": "type",
    "text": "Tracker Repository\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Tracker.AbstractSession",
    "page": "Trackers",
    "title": "JDP.Tracker.AbstractSession",
    "category": "type",
    "text": "A connection to a tracker API\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Tracker.Instance",
    "page": "Trackers",
    "title": "JDP.Tracker.Instance",
    "category": "type",
    "text": "Information about a Tracker\'s instance\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Tracker.Instance-Tuple{String}",
    "page": "Trackers",
    "title": "JDP.Tracker.Instance",
    "category": "method",
    "text": "Create a minimal tracker instance for an unknown tracker\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Tracker.StaticSession",
    "page": "Trackers",
    "title": "JDP.Tracker.StaticSession",
    "category": "type",
    "text": "Not really a session\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Tracker.ensure_login!-Union{Tuple{Instance{S}}, Tuple{S}} where S<:JDP.Tracker.AbstractSession",
    "page": "Trackers",
    "title": "JDP.Tracker.ensure_login!",
    "category": "method",
    "text": "Returns an active session\n\nIf the tracker already has an active session then return it, otherwise create one. The tracker specific modules should override this\n\n\n\n\n\n"
},

{
    "location": "trackers/#Tracker-1",
    "page": "Trackers",
    "title": "Tracker",
    "category": "section",
    "text": "Modules = [JDP.Tracker]"
},

{
    "location": "trackers/#JDP.Trackers.OpenQA.NativeSession",
    "page": "Trackers",
    "title": "JDP.Trackers.OpenQA.NativeSession",
    "category": "type",
    "text": "Use native Julia HTTP library to access OpenQA\n\nUnfortunately this doesn\'t work so well because:\n\nA) JuliaWeb\'s current HTTP SSL implementation i.e. the MbedTLS wrapper B) OpenQA\'s wierd authentication which is difficult to replicate outside of    Perl.\n\n\n\n\n\n"
},

{
    "location": "trackers/#JDP.Trackers.OpenQA.Session",
    "page": "Trackers",
    "title": "JDP.Trackers.OpenQA.Session",
    "category": "type",
    "text": "Makes requests to OpenQA using the official OpenQA client script\n\nI really hate this, but we cache the data locally anyway due to the slowness of fetching from OpenQA, so the overhead of calling a Perl script can be ignored. Also see OpenQA::NativeSession\'s docs.\n\n\n\n\n\n"
},

{
    "location": "trackers/#Trackers.OpenQA-1",
    "page": "Trackers",
    "title": "Trackers.OpenQA",
    "category": "section",
    "text": "Modules = [JDP.Trackers.OpenQA]"
},

{
    "location": "trackers/#Trackers.Bugzilla-1",
    "page": "Trackers",
    "title": "Trackers.Bugzilla",
    "category": "section",
    "text": "Modules = [JDP.Trackers.Bugzilla]"
},

{
    "location": "development/#",
    "page": "Development",
    "title": "Development",
    "category": "page",
    "text": "Here we discuss the development of JDP itself for anyone who wishes to contribute or understand what kind of madness this was born from.note: Note\nYou should at the very least read the coding standards and principals before contributing to the core library."
},

{
    "location": "development/#Coding-standards-and-principals-1",
    "page": "Development",
    "title": "Coding standards and principals",
    "category": "section",
    "text": "The standards and principals change depending on the stage of the product/component life cycle and what the component is. For now there are three stages to the life cycle. These are listed below along with the principals you should follow.Components don\'t necessarily need to start as experimental and progress in a linear fashion. They can be added at any stage. Use the stage specific principals to decide what stage to use.Components are also differentiated by type: library, script and report. The life cycle stages only apply to the library and to the scripts which automate core functionality (e.g. caching data in the master node).The reason for having such a complex system of principles is to take advantage of the bar-bell strategy. So that we do not have to compromise between moving quickly to test new ideas and moving slowly to be robust.warning: Warning\nPrincipals and maxims are never perfect. They just provide a common point of reference so that our productivity vectors sum to a value greater than anyone\'s individual magnitude."
},

{
    "location": "development/#Universal-Principals-1",
    "page": "Development",
    "title": "Universal Principals",
    "category": "section",
    "text": "These apply all the timeThe Silver Rule\nDo not do to others what you would not like to be done to you.\nBe polite, but critical and seek criticism\nWe want the correct solution not to feel like we have the correct solution.\nDo the easiest thing to change later\nWhen in doubt, take the path which is easiest to leave later.\nShow me the code\nCompare your options, make a hypothesis, prove it. (preference for action).\nSmall batch sizes\nMake your feeback loop as tight as possible. Risk making your PRs too small, never too big.\nRule of three\nSane DRY\nIf you need to do something once; write it inline, twice; copy and paste, three times; create an abstraction.\nThe solution should be simpler than the problem\nAvoid unnecessary complexity."
},

{
    "location": "development/#Life-cycle-1",
    "page": "Development",
    "title": "Life cycle",
    "category": "section",
    "text": ""
},

{
    "location": "development/#Experimental-1",
    "page": "Development",
    "title": "Experimental",
    "category": "section",
    "text": "The proof of concept (POC) stage which allows you to just make it work in the shortest time possible. You are free to take on technical debt at this stage and take shortcuts.Experimental components can be merged, but will be deleted if they are abandoned. They must align with the below principals otherwise they are just poorly written features and won\'t be merged.Create a falsifiable hypothesis\nClearly state what you are trying to prove, what failure would look like and what success would be. A component or PR can only be categorised as experimental if it is clearly an experiment.\nDo not over-engineer\nJust do the simplest, easiest thing to prove the feature\'s viability. Use workarounds to solve problems further down the stack. Do not generalise if a specific solution will meet your current requirements regardless of the consequences.\nTrack your technical debt\nYou need to keep a list of your technical debt (i.e. a TODO list) which can be used to estimate the cost of turning an experimental component into a stable one."
},

{
    "location": "development/#Stable-1",
    "page": "Development",
    "title": "Stable",
    "category": "section",
    "text": "Components and code which we won\'t delete without obsoleting them first.Think in the long term\nAssume your code will be run for 10 years and that any mistake will cost many times your own labor and that any improvement will have a huge payoff.\nDocument once instead of answering many\nIt is better to spend a few hours documenting than many hours answering.\nUpstream first\nPropagate your fixes back to the community and...\nFix whatever needs to be fixed\nFixing problems further down the stack can create a long chain-reaction (fractal) of events which eventually benefit us much more than whatever your original task was. Fix root causes, don\'t write workarounds."
},

{
    "location": "development/#Legacy-1",
    "page": "Development",
    "title": "Legacy",
    "category": "section",
    "text": "Components or APIs which can only be accessed through a versioned interface and only use versioned interfaces. That is, the function names and/or namespaces have the version number in the name. The behaviour of versioned interfaces does not change allowing scripts or reports to use them indefinitely without any maintenance due to changes in the library. Legacy components are deleted if they are not used enough.Otherwise the principals are the same as the Stable stage."
},

{
    "location": "development/#Library-coding-standards-1",
    "page": "Development",
    "title": "Library coding standards",
    "category": "section",
    "text": "This applies to code providing core functionality of the project. This includes some scripts and reports, but we will just refer to them as the library coding standards."
},

{
    "location": "development/#Documentation-and-commenting-1",
    "page": "Development",
    "title": "Documentation and commenting",
    "category": "section",
    "text": "Use documentation strings wherever possible, these are vastly more useful than inline comments. Only use inline comments for annotating very unusual code."
},

{
    "location": "development/#Prefer-explicit-over-implicit-1",
    "page": "Development",
    "title": "Prefer explicit over implicit",
    "category": "section",
    "text": "Type annotate all interfaces. Learn Julia\'s type system use it to lock down your code. Type parameters, abstract types and multiple dispatch allow for so much freedom it is rarely desirable to use implicit types (in function arguments or structs).Implicit types are often OK for local variables, but adding type annotations can help make code clearer."
},

{
    "location": "development/#Project-status-1",
    "page": "Development",
    "title": "Project status",
    "category": "section",
    "text": "See the documentation for each module. At the time of writing, most of the project needs cleaning up."
},

{
    "location": "development/#Architecture-1",
    "page": "Development",
    "title": "Architecture",
    "category": "section",
    "text": "The following diagrams are only to help you visualise the project. They are not a design specification or very accurate. For more details see the individual component documentation."
},

{
    "location": "development/#Outer-1",
    "page": "Development",
    "title": "Outer",
    "category": "section",
    "text": "(Image: )"
},

{
    "location": "development/#Inner-1",
    "page": "Development",
    "title": "Inner",
    "category": "section",
    "text": "(Image: )"
},

{
    "location": "development/#Motivation-1",
    "page": "Development",
    "title": "Motivation",
    "category": "section",
    "text": ""
},

{
    "location": "development/#Concrete-1",
    "page": "Development",
    "title": "Concrete",
    "category": "section",
    "text": "We want to spend as little time as possible reading test results and logs while maximising the error (or bug) detection rate. We also want to report all relevant information, and only the relevant information, to any interested parties for a given error using the least amount of time.The manual process for identifying errors involves looking at information from several sources, identifying relations and reporting those relations to a number of different consumers. There may be several persons forming a tree (in the simple case) or a cyclical directed graph (practically speaking), collecting and processing information then passing it along.The information is collected from sources such as OpenQA or a manual test run. Points of interest are identified, these are inputted into an issue tracker (commonly Bugzilla) and then the bugs are aggregated into reports. The bugs are then passed back to OpenQA (or whatever) to mark failing test cases or some other anomaly (bug tagging).We have a number of issues with this:Many of the data sources are very slow (e.g. OpenQA, Bugzilla)\nRemote sources are often not available due to the network or other system failure\nThe same information is encoded in many different ways\nLog files are often very large and noisy\nDifferent consumers of error data require different levels of detail\nDifferent consumers of error data require different views of the data\nWhat is considered a pass or failure by a given test runner (e.g. OpenQA, Slenkins, LTP upstream test runner) may be incorrect.\nSimilar to 7. a skipped test may be an error\nThere are many data consumers, each accepting different formats or views of the data.\nEtc."
},

{
    "location": "development/#Less-Concrete-1",
    "page": "Development",
    "title": "Less Concrete",
    "category": "section",
    "text": "Furthermore we are lacking in tools to automate arbitrary workflows given the various data sources and sinks available to us. Therefor we would like to create an environment which allows for easy experimentation/prototyping where the heavy lifting has already been done and any algorithm can be implemented on the data commonly available to us."
},

{
    "location": "development/#Existing-solutions-1",
    "page": "Development",
    "title": "Existing solutions",
    "category": "section",
    "text": "Attempts have been made to solve some of these problems in the OpenQA web UI or with a stand-alone script which queries various sources and produces some output. There are a number of problems with these approaches.note: Note\nThis is not an exhaustive list. These are just the solutions which tend to be automatically chosen."
},

{
    "location": "development/#OpenQA-1",
    "page": "Development",
    "title": "OpenQA",
    "category": "section",
    "text": "It is rigid\nIt is slow\nRemote data is not replicated to your local instance\nIt is responsible for running the tests (which is a big responsibility)Theoretically all of these can be solved except for (4). Practically speaking, solving any of them would be a huge challenge. Not least because the iteration time for developing a new feature is very slow and the process is cumbersome.However some improvements in this area can and should be made to OpenQA. I propose that such improvements can be prototyped in JDP where the iteration time is much smaller and mistakes won\'t disrupt all testing."
},

{
    "location": "development/#Various-scripts-1",
    "page": "Development",
    "title": "Various scripts",
    "category": "section",
    "text": "Little sharing of code (no general library for writing such scripts)\nNo local data cache\nNo data normalisation between sources\nNo common data visualisationThere may be a script somewhere which is evolving to solve some of these issues (maybe for performance testing). I think some of these scripts could be merged with the JDP project so they are not necessarily an alternative solution although doing so may cause some unnecessary friction."
},

{
    "location": "development/#Design-Decisions-1",
    "page": "Development",
    "title": "Design Decisions",
    "category": "section",
    "text": "These decisions should follow from the motivation or requirements of the project."
},

{
    "location": "development/#Not-a-source-of-truth-1",
    "page": "Development",
    "title": "Not a source of truth",
    "category": "section",
    "text": "JDP is not a primary data store. It caches data (see next section) from other sources (trackers) and posts data back to other stores. This allows the data cache to be deleted or transformed with no fear of data loss.Configuration for JDP itself is stored in configuration files which are not associated with the cache.If yet another tracker (test, bug tracker or something else) is required then it should be created as a separate service."
},

{
    "location": "development/#Distributed-Data-Cache-1",
    "page": "Development",
    "title": "Distributed Data Cache",
    "category": "section",
    "text": "The data sources are very slow and unreliable some of the time. So we periodically query the sources and cache the data into a Redis master node. Clients can then be configured to replicate from this master node.Replicating from the master node is significantly faster than downloading all required data from the original sources.Each client has (by default, but it is configurable) has its own local Redis instance. This replicates from the master node, but the client can write to it without effecting the master. In the future we could provide some mechanism for clients to send changes back to the master.Redis could be replaced if necessary or we could insert our own replication layer. The data is stored using BSON.jl to serialise Julia structs, but it can be changed if necessary. The storage layer is fairly well decoupled from the rest of the application.The reason we are using Redis is because it is simple and easy, yet supports replication. We are probably abusing its replication and this may not scale, so one should not assume that we will be using Redis forever."
},

{
    "location": "development/#Mostly-in-memory-data-1",
    "page": "Development",
    "title": "Mostly in memory data",
    "category": "section",
    "text": "The data is mostly brought into memory before being queried. Some filtering may be necessary before fetching from the data store, but most things are done in memory.The reason for this is to maximise freedom. We make few assumptions about what algorithms or queries the user will want to make on the data. They may wish to use SQL like statements or they may not. They may want to put the data in a graph and run some graph algorithm on it.The data is stored in the data cache in whatever way we see fit, then it can be fetched and transformed into two or more formats (currently plain structs or DataFrames).Doing everything in memory places few restrictions on how the data is stored or how it is queried. It is not a performance optimisation except in some quite rare scenarios.We may need to create indexes for very common queries. For example filtering test results by date or product group. However these must be queries used in almost every script that have a significant positive effect."
},

{
    "location": "development/#Julia-1",
    "page": "Development",
    "title": "Julia",
    "category": "section",
    "text": "Yes, we are using some crazy language you have never heard of. Some of the reasons are as follows."
},

{
    "location": "development/#Positives-1",
    "page": "Development",
    "title": "Positives",
    "category": "section",
    "text": "It has a strong type system which can optionally be inferred. This is good for the core library where we want to type annotate everything for static analysis and self documentation. It is also good for quickly writing scripts/reports where the user doesn\'t care/know what type gets used. Although personally I like to annotate almost everything.\nIt behaves mostly like a scripting language, but is compiled to native code (LLVM). In theory it can be optimised for C like performance, but it has an advanced symbolic macro system and you can dynamically build types and objects like in a scripting language.\nIt is popular with people doing a lot data analysis, like scientists and such.\nIt has a nice system for displaying any object graphically in different backends (e.g. as html, vectors, markdown, plain text, ...).\nI managed to get the basics working very quickly.\nIt is not completely alien compared to more popular languages. The learning curve is fairly low for making basic changes. It then increased rapidly once the type system is involved which I actually consider a good thing.\nIt interfaces well with C and Python[1]\nIt makes me happy.[1]: Untested by us, but it is probably mostly true. If it interfaces with C well it probably also works well with any other language which exports sane symbols."
},

{
    "location": "development/#Negatives-1",
    "page": "Development",
    "title": "Negatives",
    "category": "section",
    "text": "On the downside:In practice it is not very quick because many libraries are not optimised.\nIt looks alien to C/Perl programmers.\nEven common libraries are often immature and contain bugs\nPython/R/Scalar/X exists and people will ask why aren\'t you using Python/R/Scalar/X.\nThe startup time is quite bad because it often decides to recompile stuff on the fly.\nIt\'s just generally not very mature and stuff breaks with major language releases.\nThere are no packages for individual libraries.\nHas some weird syntax and behavior which I think will need to be changed at some point.Please note that I have repeatedly looked round at alternatives to Julia. Something really bad would have to happen at this point for us to change it. Also in the future if people wish to write scripts/reports in Python they should be able to. It is only the library which is limited to Julia and in fact parts could be written in C or another-really-fast-language if really necessary."
},

{
    "location": "development/#Jupyter-(formally-known-as-IPython)-Notebooks-for-reports/scripts-1",
    "page": "Development",
    "title": "Jupyter (formally known as IPython) Notebooks for reports/scripts",
    "category": "section",
    "text": "For some of the reports/scripts we use Jupyter which is a graphical REPL of sorts. It allows you to write blocks of code which produce some object which can be graphically represented below the code block (cell). It also allows blocks of Markdown to be rendered inline. The code blocks can all be run in sequence or individually.To experienced C hackers it looks like baby\'s first coding IDE, but it is very useful for creating report prototypes because you can render HTML/Markdown/SVG inline and quickly rerun a particular bit of code (like a REPL).Also JDP is not necessarily just aimed at developers as end users. Jupyter provides something resembling a GUI, but with all the wires hanging out. There is also the possibility of hosting the notebooks remotely for people who can\'t/won\'t install JDP locally.Jupyter notebooks can be replaced or supplemented with something else if it better suites a given use case. Also scripts and reports do not need to be written as Jupyter notebooks; it is down to the author\'s discretion."
},

]}
