Here we discuss the development of JDP itself for anyone who wishes to
contribute or understand what kind of madness this was born from.

# Motivation

## Concrete

We want to spend as little time as possible reading test results and logs
while maximising the error (or bug) detection rate. We also want to report all
relevant information, and only the relevant information, to any interested
parties for a given error using the least amount of time.

The manual process for identifying errors involves looking at information from
several sources, identifying relations and reporting those relations to a
number of different consumers. There may be several persons forming a tree (in
the simple case) or a cyclical directed graph (practically speaking),
collecting and processing information then passing it along.

The information is collected from sources such as OpenQA or a manual test
run. Points of interest are identified, these are inputted into an issue
tracker (commonly Bugzilla) and then the bugs are aggregated into reports. The
bugs are then passed back to OpenQA (or whatever) to mark failing test cases
or some other anomaly (bug tagging).

We have a number of issues with this:

1. Many of the data sources are very slow (e.g. OpenQA, Bugzilla)
2. Remote sources are often not available due to the network or other system
   failure
3. The same information is encoded in many different ways
4. Log files are often very large and noisy
5. Different consumers of error data require different levels of detail
6. Different consumers of error data require different views of the data
7. What is considered a pass or failure by a given test runner (e.g. OpenQA, Slenkins,
   LTP upstream test runner) may be incorrect.
8. Similar to 7. a skipped test may be an error
9. Etc.

## Less Concrete

Furthermore we are lacking in tools to automate arbitrary workflows given the
various data sources and sinks available to us. Therefor we would like to
create an environment which allows for easy experimentation/prototyping where
the heavy lifting has already been done and any algorithm can be implemented
on the data commonly available to us.

## Existing solutions

Attempts have been made to solve some of these problems in the OpenQA web UI
or with a stand-alone script which queries various sources and produces some
output. There are a number of problems with these approaches.

### OpenQA

1. It is rigid
2. It is slow
3. Remote data is not replicated to your local instance
4. It is responsible for running the tests (which is a big responsibility)

Theoretically all of these can be solved except for (4). Practically speaking,
solving any of them would be a huge challenge. Not least because the iteration
time for developing a new feature is very slow and the process is
cumbersome.

However some improvements in this area can and should be made to OpenQA. I
propose that such improvements can be prototyped in JDP where the iteration
time is much smaller and mistakes won't disrupt all testing.

### Various scripts

1. Little sharing of code (no general library for writing such scripts)
2. No local data cache
3. No data normalisation between sources
4. No common data visualisation

There may be a script somewhere which is evolving to solve some of these
issues (maybe for performance testing). I think some of these scripts could be
merged with the JDP project so they are not necessarily an alternative
solution although doing so may cause some unnecessary friction.

# Design Decisions

These decisions should follow from the motivation or requirements of the
project.

## Not a source of truth

JDP is not a primary data store. It caches data (see next section) from other
sources (trackers) and posts data back to other stores. This allows the data
cache to be deleted or transformed with no fear of data loss.

Configuration for JDP itself is stored in configuration files which are not
associated with the cache.

If yet another tracker (test or bug tracker) is required then it should be
created as a separate service.

## Distributed Data Cache

The data sources are very slow and unreliable some of the time. So we
periodically query the sources and cache the data into a Redis master
node. Clients can then be configured to replicate from this master node.

Replicating from the master node is significantly faster than downloading all
required data from the original sources.

Each client has (by default, but it is configurable) its own local Redis
instance. This replicates from the master node, but the client can write to it
without effecting the master. In the future we could provide some mechanism
for clients to send changes back to the master.

Redis could be replaced if necessary or we could insert our own replication
layer. The data is stored using BSON.jl, but it can be changed if
necessary. The storage layer is fairly well decoupled from the rest of the
application. 

The reason we are using Redis is because it is simple and easy, yet supports
replication. We are probably abusing its replication and this may not scale,
so one should not assume that we will be using Redis forever.

## Mostly in memory data

The data is mostly brought into memory before being queried. Some filtering
may be necessary before fetching from the data store, but most things are
done in memory.

The reason for this is to maximise freedom. We make few assumptions about what
algorithms or queries the user will want to make on the data. They may wish to
use SQL like statements or they may not. They may want to put the data in a
graph and run some graph algorithm on it.

The data is stored in the data cache in whatever way we see fit, then it can
be fetched and transformed into two or more formats (currently plain structs
or DataFrames).

Doing everything in memory places few restrictions on how the data is stored
or how it is queried. It is not a performance optimisation except in some
quite rare scenarios.

We may need to create indexes for very common queries. For example filtering
test results by date or product group. However these must be queries used in
almost every script that have a significant positive effect.

## Julia

Yes, we are using some crazy language you have never heard of. Some of the
reasons are as follows.

### Positives

1. It has a strong type system which can optionally be inferred. This is good
   for the core library where we want to type annotate everything for static
   analysis and self documentation. It is also good for quickly writing
   scripts/reports where the user doesn't care/know what type gets
   used. Although personally I like to annotate almost everything.
2. It behaves mostly like a scripting language, but is compiled to native code
   (LLVM). In theory it can be optimised for C like performance, but it has an
   advanced symbolic macro system and you can dynamically build types and
   objects like in a scripting language.
3. It is popular with people doing a lot data analysis, like scientists and
   such.
4. It has a nice system for displaying any object graphically in different
   backends (e.g. as html, vectors, markdown, plain text, ...).
5. I managed to get the basics working very quickly.
6. It is not completely alien compared to more popular languages. The learning
   curve is fairly low for making basic changes. It then increased rapidly
   once the type system is involved which I actually consider a good thing.
7. It interfaces well with C and Python[^1]
8. It makes me happy.

[^1]:
Untested by us, but it is probably mostly true. If it interfaces with C well
it probably also works well with any other language which exports sane
symbols.
   
### Negatives

On the downside:

1. In practice it is not very quick because many libraries are not optimised.
2. It looks alien to C/Perl programmers
3. Even common libraries are often immature and contain bugs
4. Python/R/Scalar/X exists and people will ask why aren't you using
   Python/R/Scalar/X
5. The startup time is quite bad relative to other languages except maybe JVM
   based stuff.
6. It's just generally not very mature and stuff breaks with major language releases
7. There are no packages for individual libraries
8. Has some weird syntax and behavior which I think will need to be changed at
   some point.

Please note that I have repeatedly looked round at alternatives to
Julia. Something really bad would have to happen at this point for us to
change it. Also in the future if people wish to write scripts/reports in
Python they should be able to. It is only the library which is limited to
Julia and in fact parts could be written in C or
`another-really-fast-language` if really necessary.

## Jupyter (formally known as IPython)

For some of the reports/scripts we use Jupyter which is a graphical
REPL of sorts. It allows you to write blocks of code which produce some object
which can be graphically represented below the code block (cell). It also allows
blocks of Markdown to be rendered inline. The code blocks can all be run in
sequence or individually.

To experienced C hackers it looks like baby's first coding IDE, but it is very
useful for creating report prototypes because you can render HTML/Markdown/SVG
inline and quickly rerun a particular bit of code (like a REPL). 

Also JDP is not necessarily just aimed at developers as end users. Jupyter
provides something resembling a GUI, but with all the wires hanging out.

# Coding standards

